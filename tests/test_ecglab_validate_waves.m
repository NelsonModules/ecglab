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
% Every delineation and reference is hand made so the answer is known. A real
% record is touched only at the end, when the QT Database is on disk.
rate = 250;
cols = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', 'QRSoff', 'J', ...
'Ton', 'Tpeak', 'Toff'};
%=============================================================================
% A reference of three beats and a delineation shifted forward by two samples
% (8 ms at 250 Hz): the signed error is +8 ms with zero scatter on every mark.
refSample = localReferenceThree();
shift = 2;
delSample = refSample + shift;
ref = localBuildWaves(refSample, rate);
del = localBuildWaves(delSample, rate);
a = ecglab.validate(del, ref, 'Kind', 'waves', 'Record', 'hand');
assert_isequal(a.kind, 'ecglab.agreement');
assert_isequal(a.basis, 'waves');
assert_isequal(a.record, 'hand');
assert_isequal(a.matchedBeats, 3);
expected = shift / rate * 1000;
for name = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'R', 'QRSoff', 'Tpeak', 'Toff'}
  f = a.fiducials.(name{1});
  assert_isequal(f.n, 3);
  assert_istrue(abs(f.mean - expected) < 1e-9);
  assert_istrue(abs(f.sd) < 1e-9);
  assert_istrue(abs(f.se - 1) < 1e-12);
  assert_istrue(abs(f.ppv - 1) < 1e-12);
end
% Q, S, J and Ton are absent on both sides, so their count is zero and mean NaN.
for name = {'Q', 'S', 'J', 'Ton'}
  f = a.fiducials.(name{1});
  assert_isequal(f.n, 0);
  assert_istrue(isnan(f.mean));
end
%=============================================================================
% The CSE tolerances ride on every agreement: five boundaries set, the other
% seven empty.
assert_istrue(abs(a.cse.Pon - 10.2) < 1e-12);
assert_istrue(abs(a.cse.Poff - 12.7) < 1e-12);
assert_istrue(abs(a.cse.QRSon - 6.5) < 1e-12);
assert_istrue(abs(a.cse.QRSoff - 11.6) < 1e-12);
assert_istrue(abs(a.cse.Toff - 30.6) < 1e-12);
assert_isequal(a.cse.R, []);
assert_isequal(a.cse.Ton, []);
%=============================================================================
% An absent reference mark is not counted. Blank the P onset of the middle beat
% on the reference side: its count drops to two, Se one, PPV two thirds.
refGap = refSample;
refGap(2, 1) = NaN;
aGap = ecglab.validate(del, localBuildWaves(refGap, rate), 'Kind', 'waves');
assert_isequal(aGap.fiducials.Pon.n, 2);
assert_istrue(abs(aGap.fiducials.Pon.mean - expected) < 1e-9);
assert_istrue(abs(aGap.fiducials.Pon.se - 1) < 1e-12);
assert_istrue(abs(aGap.fiducials.Pon.ppv - 2 / 3) < 1e-12);
%=============================================================================
% Beat matching ignores an unmatched beat: a fourth delineated beat far from any
% reference pairs with nothing, so the matched count stays three.
delExtra = [delSample; localOneBeat(10 * rate, shift)];
aExtra = ecglab.validate(localBuildWaves(delExtra, rate), ref, 'Kind', 'waves');
assert_isequal(aExtra.matchedBeats, 3);
assert_isequal(aExtra.fiducials.QRSon.n, 3);
%=============================================================================
% The summary pools the raw errors of every beat, not the per-record means:
% two beats at +4 ms and forty at +20 ms pool to 19.238 ms, not 12 ms.
rA = localBuildWaves(localManyBeats(2, 0), rate);
dA = localBuildWaves(localManyBeats(2, 1), rate);
agrA = ecglab.validate(dA, rA, 'Kind', 'waves', 'Record', 'A');
rB = localBuildWaves(localManyBeats(40, 0), rate);
dB = localBuildWaves(localManyBeats(40, 5), rate);
agrB = ecglab.validate(dB, rB, 'Kind', 'waves', 'Record', 'B');
summary = ecglab.validate({agrA, agrB});
assert_isequal(summary.basis, 'summary');
assert_isequal(summary.of, 'waves');
pooled = (2 * 4 + 40 * 20) / 42;
assert_istrue(abs(summary.fiducials.QRSon.mean - pooled) < 1e-6);
assert_isequal(summary.fiducials.QRSon.n, 42);
assert_istrue(abs(summary.fiducials.QRSon.mean - 12) > 1);
%=============================================================================
% The markdown table has one row per fiducial and carries the CSE tolerance.
md = summary.markdown;
assert_istrue(ischar(md));
lines = strsplit(md, char(10));
dataRows = 0;
for i = 1:numel(lines)
  for name = cols
    if ~isempty(strfind(lines{i}, ['| ', name{1}, ' |']))
      dataRows = dataRows + 1;
    end
  end
