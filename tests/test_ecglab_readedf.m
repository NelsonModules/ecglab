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
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% EDF is a recorder and laboratory format. Every file here is written by this
% test, with planted values chosen to catch header or byte-order errors.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% A plain EDF of two signals at different rates. The slow one is held to the
% fast rate, info.rates keeps each native rate, and physical equals stored.
plain = [folder, '/plain.edf'];
S = struct();
S.patient = 'Patient_7';
S.recid = 'Startdate 01-FEB-2003';
S.startdate = '01.02.03';
S.starttime = '12.34.56';
S.reserved = '';
S.recordDuration = 1;
S.nrec = 3;
S.labels = {'ECG1', 'ECG2'};
S.dims = {'mV', 'mV'};
S.pmin = [-32768, -32768];
S.pmax = [32767, 32767];
S.dmin = [-32768, -32768];
S.dmax = [32767, 32767];
S.nsamp = [2, 1];
% Two samples per record for the fast signal, one for the slow one.
S.data = {[10 20 30 40 50 60], [100 200 300]};
edfHandWrite(plain, S);
%=============================================================================
recording = ecglab.readedf(plain);
assert_isequal(recording.kind, 'ecglab.recording');
assert_isequal(recording.info.format, 'edf');
% The output is at the highest rate among the selected leads.
assert_isequal(recording.rate, 2);
assert_isequal(recording.leads, {'ECG1', 'ECG2'});
% Each lead's native rate is kept.
assert_isequal(recording.info.rates, [2, 1]);
assert_isequal(size(recording.samples), [6, 2]);
% The fast signal is itself; the slow one is held, each value twice.
assert_isapprox(recording.samples(:, 1), [10; 20; 30; 40; 50; 60], 1e-6);
assert_isapprox(recording.samples(:, 2), [100; 100; 200; 200; 300; 300], 1e-6);
assert_isequal(recording.units, {'mV', 'mV'});
% A plain EDF carries a start clock; the two digit year expands by the format
% rule (00 to 84 is the 2000s).
assert_isequal(recording.info.startTime, '12.34.56');
assert_istrue(recording.info.startTimeKnown);
assert_isequal(recording.info.startDate, '01/02/2003');
assert_isequal(recording.info.subject, 'Patient_7');
% A plain EDF is not discontinuous.
assert_isfalse(recording.info.discontinuous);
%=============================================================================
% Selecting one lead by its label returns only it, at its own rate.
just = ecglab.readedf(plain, 'Leads', {'ECG2'});
assert_isequal(just.rate, 1);
assert_isequal(just.leads, {'ECG2'});
assert_isequal(just.info.rates, 1);
assert_isapprox(just.samples, [100; 200; 300], 1e-6);
% Selecting the same lead by its index gives the same thing.
byIndex = ecglab.readedf(plain, 'Leads', 2);
assert_isequal(byIndex.leads, {'ECG2'});
%=============================================================================
% An EDF+ file with an annotation (TAL) signal: a time-keeping TAL per record,
% one with a duration, one with multi-byte text, and one with a negative onset.
plus = [folder, '/plus.edf'];
t20 = 20; t21 = 21; t0 = 0;
rec0 = [double('+0'), t20, t20, t0, ...
  double('-1'), t20, double('N'), t20, t0, ...
  double('+0.5'), t21, double('0.2'), t20, double('V'), t20, t0, ...
  double('+0.7'), t20, double('AFIB beat'), t20, t0];
