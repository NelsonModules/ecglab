%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
% <--ENGLISH IMPOSED-->
%=============================================================================
%=============================================================================
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% The reference fetcher is tested with Download false into a temporary folder.
% The one real record at the end is read only if on disk, or fetched once.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% When ecglab.readwfdb is absent, a stub records what it was asked to read so
% the fetch and folder logic still run; it is added to the path and removed.
readerPresent = exist('ecglab.readwfdb') ~= 0;
stubFolder = [folder, '/stub'];
if ~readerPresent
  mkdir([stubFolder, '/+ecglab']);
  fid = fopen([stubFolder, '/+ecglab/readwfdb.m'], 'wt');
  fprintf(fid, 'function recording = readwfdb(name, varargin)\n');
  fprintf(fid, '  which = '''';\n');
  fprintf(fid, '  if numel(varargin) >= 2\n');
  fprintf(fid, '    which = varargin{2};\n');
  fprintf(fid, '  end\n');
  fprintf(fid, '  recording = struct(''kind'', ''ecglab.recording'', ');
  fprintf(fid, '''rate'', NaN, ''samples'', zeros(0, 1), ''leads'', {{}}, ');
  fprintf(fid, '''units'', {{}}, ''seconds'', 0, ''info'', struct(''name'', ');
  fprintf(fid, 'name, ''source'', '''', ''format'', ''wfdb''), ');
  fprintf(fid, '''annotations'', struct(''kind'', ''ecglab.annotations'', ');
  fprintf(fid, '''sample'', zeros(0, 1), ''symbol'', char(zeros(0, 1)), ');
  fprintf(fid, '''file'', which));\n');
  fprintf(fid, 'end\n');
  fclose(fid);
  addpath(stubFolder);
  disp('ecglab.readwfdb is not on this branch yet: a stub stands in for it and what is read is not checked.');
end
%=============================================================================
% A tiny record under a real name, so the name resolves and every byte is
% known. Plain signed sixteen bit, two signals interleaved, crossing zero.
mkdir([folder, '/mitdb']);
stored = [100 -100 300 -300 1000 -1000];
fid = fopen([folder, '/mitdb/100.hea'], 'wt');
fprintf(fid, '100 2 360 3\n');
fprintf(fid, '100.dat 16 200 16 0 100 0 0 MLII\n');
fprintf(fid, '100.dat 16 200 16 0 -100 0 0 V5\n');
fprintf(fid, '# a comment the fetcher must not take for a signal file\n');
fclose(fid);
ecglabTestSixteen([folder, '/mitdb/100.dat'], stored);
% Annotations: sixteen bit words, top six bits the code, bottom ten the gap.
% A normal beat, a ventricular one 100 later, a zero word to end.
fid = fopen([folder, '/mitdb/100.atr'], 'wb');
ecglabTestWord(fid, 1 * 1024 + 100);
ecglabTestWord(fid, 5 * 1024 + 100);
ecglabTestWord(fid, 0);
fclose(fid);
%=============================================================================
recording = ecglab.reference('mitdb/100', 'Folder', folder, 'Download', false);
assert_isequal(recording.kind, 'ecglab.recording');
assert_isequal(recording.info.database, 'mitdb');
assert_isequal(recording.info.record, '100');
assert_isequal(recording.info.source, ...
'mitdb 100, PhysioNet, Open Data Commons Attribution License v1.0');
% The files are the header, the one signal file, and the annotator, as paths.
assert_isequal(recording.files, {[folder, '/mitdb/100.hea'], ...
[folder, '/mitdb/100.dat'], [folder, '/mitdb/100.atr']});
% The arrhythmia database has one annotator and no reference field.
assert_isfalse(isfield(recording, 'reference'));
if readerPresent
  assert_isequal(recording.rate, 360);
  assert_isapprox(recording.samples, ...
  [stored(1:2:end); stored(2:2:end)]' / 200, 1e-9);
  assert_isequal(recording.leads, {'MLII', 'V5'});
  assert_isequal(recording.annotations.symbol, ['N'; 'V']);
  % The first sample of the record is annotation time zero and index one.
  assert_isequal(recording.annotations.sample, [101; 201]);
else
  assert_isequal(recording.info.name, [folder, '/mitdb/100.hea']);
  assert_isequal(recording.annotations.file, [folder, '/mitdb/100.atr']);
end
%=============================================================================
% The annotator may be turned off; the file list still reports what is on disk.
bare = ecglab.reference('mitdb/100', 'Folder', folder, 'Download', false, ...
'Annotations', '');
assert_isequal(numel(bare.annotations.sample), 0);
assert_isequal(numel(bare.files), 3);
%=============================================================================
% A half-finished download ends in .part and is never used, so the record is
% reported missing rather than read short.
fid = fopen([folder, '/mitdb/101.hea'], 'wt');
fprintf(fid, '101 1 360 3\n');
fprintf(fid, '101.dat 16 200 16 0 100 0 0 MLII\n');
fclose(fid);
ecglabTestSixteen([folder, '/mitdb/101.dat.part'], stored(1:2));
assert_checkerror(['ecglab.reference(''mitdb/101'', ''Folder'', ''', ...
folder, ''', ''Download'', false)'], ...
['The file ', folder, '/mitdb/101.dat is not on disk and downloading ', ...
'was refused.']);
%=============================================================================
% The QT database: several annotators of one record, each read into
% recording.reference under its own name. The optional q2c is absent here.
mkdir([folder, '/qtdb']);
fid = fopen([folder, '/qtdb/sel100.hea'], 'wt');
fprintf(fid, 'sel100 2 250 3\n');
fprintf(fid, 'sel100.dat 16 200(0) 16 0 100 0 0 MLII\n');
fprintf(fid, 'sel100.dat 16 200(0) 16 0 -100 0 0 V5\n');
fclose(fid);
ecglabTestSixteen([folder, '/qtdb/sel100.dat'], stored);
annotators = {'atr', 'man', 'q1c', 'pu', 'pu0', 'pu1'};
% Beat annotators (atr, man) carry code 1; q1c carries the onset mark code 39
% ('('), the automatic ones the P peak code 24 ('p').
codes = [1 1 39 24 24 24];
for index = 1:numel(annotators)
  fid = fopen([folder, '/qtdb/sel100.', annotators{index}], 'wb');
  ecglabTestWord(fid, codes(index) * 1024 + 10 * index);
  ecglabTestWord(fid, 0);
  fclose(fid);
end
qt = ecglab.reference('qtdb/sel100', 'Folder', folder, 'Download', false);
assert_isequal(qt.info.source, ...
'qtdb sel100, PhysioNet, Open Data Commons Attribution License v1.0');
assert_istrue(isfield(qt, 'reference'));
assert_isequal(sort(fieldnames(qt.reference)), sort(annotators'));
assert_isfalse(isfield(qt.reference, 'q2c'));
assert_isequal(numel(qt.files), 8);
if readerPresent
  % q1c is the default annotator; every reference keeps its own mark.
  assert_isequal(qt.annotations.sample, qt.reference.q1c.sample);
  assert_isequal(qt.reference.q1c.sample, 31);
  assert_isequal(qt.reference.q1c.symbol, '(');
  assert_isequal(qt.reference.atr.sample, 11);
  assert_isequal(qt.reference.pu1.sample, 61);
else
  assert_isequal(qt.annotations.file, [folder, '/qtdb/sel100.q1c']);
  assert_isequal(qt.reference.pu0.file, [folder, '/qtdb/sel100.pu0']);
  assert_isequal(qt.reference.man.file, [folder, '/qtdb/sel100.man']);
end
% Another annotator on request; one not on disk is refused by name.
other = ecglab.reference('qtdb/sel100', 'Folder', folder, ...
'Download', false, 'Annotations', 'pu0');
if readerPresent
  assert_isequal(other.annotations.sample, 51);
else
  assert_isequal(other.annotations.file, [folder, '/qtdb/sel100.pu0']);
end
assert_checkerror(['ecglab.reference(''qtdb/sel100'', ''Folder'', ''', ...
folder, ''', ''Download'', false, ''Annotations'', ''q2c'')'], ...
'The annotator q2c does not exist for qtdb/sel100.');
assert_checkerror(['ecglab.reference(''qtdb/sel100'', ''Folder'', ''', ...
folder, ''', ''Download'', false, ''Annotations'', ''foo'')'], ...
'Unknown annotator foo for qtdb (atr, man, q1c, q2c, pu, pu0, pu1).');
%=============================================================================
% The Lobachevsky database: twelve leads in one file, one annotator per lead.
% Lead ii is the default. The records sit in a data folder the layout mirrors.
mkdir([folder, '/ludb/data']);
leads = {'i', 'ii', 'iii', 'avr', 'avl', 'avf', 'v1', 'v2', 'v3', 'v4', ...
'v5', 'v6'};
fid = fopen([folder, '/ludb/data/1.hea'], 'wt');
fprintf(fid, '1 12 500 2\n');
for index = 1:12
  fprintf(fid, '1.dat 16 1000(0)/mV 0 0 0 0 0 %s\n', leads{index});
end
fclose(fid);
ecglabTestSixteen([folder, '/ludb/data/1.dat'], 1:24);
for index = 1:12
  fid = fopen([folder, '/ludb/data/1.', leads{index}], 'wb');
  ecglabTestWord(fid, 1 * 1024 + index);
  ecglabTestWord(fid, 0);
  fclose(fid);
end
lu = ecglab.reference('ludb/1', 'Folder', folder, 'Download', false);
assert_isequal(lu.info.source, ...
'ludb 1, PhysioNet, Open Data Commons Attribution License v1.0');
assert_isequal(lu.info.record, '1');
assert_isequal(fieldnames(lu.reference), leads');
assert_isequal(numel(lu.files), 14);
assert_isequal(lu.files{1}, [folder, '/ludb/data/1.hea']);
assert_isequal(lu.files{end}, [folder, '/ludb/data/1.v6']);
if readerPresent
  assert_isequal(lu.annotations.sample, 3);
  assert_isequal(lu.reference.v6.sample, 13);
else
  assert_isequal(lu.annotations.file, [folder, '/ludb/data/1.ii']);
  assert_isequal(lu.reference.v6.file, [folder, '/ludb/data/1.v6']);
end
%=============================================================================
% The PTB databases carry no annotations, so asking for an annotator is
% refused. The header may spread signals over several files, all fetched.
mkdir([folder, '/ptbdb/patient001']);
fid = fopen([folder, '/ptbdb/patient001/s0010_re.hea'], 'wt');
fprintf(fid, 's0010_re 3 1000 2\n');
fprintf(fid, 's0010_re.dat 16 2000 16 0 0 0 0 i\n');
fprintf(fid, 's0010_re.dat 16 2000 16 0 0 0 0 ii\n');
fprintf(fid, 's0010_re.xyz 16 2000 16 0 0 0 0 vx\n');
fclose(fid);
ecglabTestSixteen([folder, '/ptbdb/patient001/s0010_re.dat'], [1 2 3 4]);
ecglabTestSixteen([folder, '/ptbdb/patient001/s0010_re.xyz'], [5 6]);
ptb = ecglab.reference('ptbdb/patient001/s0010_re', 'Folder', folder, ...
'Download', false);
assert_isequal(ptb.info.database, 'ptbdb');
assert_isequal(ptb.info.record, 'patient001/s0010_re');
assert_isequal(ptb.info.source, ...
'ptbdb patient001/s0010_re, PhysioNet, Open Data Commons Attribution License v1.0');
assert_isequal(ptb.files, {[folder, '/ptbdb/patient001/s0010_re.hea'], ...
[folder, '/ptbdb/patient001/s0010_re.dat'], ...
[folder, '/ptbdb/patient001/s0010_re.xyz']});
assert_isfalse(isfield(ptb, 'reference'));
assert_isequal(numel(ptb.annotations.sample), 0);
assert_checkerror(['ecglab.reference(''ptbdb/patient001/s0010_re'', ', ...
'''Folder'', ''', folder, ''', ''Download'', false, ''Annotations'', ''atr'')'], ...
'Unknown annotator atr for ptbdb (none).');
% A signal file the header names but is missing is an error, not a short record.
fid = fopen([folder, '/ptbdb/patient001/s0014lre.hea'], 'wt');
fprintf(fid, 's0014lre 1 1000 2\n');
fprintf(fid, 's0014lre.dat 16 2000 16 0 0 0 0 i\n');
fclose(fid);
assert_checkerror(['ecglab.reference(''ptbdb/patient001/s0014lre'', ', ...
'''Folder'', ''', folder, ''', ''Download'', false)'], ...
['The file ', folder, '/ptbdb/patient001/s0014lre.dat is not on disk ', ...
'and downloading was refused.']);
% PTB-XL is the other licence, and its records sit three folders deep.
mkdir([folder, '/ptb-xl/records500/00000']);
fid = fopen([folder, '/ptb-xl/records500/00000/00001_hr.hea'], 'wt');
fprintf(fid, '00001_hr 1 500 2\n');
fprintf(fid, '00001_hr.dat 16 1000.0(0)/mV 16 0 0 0 0 I\n');
fclose(fid);
ecglabTestSixteen([folder, '/ptb-xl/records500/00000/00001_hr.dat'], [1 2]);
xl = ecglab.reference('ptb-xl/records500/00000/00001_hr', 'Folder', ...
folder, 'Download', false);
assert_isequal(xl.info.source, ...
'ptb-xl records500/00000/00001_hr, PhysioNet, Creative Commons Attribution 4.0');
assert_isequal(numel(xl.files), 2);
%=============================================================================
% The noise records of the noise stress test database carry no annotator.
mkdir([folder, '/nstdb']);
fid = fopen([folder, '/nstdb/bw.hea'], 'wt');
fprintf(fid, 'bw 2 360 3\n');
fprintf(fid, 'bw.dat 212 200 11 1024 0 0 0 noise1\n');
fprintf(fid, 'bw.dat 212 200 11 1024 0 0 0 noise2\n');
fclose(fid);
fid = fopen([folder, '/nstdb/bw.dat'], 'wb');
fwrite(fid, zeros(1, 9), 'uint8');
fclose(fid);
noise = ecglab.reference('nstdb/bw', 'Folder', folder, 'Download', false);
assert_isequal(numel(noise.files), 2);
assert_isequal(numel(noise.annotations.sample), 0);
assert_checkerror(['ecglab.reference(''nstdb/118e06'', ''Folder'', ''', ...
folder, ''', ''Download'', false)'], ...
['The file ', folder, '/nstdb/118e06.hea is not on disk and ', ...
'downloading was refused.']);
%=============================================================================
% The record lists, with the counts of the server RECORDS files. The afdb
% list keeps the 23 openable records out of 25.
assert_isequal(numel(ecglab.reference('list', 'Database', 'mitdb')), 48);
assert_isequal(numel(ecglab.reference('list', 'Database', 'qtdb')), 105);
assert_isequal(numel(ecglab.reference('list', 'Database', 'nsrdb')), 18);
assert_isequal(numel(ecglab.reference('list', 'Database', 'afdb')), 23);
assert_isequal(numel(ecglab.reference('list', 'Database', 'nstdb')), 15);
assert_isequal(numel(ecglab.reference('list', 'Database', 'ludb')), 200);
names = ecglab.reference('list');
assert_isequal(size(names), [48 1]);
assert_isequal(names{1}, '100');
assert_isequal(names{end}, '234');
afdb = ecglab.reference('list', 'Database', 'AFDB');
assert_isfalse(any(strcmp(afdb, '00735')));
assert_istrue(any(strcmp(afdb, '04015')));
nstdb = ecglab.reference('list', 'Database', 'nstdb');
assert_istrue(any(strcmp(nstdb, 'bw')));
assert_istrue(any(strcmp(nstdb, '118e_6')));
ludb = ecglab.reference('list', 'Database', 'ludb');
assert_isequal(ludb{1}, '1');
assert_isequal(ludb{200}, '200');
% The PTB lists are fetched once; offline the cached file is read, else error.
fid = fopen([folder, '/ptbdb/RECORDS'], 'wt');
fprintf(fid, 'patient001/s0010_re\npatient001/s0014lre\npatient001/s0016lre\n');
fclose(fid);
ptbList = ecglab.reference('list', 'Database', 'ptbdb', 'Folder', folder, ...
'Download', false);
assert_isequal(ptbList, {'patient001/s0010_re'; 'patient001/s0014lre'; ...
'patient001/s0016lre'});
assert_checkerror(['ecglab.reference(''list'', ''Database'', ''ptb-xl'', ', ...
'''Folder'', ''', folder, ''', ''Download'', false)'], ...
['The file ', folder, '/ptb-xl/RECORDS is not on disk and downloading ', ...
'was refused.']);
% Once the list is on disk, a record it does not name is refused by name.
assert_checkerror(['ecglab.reference(''ptbdb/patient999/s0001_re'', ', ...
'''Folder'', ''', folder, ''', ''Download'', false)'], ...
'Unknown record patient999/s0001_re in ptbdb.');
%=============================================================================
% The errors, each a sentence that says what was wrong.
assert_checkerror('ecglab.reference(''foo/1'')', ...
'Unknown database: foo (mitdb, qtdb, nsrdb, afdb, nstdb, ludb, ptbdb, ptb-xl).');
assert_checkerror('ecglab.reference(''list'', ''Database'', ''foo'')', ...
'Unknown database: foo (mitdb, qtdb, nsrdb, afdb, nstdb, ludb, ptbdb, ptb-xl).');
assert_checkerror('ecglab.reference(''mitdb/999'')', ...
'Unknown record 999 in mitdb.');
assert_checkerror('ecglab.reference(''afdb/00735'')', ...
'Unknown record 00735 in afdb.');
assert_checkerror('ecglab.reference(''mitdb'')', ...
'A record is named database/record, such as mitdb/100.');
assert_checkerror('ecglab.reference(3)', 'The name must be text.');
assert_checkerror(['ecglab.reference(''mitdb/102'', ''Folder'', ''', ...
folder, ''', ''Download'', false)'], ...
['The file ', folder, '/mitdb/102.hea is not on disk and downloading ', ...
'was refused.']);
assert_checkerror('ecglab.reference(''mitdb/100'', ''Where'', 1)', ...
'Unknown option: Where.');
assert_checkerror('ecglab.reference(''mitdb/100'', ''Folder'')', ...
'Options come in name and value pairs.');
%=============================================================================
if ~readerPresent
  rmpath(stubFolder);
end
rmdir(folder, 's');
%=============================================================================
% One real record, mitdb/100: read from disk when there, fetched once if the
% network answers, else skipped. Its table has 2274 annotations, 2239 normal.
home = [prefdir(), '/ecglab_reference'];
onDisk = isfile([home, '/mitdb/100.hea']) && isfile([home, '/mitdb/100.dat']) ...
&& isfile([home, '/mitdb/100.atr']);
reachable = onDisk;
if ~onDisk
  try
    webread('https://physionet.org/files/mitdb/1.0.0/RECORDS', ...
    weboptions('Timeout', 20));
    reachable = true;
  catch
    reachable = false;
  end
end
if ~reachable
  disp('mitdb/100 is not on disk and the network does not answer: the real record is not checked.');
elseif ~readerPresent
  % The stub is gone: only the files and paths are checked, not their contents.
  addpath(stubFolder);
  real = ecglab.reference('mitdb/100');
  rmpath(stubFolder);
  assert_istrue(isfile([home, '/mitdb/100.hea']));
  assert_istrue(isfile([home, '/mitdb/100.dat']));
  assert_istrue(isfile([home, '/mitdb/100.atr']));
  assert_isequal(real.files, {[home, '/mitdb/100.hea'], ...
  [home, '/mitdb/100.dat'], [home, '/mitdb/100.atr']});
  % Record 100 is 650000 samples of two signals, three bytes a pair: 1950000.
  described = dir([home, '/mitdb/100.dat']);
  assert_isequal(described.bytes, 1950000);
else
  real = ecglab.reference('mitdb/100');
  assert_isequal(real.rate, 360);
  assert_isequal(size(real.samples), [650000 2]);
  assert_isequal(real.leads, {'MLII', 'V5'});
  assert_isequal(numel(real.annotations.sample), 2274);
  assert_isequal(sum(real.annotations.symbol == 'N'), 2239);
  assert_isequal(sum(real.annotations.symbol == 'A'), 33);
  assert_isequal(sum(real.annotations.symbol == 'V'), 1);
  % Fetched once: the second call reads the same files off disk.
  again = ecglab.reference('mitdb/100', 'Download', false);
  assert_isequal(again.files, real.files);
end
%=============================================================================
function ecglabTestSixteen(path, values)
  % Plain signed sixteen bit, least significant byte first, written by hand.
  bytes = zeros(1, 2 * numel(values));
  for index = 1:numel(values)
    value = mod(values(index), 65536);
    bytes(2 * index - 1) = mod(value, 256);
    bytes(2 * index) = floor(value / 256);
  end
  fid = fopen(path, 'wb');
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
function ecglabTestWord(fid, value)
  value = mod(value, 65536);
  fwrite(fid, [mod(value, 256), floor(value / 256)], 'uint8');
end
%=============================================================================