end
assert_isequal(dataRows, 12);
assert_istrue(~isempty(strfind(md, 'QRSon')));
assert_istrue(~isempty(strfind(md, '6.5')));
%=============================================================================
% Errors: a test that is not a waves struct, a reference with no beats, and a
% summary of agreements of mixed bases.
badTest = struct('kind', 'ecglab.beats', 'sample', [1; 2], 'time', [0; 1]);
emptyRef = localBuildWaves(zeros(0, 12), rate);
assert_checkerror('ecglab.validate(badTest, ref, ''Kind'', ''waves'')', ...
  'The test must be an ecglab.waves struct from ecglab.delineate.');
assert_checkerror('ecglab.validate(del, emptyRef, ''Kind'', ''waves'')', ...
  'The reference carries no beats.');
% A cell of agreements whose bases disagree cannot be summarised as one basis.
beatsAgr = ecglab.validate([301 302 303], [301 302 303], 'Rate', 250, ...
  'Unit', 'seconds');
assert_checkerror('ecglab.validate({agrA, beatsAgr})', ...
  'The agreements to summarise are not of one basis.');
%=============================================================================
% A real record, only when the QT Database is on disk. Delineate sel100's first
% lead against its q1c marks: the QRS onset and offset mean errors within 25 ms.
qtdbOne = [prefdir(), '/ecglab_reference/qtdb/sel100.hea'];
if isfile(qtdbOne)
  recordBase = [prefdir(), '/ecglab_reference/qtdb/sel100'];
  recRef = ecglab.readwfdb(recordBase, 'Annotations', '.q1c');
  wDel = ecglab.delineate(recRef, 'Lead', 1);
  aReal = ecglab.validate(wDel, recRef, 'Kind', 'waves', 'Record', 'sel100');
  fprintf('sel100 QRSon %.2f +/- %.2f ms (n %d), QRSoff %.2f +/- %.2f ms (n %d)\n', ...
  aReal.fiducials.QRSon.mean, aReal.fiducials.QRSon.sd, aReal.fiducials.QRSon.n, ...
  aReal.fiducials.QRSoff.mean, aReal.fiducials.QRSoff.sd, aReal.fiducials.QRSoff.n);
  assert_istrue(aReal.fiducials.QRSon.n > 0);
  assert_istrue(aReal.fiducials.QRSoff.n > 0);
  assert_istrue(abs(aReal.fiducials.QRSon.mean) <= 25);
  assert_istrue(abs(aReal.fiducials.QRSoff.mean) <= 25);
else
  disp('QT Database not on disk: the real-record waves check is skipped.');
end
%=============================================================================
function sample = localReferenceThree()
  % Three beats carrying a P, a QRS and a T but no Q, S, J or T onset.
  sample = zeros(3, 12);
  rPeaks = [300; 600; 900];
  for k = 1:3
    sample(k, :) = localOneBeat(rPeaks(k), 0);
  end
end
%=============================================================================
function row = localOneBeat(rPeak, shift)
  % One beat row around an R peak, every mark shifted by SHIFT; unplaced marks
  % stay NaN.
  row = nan(1, 12);
  row(1) = rPeak - 50 + shift;
  row(2) = rPeak - 38 + shift;
  row(3) = rPeak - 25 + shift;
  row(4) = rPeak - 12 + shift;
  row(6) = rPeak + shift;
  row(8) = rPeak + 12 + shift;
  row(11) = rPeak + 90 + shift;
  row(12) = rPeak + 140 + shift;
end
%=============================================================================
function sample = localManyBeats(count, shift)
  % COUNT beats 200 samples apart, each shifted by SHIFT, so a reference and a
  % delineation of the same count pair beat for beat.
  sample = zeros(count, 12);
  for k = 1:count
    sample(k, :) = localOneBeat(300 + (k - 1) * 200, shift);
  end
end
%=============================================================================
function waves = localBuildWaves(sample, rate)
  % A minimal waves struct: the comparator reads the sample, time and kind.
  waves = struct();
  waves.kind = 'ecglab.waves';
  waves.columns = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', ...
  'QRSoff', 'J', 'Ton', 'Tpeak', 'Toff'};
  waves.sample = sample;
  waves.time = (sample - 1) / rate;
end
%=============================================================================
