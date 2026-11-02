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
% Every list is hand made so the answer is known: the matching rule, learning
% period, shutdown and class matrix each on a case counted by hand. A real
% record is touched only at the end, when on disk.
rate = 360;
%=============================================================================
% A list against itself is perfect: ten true positives, no miss, no extra, Se
% and PPV both one. The times are past the learning period.
ref = (301:310)';
a = ecglab.validate(ref, ref, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.kind, 'ecglab.agreement');
assert_isequal(a.basis, 'beats');
assert_isequal(a.tp, 10);
assert_isequal(a.fn, 0);
assert_isequal(a.fp, 0);
assert_isapprox(a.se, 1, 1e-12);
assert_isapprox(a.ppv, 1, 1e-12);
assert_isequal(size(a.matched), [10, 2]);
%=============================================================================
% One reference beat with no test beat near it is a single false negative.
test = ref;
test(5) = [];
a = ecglab.validate(test, ref, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 9);
assert_isequal(a.fn, 1);
assert_isequal(a.fp, 0);
%=============================================================================
% One test beat with no reference near it is a single false positive.
test = [ref; 305.5];
a = ecglab.validate(test, ref, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 10);
assert_isequal(a.fn, 0);
assert_isequal(a.fp, 1);
%=============================================================================
% The EC57 matching window is 150 ms: a beat 140 ms away is paired, one 160 ms
% away is a miss and an extra.
a = ecglab.validate(305.14, 305, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 1);
a = ecglab.validate(305.16, 305, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 0);
assert_isequal(a.fn, 1);
assert_isequal(a.fp, 1);
%=============================================================================
% Two test beats straddle one reference: the closer one (305.01, 10 ms) is
% paired, the other (304.90) is an extra.
a = ecglab.validate([304.90, 305.01], 305, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 1);
assert_isequal(a.fp, 1);
assert_isequal(a.fn, 0);
matchedTime = (a.matched(1, 1) - 1) / rate;
assert_istrue(abs(matchedTime - 305.01) < 0.01);
%=============================================================================
% Two close reference beats each keep their own test beat: [0.50 0.60] against
% [0.55 0.65] gives tp 2, fp 0, fn 0. Learning is off here.
a = ecglab.validate([0.50, 0.60], [0.55, 0.65], 'Rate', rate, ...
  'Unit', 'seconds', 'Learning', 0);