rec1 = [double('+1'), t20, t20, t0];
annotSamples = ceil(max(numel(rec0), numel(rec1)) / 2);
annotWords = edfPackTal({rec0, rec1}, annotSamples);
P = struct();
P.patient = 'X X X X';
P.recid = 'Startdate 05-JUL-2021';
P.startdate = '05.07.21';
P.starttime = '23.00.00';
P.reserved = 'EDF+C';
P.recordDuration = 1;
P.nrec = 2;
P.labels = {'ECG', 'EDF Annotations'};
P.dims = {'mV', ''};
P.pmin = [-5, -1];
P.pmax = [5, 1];
P.dmin = [-32768, -32768];
P.dmax = [32767, 32767];
P.nsamp = [10, annotSamples];
P.data = {1:20, annotWords};
edfHandWrite(plus, P);
%=============================================================================
marked = ecglab.readedf(plus);
% The annotation signal is never returned as a lead.
assert_isequal(marked.leads, {'ECG'});
assert_isequal(marked.rate, 10);
% Three annotations: the two time-keeping TALs carry no text and are dropped.
assert_isequal(numel(marked.annotations.sample), 3);
% sample = round(onset * rate) + 1; a negative onset lands below one and is kept.
assert_isequal(marked.annotations.sample, [-9; 6; 8]);
assert_isequal(marked.annotations.symbol, ['N'; 'V'; '"']);
% A single PhysioNet symbol becomes the symbol; other text becomes a note with
% the text in aux.
assert_isequal(marked.annotations.aux, {''; ''; 'AFIB beat'});
% A duration is kept in num, in samples: 0.2 s at 10 Hz is two samples.
assert_isequal(marked.annotations.num, [0; 2; 0]);
% The patient 'X X X X' is the format's anonymous patient.
assert_isequal(marked.info.subject, 'anonymous');
assert_isequal(marked.info.startDate, '05/07/2021');
assert_isequal(marked.info.startTime, '23.00.00');
assert_isfalse(marked.info.discontinuous);
% Annotations can be turned off.
bare = ecglab.readedf(plus, 'Annotations', false);
assert_isequal(numel(bare.annotations.sample), 0);
%=============================================================================
% Errors: a missing file, and a file that is not an EDF header.
absent = [folder, '/nope.edf'];
assert_checkerror(['ecglab.readedf(''', absent, ''')'], ...
  ['The file ', absent, ' is not on disk.']);
notedf = [folder, '/notedf.edf'];
fid = fopen(notedf, 'wb');
fwrite(fid, double('X') * ones(1, 300), 'uint8');
fclose(fid);
assert_checkerror(['ecglab.readedf(''', notedf, ''')'], ...
  ['The file ', notedf, ' is not an EDF file.']);
assert_checkerror(['ecglab.readedf(''', plain, ''', ''Nope'', 1)'], ...
  'Unknown option: Nope.');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function edfHandWrite(path, S)
  % Hand EDF writer: 256 byte main header, the signal header fields, then the
  % interleaved data records. Numbers are ASCII, samples little-endian int16.
  ns = numel(S.labels);
  fid = fopen(path, 'wb');
  fwrite(fid, edfPad('0', 8), 'uint8');
  fwrite(fid, edfPad(S.patient, 80), 'uint8');
  fwrite(fid, edfPad(S.recid, 80), 'uint8');
  fwrite(fid, edfPad(S.startdate, 8), 'uint8');
  fwrite(fid, edfPad(S.starttime, 8), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', 256 * (ns + 1)), 8), 'uint8');
  fwrite(fid, edfPad(S.reserved, 44), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', S.nrec), 8), 'uint8');
  fwrite(fid, edfPad(edfNumber(S.recordDuration), 8), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', ns), 4), 'uint8');
  for i = 1:ns, fwrite(fid, edfPad(S.labels{i}, 16), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad('', 80), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(S.dims{i}, 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(edfNumber(S.pmin(i)), 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(edfNumber(S.pmax(i)), 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(sprintf('%d', S.dmin(i)), 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(sprintf('%d', S.dmax(i)), 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad('', 80), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad(sprintf('%d', S.nsamp(i)), 8), 'uint8'); end
  for i = 1:ns, fwrite(fid, edfPad('', 32), 'uint8'); end
  total = sum(S.nsamp);
  block = zeros(total, S.nrec);
  offs = [0, cumsum(S.nsamp(1:end - 1))];
  for i = 1:ns
    block(offs(i) + 1:offs(i) + S.nsamp(i), :) = ...
    reshape(S.data{i}, S.nsamp(i), S.nrec);
  end
  fwrite(fid, int16(reshape(block, [], 1)), 'int16');
  fclose(fid);
end
%=============================================================================
function words = edfPackTal(perRecord, nsamp)
  % Pad each record's TAL bytes to the signal width and pack two per int16.
  nrec = numel(perRecord);
  words = zeros(nsamp, nrec);
  for r = 1:nrec
    bytes = perRecord{r};
    bytes = [bytes, zeros(1, 2 * nsamp - numel(bytes))];
    low = bytes(1:2:end);
    high = bytes(2:2:end);
    value = low + 256 * high;
    value(value > 32767) = value(value > 32767) - 65536;
    words(:, r) = value(:);
  end
  words = reshape(words, [], 1);
end
%=============================================================================
function out = edfPad(text, width)
  text = char(text);
  if numel(text) >= width
    out = double(text(1:width));
  else
    out = double([text, repmat(' ', 1, width - numel(text))]);
  end
end
%=============================================================================
function s = edfNumber(x)
  if x == round(x)
    s = sprintf('%d', x);
  else
    s = sprintf('%g', x);
  end
end
%=============================================================================
