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
%=============================================================================
% A clean simulated recording is good on almost every window: detectors agree,
% the trace is peaky, and the usable fraction is near one.
rec = ecglab.simulate('Seconds', 120, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
q = ecglab.quality(rec);
assert_isequal(q.kind, 'ecglab.quality');
assert_isequal(q.window, 10);
assert_isequal(q.step, 10);
W = numel(q.time);
assert_isequal(size(q.bsqi), [W, 1]);
assert_isequal(size(q.ksqi), [W, 1]);
assert_isequal(size(q.psqi), [W, 1]);
assert_isequal(size(q.bassqi), [W, 1]);
assert_isequal(size(q.orphanidou), [W, 1]);
assert_isequal(size(q.acceptable), [W, 1]);
assert_istrue(islogical(q.acceptable));
assert_istrue(islogical(q.orphanidou));
assert_istrue(q.usableFraction > 0.95);
assert_istrue(median(q.bsqi) > 0.95);
assert_istrue(median(q.ksqi) > 8);
assert_istrue(q.good > 100);
assert_isequal(q.settings.Lead, 'II');
%=============================================================================
% Default step equals the window, so windows tile the record without overlap.
assert_isequal(W, 12);
assert_isapprox(q.time(1), 5, 1e-9);
assert_isapprox(q.time(2) - q.time(1), 10, 1e-9);
% A smaller step overlaps the windows, so there are more of them.
qOv = ecglab.quality(rec, 'Window', 10, 'Step', 5);
assert_istrue(numel(qOv.time) > W);
assert_isapprox(qOv.time(2) - qOv.time(1), 5, 1e-9);
%=============================================================================
% Clean for two thirds, then wrecked by strong noise: the last third is
% unacceptable, so the usable fraction is about two thirds.
rng(7);
recNoise = ecglab.simulate('Seconds', 180, 'Rate', 360, 'HeartRate', 60, ...
'Seed', 2);
N = size(recNoise.samples, 1);
third = round(2 * N / 3);
recNoise.samples(third + 1:end, 1) = recNoise.samples(third + 1:end, 1) + ...
0.5 * randn(N - third, 1);
qN = ecglab.quality(recNoise, 'Window', 10, 'Step', 10);
cleanWin = qN.time <= (third - 1) / 360;
noisyWin = ~cleanWin;
assert_istrue(qN.usableFraction > 0.55);
assert_istrue(qN.usableFraction < 0.80);
assert_istrue(qN.good >= 100);
assert_istrue(qN.good <= 125);
assert_istrue(mean(qN.acceptable(cleanWin)) > 0.9);
assert_istrue(mean(qN.acceptable(noisyWin)) < 0.25);
% bSQI is lower on the noisy windows, where the two detectors disagree.
assert_istrue(median(qN.bsqi(noisyWin)) < median(qN.bsqi(cleanWin)));
% kSQI is higher on the clean windows: a clean ECG is peaky, noise is not.
assert_istrue(median(qN.ksqi(cleanWin)) > median(qN.ksqi(noisyWin)));
%=============================================================================
% Orphanidou rules, each failed by a constructed beat train over one window.
% A normal 75 bpm train passes every rule.
rate = 360;
normal = ecglabQualitySynth(0.8:0.8:9.5, rate, 10);
qOk = ecglab.quality(normal, 'Rate', rate, 'Window', 10);
assert_isequal(numel(qOk.orphanidou), 1);
assert_istrue(qOk.orphanidou);
assert_istrue(qOk.acceptable);
% A four second pause: one RR exceeds the three second limit.
pause = ecglabQualitySynth([0.8 1.6 2.4 3.2 7.2 8.0 8.8 9.6], rate, 10);
qP = ecglab.quality(pause, 'Rate', rate, 'Window', 10);
assert_isfalse(qP.orphanidou(1));
% A doubled then halved RR breaks only the ratio rule (max over min above 2.2).
ratio = ecglabQualitySynth([0.8 1.6 2.4 4.0 4.4 5.2 6.0 6.8 7.6 8.4 9.2], ...
rate, 10);
qR = ecglab.quality(ratio, 'Rate', rate, 'Window', 10);
assert_isfalse(qR.orphanidou(1));
% A slow 30 bpm train: the heart rate is below the rule's minimum of 40.
slow = ecglabQualitySynth([0.8 2.8 4.8 6.8 8.8], rate, 10);
qS = ecglab.quality(slow, 'Rate', rate, 'Window', 10);
assert_isfalse(qS.orphanidou(1));
% A flat window has no beats, so it is not acceptable.
qF = ecglab.quality(zeros(round(10 * rate), 1), 'Rate', rate, 'Window', 10);
assert_isfalse(qF.orphanidou(1));
assert_isfalse(qF.acceptable(1));
%=============================================================================
% The four rules each decide what acceptable means; on the clean recording
% every rule accepts nearly every window.
qB = ecglab.quality(rec, 'Rule', 'bsqi');
qO = ecglab.quality(rec, 'Rule', 'orphanidou');
qZ = ecglab.quality(rec, 'Rule', 'zhao');
assert_istrue(qB.usableFraction > 0.95);
assert_istrue(qO.usableFraction > 0.95);
assert_istrue(qZ.usableFraction > 0.95);
assert_isequal(numel(qZ.zhao), numel(qZ.time));
assert_istrue(ischar(qZ.zhao{1}));
% The bSQI rule follows its threshold; a threshold above one accepts nothing.
qHigh = ecglab.quality(rec, 'Rule', 'bsqi', 'BsqiThreshold', 1.01);
assert_isequal(qHigh.usableFraction, 0);
%=============================================================================
% A plain signal vector is accepted when its rate is given.
vec = rec.samples(:, 1);
qVec = ecglab.quality(vec, 'Rate', 360);
assert_isequal(qVec.kind, 'ecglab.quality');
assert_istrue(qVec.usableFraction > 0.95);
%=============================================================================
% Errors: signal too short, unknown option, unknown rule, vector with no rate.
short = rec.samples(1:round(5 * 360), 1);
assert_checkerror('ecglab.quality(short, ''Rate'', 360, ''Window'', 10)', ...
'The signal is shorter than one window.');
assert_checkerror('ecglab.quality(rec, ''Nope'', 1)', 'Unknown option: Nope.');
assert_checkerror('ecglab.quality(rec, ''Rule'', ''best'')', ...
'The rule must be bsqi, orphanidou, both or zhao.');
assert_checkerror('ecglab.quality(vec)', ...
'A signal vector needs its sampling rate, given as Rate.');
%=============================================================================
% The two detectors run once each, not once per window, so quality on a long
% record costs about two detections plus a small overhead.
big = ecglab.simulate('Seconds', 1800, 'Rate', 360, 'HeartRate', 72, 'Seed', 3);
t0 = tic();
ecglab.detect(big, 'Method', 'pantompkins');
ecglab.detect(big, 'Method', 'wqrs');
twoDetections = toc(t0);
t0 = tic();
ecglab.quality(big, 'Detectors', {'pantompkins', 'wqrs'});
qualityTime = toc(t0);
fprintf('quality 30 min: two detections %.3f s, quality %.3f s\n', ...
twoDetections, qualityTime);
% The windowing overhead is small; quality stays under twice two detections.
assert_istrue(qualityTime < 2 * twoDetections + 2);
%=============================================================================
% A Noise Stress Test record, only if that database is on disk. Unacceptable
% windows must fall in the known noisy segments far more than in the clean ones.
nstPath = [prefdir(), '/ecglab_reference/nstdb/118e00.hea'];
if isfile(nstPath)
  nst = ecglab.reference('nstdb/118e00');
  qNst = ecglab.quality(nst, 'Window', 10, 'Step', 10);
  % NST protocol: clean for 300 s, then noise in alternating two minute segments.
  c = qNst.time;
  noisy = c >= 300 & mod(floor((c - 300) / 120), 2) == 0;
  clean = ~noisy;
  fracNoisy = mean(~qNst.acceptable(noisy));
  fracClean = mean(~qNst.acceptable(clean));
  fprintf('nstdb/118e00: unacceptable in noisy %.2f, in clean %.2f\n', ...
  fracNoisy, fracClean);
  assert_istrue(fracNoisy > fracClean);
  assert_istrue(fracNoisy > 0.5);
else
  warning('The Noise Stress record nstdb/118e00 is not on disk; its check is skipped.');
end
%=============================================================================
function signal = ecglabQualitySynth(beatTimes, rate, seconds)
  % A signal from a known beat train: a narrow R peak and a small T wave per
  % beat, which both detectors find exactly, so the test controls the RR series.
  N = round(seconds * rate);
  t = (0:N - 1)' / rate;
  signal = zeros(N, 1);
  beatTimes = beatTimes(:);
  for k = 1:numel(beatTimes)
    signal = signal + 1.0 * exp(-((t - beatTimes(k)) .^ 2) / (2 * 0.008 ^ 2));
    signal = signal + 0.2 * ...
    exp(-((t - beatTimes(k) - 0.2) .^ 2) / (2 * 0.04 ^ 2));
  end
end
%=============================================================================