assert_isequal(a.tp, 2);
assert_isequal(a.fp, 0);
assert_isequal(a.fn, 0);
%=============================================================================
% The learning period silences the first five minutes on both sides: beats
% before 300 s with no test beat are not misses, the two after it match.
ref = [100; 200; 400; 500];
test = [400; 500];
a = ecglab.validate(test, ref, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 2);
assert_isequal(a.fn, 0);
assert_isequal(a.fp, 0);
%=============================================================================
% A shutdown must not be charged. A '~' mark with the two quality bits opens a
% window the next '~' closes; the two beats inside are shutdownMissed, not FN.
refS = struct();
refS.kind = 'ecglab.annotations';
refS.sample = round([310, 320, 332, 335, 350] * rate)' + 1;
refS.time = (refS.sample - 1) / rate;
refS.symbol = 'NNNNN';
refS.rate = rate;
testS = struct();
testS.kind = 'ecglab.annotations';
testS.sample = round([310, 320, 330, 340, 350] * rate)' + 1;
testS.time = (testS.sample - 1) / rate;
testS.symbol = 'NN~~N';
testS.subtype = [0; 0; 16 + 32; 0; 0];
testS.rate = rate;
a = ecglab.validate(testS, refS, 'Shutdown', true);
assert_isequal(a.tp, 3);
assert_isequal(a.fn, 0);
assert_isequal(a.shutdownMissed, 2);
% With the shutdown disabled the same two beats are ordinary misses.
a = ecglab.validate(testS, refS, 'Shutdown', false);
assert_isequal(a.tp, 3);
assert_isequal(a.fn, 2);
assert_isequal(a.shutdownMissed, 0);
%=============================================================================
% The class matrix is built from per-beat labels. A true V called N is a pair
% at row V column N, and a miss for the VEB statistics.
refC = struct();
refC.kind = 'ecglab.annotations';
refC.sample = round([310, 320, 330] * rate)' + 1;
refC.time = (refC.sample - 1) / rate;
refC.symbol = 'NVN';
refC.rate = rate;
testC = struct();
testC.sample = round([310, 320, 330] * rate)' + 1;
testC.time = (testC.sample - 1) / rate;
testC.label = 'NNN';
testC.rate = rate;
a = ecglab.validate(testC, refC);
% rows are N S V F Q X, columns N S V F Q O.
assert_isequal(a.matrix(1, 1), 2);
assert_isequal(a.matrix(3, 1), 1);
assert_isequal(a.vebSe, 0);
assert_isequal(a.veb.fn, 1);
%=============================================================================
% A constant timing offset leaves the RR intervals untouched: the RMS RR error
% is zero while the mean timing error is the offset of 20 ms.
ref = [301; 301.8; 302.7; 303.5; 304.6];
test = ref + 0.02;
a = ecglab.validate(test, ref, 'Rate', rate, 'Unit', 'seconds');
assert_isequal(a.tp, 5);
assert_isapprox(a.timingMean, 20, 1e-6);
assert_isapprox(a.rrError, 0, 1e-6);
%=============================================================================
% A summary pools counts for the gross figure and averages per-record rates
% for the average figure; the two differ when records differ in size.
ref1 = (301:310)';
a1 = ecglab.validate(ref1, ref1, 'Rate', rate, 'Unit', 'seconds', ...
  'Record', 'r1');
ref2 = 301 + (0:999)' * 0.8;
test2 = ref2;
test2(10:10:end) = [];
a2 = ecglab.validate(test2, ref2, 'Rate', rate, 'Unit', 'seconds', ...
  'Record', 'r2');
assert_isequal(a2.tp, 900);
assert_isequal(a2.fn, 100);
a3 = ecglab.validate(ref1, ref1, 'Rate', rate, 'Unit', 'seconds', ...
  'Record', 'r3');
s = ecglab.validate({a1, a2, a3});
assert_isequal(s.basis, 'summary');
assert_isequal(numel(s.records), 3);
assert_isapprox(s.gross.se, 920 / 1020, 1e-9);
assert_isapprox(s.average.se, (1 + 0.9 + 1) / 3, 1e-9);
assert_istrue(abs(s.gross.se - s.average.se) > 0.01);
%=============================================================================
% The markdown table has one row per record; each name appears once.
md = s.markdown;
lines = strsplit(md, char(10));
counts = [0, 0, 0];
names = {'r1', 'r2', 'r3'};
for index = 1:numel(lines)
  for which = 1:3
    if ~isempty(strfind(lines{index}, names{which}))
      counts(which) = counts(which) + 1;
    end
  end
end
assert_isequal(counts, [1, 1, 1]);
%=============================================================================
% Sample indices and times in seconds are both valid; with learning zero every
% beat counts.
samp = round((1:5) * rate)' + 1;
a = ecglab.validate(samp, samp, 'Rate', rate, 'Unit', 'samples', ...
  'Learning', 0);
assert_isequal(a.tp, 5);
secs = [0.5; 1.0; 1.5];
a = ecglab.validate(secs, secs, 'Rate', rate, 'Unit', 'seconds', ...
  'Learning', 0);
