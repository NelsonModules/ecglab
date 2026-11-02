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
% The open databases use WFDB. Every file here is written by this test except
% the real record, which is read only when already on disk.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% Plain signed sixteen bit, two leads interleaved. Gain and baseline turn a
% stored integer into a physical value; the samples cross zero.
raw = [100 -100; 3000 -3000; 5 -5];
writeHeader([folder, '/r16.hea'], 'r16 2 50 3 21:30:00 05/06/2026', ...
  {'r16.dat 16 200(1024)/mV 16 0 100 0 0 MLII', ...
   'r16.dat 16 100(-8)/mV 16 0 3000 0 0 V5'}, ...
  {'# a comment the reader must not take for a signal'});
writeDat([folder, '/r16.dat'], 16, raw, []);
rec = ecglab.readwfdb([folder, '/r16']);
assert_isequal(rec.kind, 'ecglab.recording');
assert_isequal(rec.rate, 50);
assert_isequal(rec.info.format, 'wfdb');
assert_isequal(rec.info.name, 'r16');
assert_isequal(rec.leads, {'MLII', 'V5'});
assert_isequal(rec.units, {'mV', 'mV'});
assert_istrue(rec.info.startTimeKnown);
assert_isequal(rec.info.startTime, '21.30.00');
assert_isequal(rec.info.startDate, '05/06/2026');
assert_isequal(rec.info.comments, ...
  {'a comment the reader must not take for a signal'});
% Physical is (stored minus baseline) over gain, baseline from the bracket.
assert_isapprox(rec.samples(:, 1), (raw(:, 1) - 1024) / 200, 1e-9);
assert_isapprox(rec.samples(:, 2), (raw(:, 2) + 8) / 100, 1e-9);
assert_isequal(rec.gain, [200 100]);
assert_isequal(rec.baseline, [1024 -8]);
% Three samples at fifty hertz.
assert_isapprox(rec.seconds, 3 / 50, 1e-9);
% The name is taken with or without its extension.
again = ecglab.readwfdb([folder, '/r16.hea']);
assert_isequal(again.samples, rec.samples);
% Physical false returns the raw ADC integers, untouched by gain or baseline.
rawrec = ecglab.readwfdb([folder, '/r16'], 'Physical', false);
assert_isequal(rawrec.samples, raw);
%=============================================================================
% The other packings, each a single lead crossing zero. The baseline defaults
% to the ADC zero field when the header has no bracket.
checkFormat(folder, 61, [100 -100 3000 -3000 5 -5], 100, 0);
checkFormat(folder, 80, [10 -10 100 -100 5 -5], 50, 0);
checkFormat(folder, 160, [100 -100 3000 -3000 5 -5], 100, 0);
checkFormat(folder, 24, [7 -7 70000 -70000 5 -5], 1000, 0);
checkFormat(folder, 32, [7 -7 70000 -70000 5 -5], 1000, 0);
checkFormat(folder, 212, [1 -1 2047 -2048 5 -5], 200, 0);
checkFormat(folder, 310, [10 -10 500 -500 5 -5], 100, 0);
checkFormat(folder, 311, [10 -10 500 -500 5 -5], 100, 0);
% The ADC zero is a non-zero baseline when no bracket overrides it.
checkFormat(folder, 16, [100 -100 3000 -3000 5 -5], 200, 1024);
%=============================================================================
% Format 8 is first differences: signed eight bit steps, the first measured
% from the initial value field.
wave = [5 -5 10 -10 3 -3];
initial = 0;
diffs = [wave(1) - initial, diff(wave)];
writeHeader([folder, '/r8.hea'], 'r8 1 100 6', ...
  {sprintf('r8.dat 8 100 8 0 %d 0 0 ECG', initial)}, {});
writeDat([folder, '/r8.dat'], 8, diffs(:), []);
got = ecglab.readwfdb([folder, '/r8']);
assert_isapprox(got.samples, wave(:) / 100, 1e-9);
%=============================================================================
% A plus sign after the format is a byte offset: 16+24 is sixteen bit starting
% twenty four bytes into the file.
shifted = [7 -7 70 -70 700 -700]';
writeHeader([folder, '/shift.hea'], 'shift 1 100 6', ...
  {'shift.dat 16+24 100/mV 16 0 7 0 0 Flow'}, {});
fid = fopen([folder, '/shift.dat'], 'wb');
fwrite(fid, 255 * ones(1, 24), 'uint8');
fclose(fid);
appendDat([folder, '/shift.dat'], 16, shifted);
moved = ecglab.readwfdb([folder, '/shift']);
assert_isapprox(moved.samples, shifted / 100, 1e-9);
%=============================================================================
% Two leads in two files, each a signed sixteen bit stream, paired by column.
a = [1 -1 2 -2]';
b = [10 -10 20 -20]';
writeHeader([folder, '/split.hea'], 'split 2 100 4', ...
  {'split1.dat 16 100 16 0 1 0 0 A', 'split2.dat 16 100 16 0 10 0 0 B'}, {});
