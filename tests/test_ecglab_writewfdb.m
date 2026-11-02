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
% The writer is checked by reading back every format to the quantisation it
% holds. Every file is written by this test.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% A two-lead recording with annotations of every kind: a rhythm change with
% aux, a beat, a ventricular beat on another channel, and one far enough to
% need a skip word.
rate = 360;
n = 6000;
t = (0:n - 1)' / rate;
samples = [sin(2 * pi * 1.3 * t), 0.7 * cos(2 * pi * 0.8 * t)];
rec = makeRecording(samples, rate);
ann = struct();
ann.kind = 'ecglab.annotations';
ann.sample = [19; 1500; 1600; 5000];
ann.time = (ann.sample - 1) / rate;
ann.symbol = ['+'; 'N'; 'V'; 'A'];
ann.num = [0; 5; 5; 5];
ann.subtype = [0; 2; 0; 0];
ann.chan = [0; 0; 1; 1];
ann.aux = {'(N'; ''; ''; 'note'};
ann.rate = rate;
rec.annotations = ann;
%=============================================================================
formats = [16 212 24 32 80 160];
for index = 1:numel(formats)
  format = formats(index);
  % Format 80 holds eight bits, so the gain is kept small enough to fit.
  gain = 200;
  if format == 80
    gain = 20;
  end
  base = [folder, '/rt', int2str(format)];
  ecglab.writewfdb(base, rec, 'Format', format, 'Gain', gain);
  back = ecglab.readwfdb(base);
  % The signal reads back to within half a least significant bit.
  assert_istrue(max(abs(back.samples(:) - rec.samples(:))) < 0.5 / gain);
  assert_isequal(back.leads, rec.leads);
  assert_isequal(back.rate, rate);
  % The annotations come back field by field, NaN compared as equal.
  b = back.annotations;
  assert_istrue(isequaln(b.sample, ann.sample));
  assert_istrue(isequaln(b.symbol, ann.symbol));
  assert_istrue(isequaln(b.num, ann.num));
  assert_istrue(isequaln(b.subtype, ann.subtype));
  assert_istrue(isequaln(b.chan, ann.chan));
  assert_istrue(isequaln(b.aux, ann.aux));
end
%=============================================================================
% The header carries the checksum: the sum of the raw samples mod 65536, read
% as a signed sixteen bit value.
base = [folder, '/sum'];
ecglab.writewfdb(base, rec, 'Format', 16, 'Gain', 200);
adu = round(rec.samples(:, 1) * 200);
expected = mod(sum(adu), 65536);
if expected > 32767
  expected = expected - 65536;
end
lines = readLines([base, '.hea']);
words = strsplit(strtrim(lines{2}), ' ');
assert_isequal(str2double(words{7}), expected);
% The record line carries the name, the count, the rate and the length.
head = strsplit(strtrim(lines{1}), ' ');
assert_isequal(head{1}, 'sum');
assert_isequal(str2double(head{2}), 2);
assert_isequal(str2double(head{3}), 360);
assert_isequal(str2double(head{4}), n);
% A known start time and date are written, with the comments as hash lines.
assert_istrue(~isempty(strfind(lines{1}, '12:00:00')));
assert_istrue(any(cellfun(@(L) ~isempty(strfind(L, '# a note')), lines)));
%=============================================================================
% A recording with no annotations writes no annotation file unless one is named.
plain = makeRecording(samples, rate);
base = [folder, '/plain'];
ecglab.writewfdb(base, plain, 'Format', 16);
assert_isfalse(isfile([base, '.atr']));
assert_istrue(isfile([base, '.hea']));
assert_istrue(isfile([base, '.dat']));
%=============================================================================
% An unaccepted format is refused by name.
refused = false;
message = '';
try
  ecglab.writewfdb([folder, '/bad'], plain, 'Format', 99);
catch problem
  refused = true;
  message = problem.message;
end
assert_istrue(refused);
assert_isequal(message, ...
  'Format 99 is not a WFDB signal format this writer knows.');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function rec = makeRecording(samples, rate)
  rec = struct();
  rec.kind = 'ecglab.recording';
  rec.rate = rate;
  rec.samples = samples;
  rec.leads = {'MLII', 'V5'};
  rec.units = {'mV', 'mV'};
  rec.seconds = size(samples, 1) / rate;
  info = struct('name', 'sum', 'source', '', 'format', 'wfdb', ...
    'startTime', '12.00.00', 'startTimeKnown', true, ...
    'startDate', '01/01/2026', 'subject', '', 'comments', {{'a note'}});
  rec.info = info;
  empty = struct('kind', 'ecglab.annotations', 'sample', zeros(0, 1), ...
    'time', zeros(0, 1), 'symbol', char(zeros(0, 1)), 'num', zeros(0, 1), ...
    'subtype', zeros(0, 1), 'chan', zeros(0, 1), 'aux', {cell(0, 1)}, ...
    'rate', rate);
  rec.annotations = empty;
  rec.gain = [200 200];
  rec.baseline = [0 0];
end
%=============================================================================
function lines = readLines(path)
  text = fileread(path);
  lines = strsplit(strrep(text, char(13), ''), char(10));
  lines = lines(~cellfun(@isempty, lines));
end
%=============================================================================