assert_isequal(a.tp, 3);
%=============================================================================
% The errors a caller must be told about, each a sentence.
assert_checkerror(['ecglab.validate([301 302 303], [301 302 303], ', ...
  '''Rate'', 360, ''Unit'', ''seconds'', ''Kind'', ''rhythms'')'], ...
  'The kind rhythms is not implemented yet.');
assert_checkerror('ecglab.validate([1 2 3], [1 2 3])', ...
  'A sampling rate is needed to compare samples to a time window.');
assert_checkerror('ecglab.validate([1 2 3], [], ''Rate'', 360)', ...
  'The reference carries no beats.');
assert_checkerror(['ecglab.validate([1 2 3], [1 2 3], ''Rate'', 360, ', ...
  '''Unit'', ''minutes'')'], 'Unit must be samples or seconds.');
%=============================================================================
% A waves reference in the Lobachevsky convention (num 0 boundaries read from
% the peak next to '(' and ')') is parsed to the right fiducial columns, so
% the QRS and T boundaries pair too (n 2 each).
ludbRate = 250;
ludbSample = [60 70 80 92 100 112 150 175 200, ...
  310 320 330 342 350 362 400 425 450]';
ludbSymbol = repmat('(p)(N)(t)', 1, 2)';
ludbNum = zeros(numel(ludbSample), 1);
refLudb = struct('kind', 'ecglab.annotations', 'sample', ludbSample, ...
  'time', (ludbSample - 1) / ludbRate, 'symbol', ludbSymbol, 'num', ludbNum, ...
  'subtype', ludbNum, 'chan', ludbNum, 'rate', ludbRate);
wcols = nan(2, 12);
wcols(:, 1) = [60; 310];
wcols(:, 2) = [70; 320];
wcols(:, 3) = [80; 330];
wcols(:, 4) = [92; 342];
wcols(:, 6) = [100; 350];
wcols(:, 8) = [112; 362];
wcols(:, 10) = [150; 400];
wcols(:, 11) = [175; 425];
wcols(:, 12) = [200; 450];
testLudb = struct('kind', 'ecglab.waves', 'columns', ...
  {{'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', 'QRSoff', 'J', 'Ton', ...
  'Tpeak', 'Toff'}}, 'sample', wcols, 'time', (wcols - 1) / ludbRate);
aLudb = ecglab.validate(testLudb, refLudb, 'Kind', 'waves', 'Window', 0.15, ...
  'Record', 'ludb');
assert_isequal(aLudb.fiducials.Pon.n, 2);
assert_isequal(aLudb.fiducials.QRSon.n, 2);
assert_isequal(aLudb.fiducials.QRSoff.n, 2);
assert_isequal(aLudb.fiducials.Toff.n, 2);
assert_istrue(abs(aLudb.fiducials.QRSon.mean) < 1e-6);
assert_istrue(abs(aLudb.fiducials.Toff.mean) < 1e-6);
%=============================================================================
% A real record, only when on disk. Record 100's own beats shifted by 20 ms are
% recovered perfectly; dropping every fifth beat costs that many FN past 300 s.
recordPath = ['C:/Users/allan/AppData/Roaming/Nelson/2.0.0/', ...
  'ecglab_reference/mitdb/100'];
if isfile([recordPath, '.hea'])
  recording = ecglab.readwfdb(recordPath);
  ann = recording.annotations;
  recordRate = recording.rate;
  isBeat = ismember(ann.symbol, 'NLRBAaJSVrFejnE/fQ?');
  beatSample = ann.sample(isBeat);
  shifted = beatSample + round(0.02 * recordRate);
  a = ecglab.validate(shifted, ann, 'Rate', recordRate, 'Unit', 'samples');
  assert_isapprox(a.se, 1, 1e-12);
  assert_isapprox(a.ppv, 1, 1e-12);
  assert_isfalse(a.paced);
  dropped = beatSample(5:5:end);
  kept = beatSample;
  kept(5:5:end) = [];
  a = ecglab.validate(kept, ann, 'Rate', recordRate, 'Unit', 'samples');
  droppedAfter = sum((dropped - 1) / recordRate >= 300);
  assert_isequal(a.fn, droppedAfter);
  assert_isequal(a.fp, 0);
else
  disp('Record 100 of the arrhythmia database is not on disk; skipped.');
end
%=============================================================================