writeDat([folder, '/split1.dat'], 16, a, []);
writeDat([folder, '/split2.dat'], 16, b, []);
spl = ecglab.readwfdb([folder, '/split']);
assert_isapprox(spl.samples, [a / 100, b / 100], 1e-9);
%=============================================================================
% A multi-frequency record: the second lead has two samples per frame, the
% first one. Returned at the highest rate, the slow lead is held.
flat = [10, 20, -20, -30, 40, -40, 50, 60, -60];
writeHeader([folder, '/mf.hea'], 'mf 2 100 3', ...
  {'mf.dat 16x1 100 16 0 10 0 0 A', 'mf.dat 16x2 100 16 0 20 0 0 B'}, {});
writeDatFlat([folder, '/mf.dat'], 16, flat);
mf = ecglab.readwfdb([folder, '/mf']);
assert_istrue(mf.info.multiFrequency);
assert_isequal(mf.info.frameRate, 100);
assert_isequal(mf.rate, 200);
assert_isapprox(mf.samples(:, 1), [10 10 -30 -30 50 50]' / 100, 1e-9);
assert_isapprox(mf.samples(:, 2), [20 -20 40 -40 60 -60]' / 100, 1e-9);
%=============================================================================
% A fixed-layout multi-segment record: segments are concatenated and a null
% segment (~) becomes NaN, so a gap stays a gap.
s1 = [1 -1; 2 -2; 3 -3; 4 -4];
s2 = [7 -7; 8 -8; 9 -9];
writeHeader([folder, '/seg1.hea'], 'seg1 2 100 4', ...
  {'seg1.dat 16 100 16 0 1 0 0 A', 'seg1.dat 16 100 16 0 -1 0 0 B'}, {});
writeDat([folder, '/seg1.dat'], 16, s1, []);
writeHeader([folder, '/seg2.hea'], 'seg2 2 100 3', ...
  {'seg2.dat 16 100 16 0 7 0 0 A', 'seg2.dat 16 100 16 0 -7 0 0 B'}, {});
writeDat([folder, '/seg2.dat'], 16, s2, []);
writeHeader([folder, '/multi.hea'], 'multi/3 2 100 9', ...
  {'seg1 4', '~ 2', 'seg2 3'}, {});
ms = ecglab.readwfdb([folder, '/multi']);
assert_isequal(size(ms.samples), [9 2]);
assert_isapprox(ms.samples(1:4, :), s1 / 100, 1e-9);
assert_istrue(all(all(isnan(ms.samples(5:6, :)))));
assert_isapprox(ms.samples(7:9, :), s2 / 100, 1e-9);
%=============================================================================
% Annotations in MIT format. The top six bits are the code, the bottom ten the
% gap; code 59 carries a long gap, 63 text, and 60, 61, 62 num, subtype, chan.
fid = fopen([folder, '/r16.atr'], 'wb');
% A rhythm change at sample 19, aux (N, padded to an even byte count.
writeWord(fid, 28 * 1024 + 18);
writeWord(fid, 63 * 1024 + 3);
fwrite(fid, [double('(N'), 0, 0], 'uint8');
% A normal beat 50 samples on: num 5 sticks, subtype 2 does not.
writeWord(fid, 61 * 1024 + 2);
writeWord(fid, 1 * 1024 + 50);
writeWord(fid, 60 * 1024 + 5);
% A ventricular beat 100 samples on, channel 1: num inherited, channel sticks.
writeWord(fid, 1 * 1024 + 100);
writeWord(fid, 62 * 1024 + 1);
% Relabel it a PVC by its own word is not possible; emit a fresh V beat.
writeWord(fid, 5 * 1024 + 100);
writeWord(fid, 0);
fclose(fid);
ann = ecglab.readwfdb([folder, '/r16'], 'Annotations', 'atr');
a = ann.annotations;
assert_isequal(a.kind, 'ecglab.annotations');
assert_isequal(numel(a.sample), 4);
assert_isequal(a.sample, [19; 69; 169; 269]);
assert_isequal(a.symbol, ['+'; 'N'; 'N'; 'V']);
assert_isequal(a.aux{1}, '(N');
assert_isequal(a.aux{2}, '');
% Num 5 is set on the second beat and sticks to every one after it.
assert_isequal(a.num, [0; 5; 5; 5]);
% Subtype 2 touches only the beat it precedes.
assert_isequal(a.subtype, [0; 2; 0; 0]);
% Channel 1 is set on the third beat and sticks.
assert_isequal(a.chan, [0; 0; 1; 1]);
% The time is (sample minus one) over the rate.
assert_isapprox(a.time, ([19; 69; 169; 269] - 1) / 50, 1e-9);
% Auto reads NAME.atr when it is there without being told the extension.
auto = ecglab.readwfdb([folder, '/r16']);
assert_isequal(numel(auto.annotations.sample), 4);
% False reads none even when the file is there.
none = ecglab.readwfdb([folder, '/r16'], 'Annotations', false);
assert_isequal(numel(none.annotations.sample), 0);
% A full file path is taken as well as an extension.
byPath = ecglab.readwfdb([folder, '/r16'], 'Annotations', [folder, '/r16.atr']);
assert_isequal(numel(byPath.annotations.sample), 4);
%=============================================================================
% The long gap of code 59 is signed, high half first. A gap of minus one then
% a beat one sample on lands a mark at sample one.
fid = fopen([folder, '/r16.neg'], 'wb');
writeWord(fid, 59 * 1024);
writeWord(fid, 65535);
writeWord(fid, 65535);
writeWord(fid, 1 * 1024 + 1);
writeWord(fid, 0);
fclose(fid);
neg = ecglab.readwfdb([folder, '/r16'], 'Annotations', 'neg');
assert_isequal(numel(neg.annotations.sample), 1);
% Minus one plus one is file time zero, which is sample one.
assert_isequal(neg.annotations.sample, 1);
%=============================================================================
% The Leads option keeps only the named or numbered leads, in the order asked.
kept = ecglab.readwfdb([folder, '/r16'], 'Leads', {'V5'});
assert_isequal(kept.leads, {'V5'});
assert_isapprox(kept.samples, (raw(:, 2) + 8) / 100, 1e-9);
byIndex = ecglab.readwfdb([folder, '/r16'], 'Leads', [2 1]);
assert_isequal(byIndex.leads, {'V5', 'MLII'});
%=============================================================================
% Errors, each a sentence naming the file or the format.
assert_checkerror(['ecglab.readwfdb(''', folder, '/absent'')'], ...
  ['The file ', folder, '/absent.hea is not on disk.']);
writeHeader([folder, '/short.hea'], 'short 3 100 2', ...
  {'short.dat 16 100 16 0 0 0 0 Flow'}, {});
assert_checkerror(['ecglab.readwfdb(''', folder, '/short'')'], ...
  ['The header ', folder, ...
  '/short.hea announces 3 signals and describes 1.']);
writeHeader([folder, '/flac.hea'], 'flac 1 100 4', ...
  {'flac.dat 508 100 16 0 0 0 0 ECG'}, {});
assert_checkerror(['ecglab.readwfdb(''', folder, '/flac'')'], ...
  'Format 508 (FLAC) is compressed and is not read.');
assert_checkerror(['ecglab.readwfdb(''', folder, '/r16'', ''Where'', 1)'], ...
  'Unknown option: Where.');
assert_checkerror(['ecglab.readwfdb(''', folder, '/r16'', ''Annotations'')'], ...
  'Options come in name and value pairs.');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
% Record 100 of the arrhythmia database, read only when already on disk.
ref = [prefdir(), '/ecglab_reference/mitdb'];
if isfile([ref, '/100.hea']) && isfile([ref, '/100.dat']) && ...
  isfile([ref, '/100.atr'])
  r = ecglab.readwfdb([ref, '/100']);
  assert_isequal(r.rate, 360);
  assert_isequal(size(r.samples), [650000 2]);
  assert_isequal(r.leads, {'MLII', 'V5'});
  % Initial value 995, ADC zero 1024, so the first sample is -0.145 mV.
  assert_isapprox(r.samples(1, 1), -0.145, 1e-9);
  ra = ecglab.readwfdb([ref, '/100']);
  s = ra.annotations.symbol;
  assert_isequal(numel(s), 2274);
  assert_isequal(sum(s == 'N'), 2239);
  assert_isequal(sum(s == 'A'), 33);
  assert_isequal(sum(s == 'V'), 1);
  assert_isequal(sum(s == '+'), 1);
  % The first mark is the rhythm change at sample 19, aux the rhythm label.
  assert_isequal(ra.annotations.symbol(1), '+');
  assert_isequal(ra.annotations.sample(1), 19);
  assert_isequal(ra.annotations.aux{1}, '(N');
else
  disp('skip: record 100 of the arrhythmia database is not on disk.');
end
%=============================================================================
function writeHeader(path, recordLine, bodyLines, commentLines)
  fid = fopen(path, 'wt');
  fprintf(fid, '%s\n', recordLine);
  for index = 1:numel(bodyLines)
    fprintf(fid, '%s\n', bodyLines{index});
  end
  for index = 1:numel(commentLines)
    fprintf(fid, '%s\n', commentLines{index});
  end
  fclose(fid);
end
%=============================================================================
function checkFormat(folder, format, values, gain, zero)
  % A single lead written in FORMAT, read back and checked sample by sample.
  base = [folder, '/fmt', int2str(format)];
  writeHeader([base, '.hea'], ...
    sprintf('fmt%d 1 100 %d', format, numel(values)), ...
    {sprintf('fmt%d.dat %d %d 16 %d %d 0 0 ECG', format, format, gain, ...
    zero, values(1))}, {});
  writeDat([base, '.dat'], format, values(:), []);
  got = ecglab.readwfdb(base);
  assert_isapprox(got.samples, (values(:) - zero) / gain, 1e-9);
end
%=============================================================================
function writeDat(path, format, raw, initvals)
  % RAW is one column per lead; interleave frame by frame and encode.
  flat = reshape(raw', 1, []);
  writeDatFlat(path, format, flat);
end
%=============================================================================
function appendDat(path, format, raw)
  flat = reshape(raw', 1, []);
  bytes = encodeFormat(format, flat);
  fid = fopen(path, 'ab');
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
function writeDatFlat(path, format, flat)
  bytes = encodeFormat(format, flat);
  fid = fopen(path, 'wb');
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
function bytes = encodeFormat(format, v)
  switch format
    case 16
      bytes = enc16(v);
    case 8
      d = mod(v, 256);
      bytes = d;
    case 61
      w = mod(v, 65536);
      bytes = zeros(1, 2 * numel(v));
      bytes(1:2:end) = floor(w / 256);
      bytes(2:2:end) = mod(w, 256);
    case 80
      bytes = mod(v + 128, 256);
    case 160
      w = mod(v + 32768, 65536);
      bytes = zeros(1, 2 * numel(v));
      bytes(1:2:end) = mod(w, 256);
      bytes(2:2:end) = floor(w / 256);
    case 212
      bytes = enc212(v);
    case 24
      w = mod(v, 2 ^ 24);
      bytes = zeros(1, 3 * numel(v));
      bytes(1:3:end) = mod(w, 256);
      bytes(2:3:end) = mod(floor(w / 256), 256);
      bytes(3:3:end) = floor(w / 65536);
    case 32
      w = mod(v, 2 ^ 32);
      bytes = zeros(1, 4 * numel(v));
      bytes(1:4:end) = mod(w, 256);
      bytes(2:4:end) = mod(floor(w / 256), 256);
      bytes(3:4:end) = mod(floor(w / 65536), 256);
      bytes(4:4:end) = floor(w / 16777216);
    case 310
      bytes = enc310(v);
    case 311
      bytes = enc311(v);
    otherwise
      error('test encode: unknown format');
  end
end
%=============================================================================
function bytes = enc16(v)
  w = mod(v, 65536);
  bytes = zeros(1, 2 * numel(v));
  bytes(1:2:end) = mod(w, 256);
  bytes(2:2:end) = floor(w / 256);
end
%=============================================================================
function bytes = enc212(v)
  bytes = [];
  for index = 1:2:numel(v)
    one = mod(v(index), 4096);
    two = mod(v(index + 1), 4096);
    bytes(end + 1) = mod(one, 256);
    bytes(end + 1) = floor(one / 256) + 16 * floor(two / 256);
    bytes(end + 1) = mod(two, 256);
  end
end
%=============================================================================
function bytes = enc310(v)
  bytes = [];
  for index = 1:3:numel(v)
    s0 = mod(v(index), 1024);
    s1 = mod(v(index + 1), 1024);
    s2 = mod(v(index + 2), 1024);
    w0 = s0 * 2 + mod(s2, 32) * 2048;
    w1 = s1 * 2 + floor(s2 / 32) * 2048;
    bytes(end + 1) = mod(w0, 256);
    bytes(end + 1) = floor(w0 / 256);
    bytes(end + 1) = mod(w1, 256);
    bytes(end + 1) = floor(w1 / 256);
  end
end
%=============================================================================
function bytes = enc311(v)
  bytes = [];
  for index = 1:3:numel(v)
    s0 = mod(v(index), 1024);
    s1 = mod(v(index + 1), 1024);
    s2 = mod(v(index + 2), 1024);
    value = s0 + s1 * 1024 + s2 * 1048576;
    bytes(end + 1) = mod(value, 256);
    bytes(end + 1) = mod(floor(value / 256), 256);
    bytes(end + 1) = mod(floor(value / 65536), 256);
    bytes(end + 1) = floor(value / 16777216);
  end
end
%=============================================================================
function writeWord(fid, value)
  value = mod(value, 65536);
  fwrite(fid, [mod(value, 256), floor(value / 256)], 'uint8');
end
%=============================================================================
