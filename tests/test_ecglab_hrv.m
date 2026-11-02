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
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
% The time-domain measures match a hand computation on a short NN series. Its
% successive differences are 30, -30, 70, -70, 80 ms (three over 50 ms, all
% five over 20 ms) and 800 ms appears three times. No cleaning runs, so the NN
% series equals the input.
nnms = [800, 830, 800, 870, 800, 880];
nn = nnms / 1000;
hrv = ecglab.hrv(nn, 'Input', 'rr', 'Unit', 'seconds', 'Ectopic', 'none', ...
'Range', [], 'Interp', 'none');
assert_isequal(hrv.kind, 'ecglab.hrv');
% SDNN is the sample standard deviation (N - 1) of the NN series in ms.
assert_istrue(abs(hrv.time.sdnn - sqrt(6800 / 5)) < 1e-9, 'SDNN');
% RMSSD is the root mean square of the successive differences.
assert_istrue(abs(hrv.time.rmssd - 60) < 1e-9, 'RMSSD');
% SDSD is the sample standard deviation of the successive differences.
assert_istrue(abs(hrv.time.sdsd - sqrt(16720 / 4)) < 1e-9, 'SDSD');
assert_isequal(hrv.time.nn50, 3);
assert_istrue(abs(hrv.time.pnn50 - 60) < 1e-12, 'pNN50');
assert_isequal(hrv.time.nn20, 5);
assert_istrue(abs(hrv.time.pnn20 - 100) < 1e-12, 'pNN20');
% The triangular index is the NN count over the tallest histogram bin: six
% intervals, the bin at 800 ms holding three, so the index is two.
assert_istrue(abs(hrv.time.triangularIndex - 2) < 1e-12, 'triangular index');
% The histogram bin width is the standard's 1/128 s = 7.8125 ms exactly.
assert_istrue(abs(hrv.time.histogramBinWidth - 1000 / 128) < 1e-12, 'bin width');
assert_istrue(abs(hrv.time.histogramBinWidth - 7.8125) < 1e-12, 'bin is 7.8125 ms');
%=============================================================================
% Poincare SD1 and SD2 match their closed forms on the same series: SD1 is
% sqrt(1/2) times SDSD, SD2 is sqrt(2 SDNN^2 - 1/2 SDSD^2).
sdsd = sqrt(16720 / 4);
sdnn = sqrt(6800 / 5);
assert_istrue(abs(hrv.nonlinear.sd1 - sqrt(0.5) * sdsd) < 1e-9, 'SD1');
assert_istrue(abs(hrv.nonlinear.sd2 - sqrt(2 * sdnn ^ 2 - 0.5 * sdsd ^ 2)) < 1e-9, 'SD2');
assert_istrue(abs(hrv.nonlinear.ellipseArea - pi * hrv.nonlinear.sd1 * hrv.nonlinear.sd2) < 1e-9, 'ellipse');
%=============================================================================
% The frequency estimate recovers the planted LF/HF. The simulator drives the
% RR from a bimodal spectrum of LF/HF ratio 0.5 (peaks near 0.1 and 0.25 Hz),
% so every estimator should give LF/HF near 0.5. The truth RR is used, and the
% tolerance is wide because a spectral estimate scatters.
rec = ecglab.simulate('Seconds', 600, 'HeartRate', 60, 'HeartRateStd', 5, ...
'Seed', 7);
rr = rec.truth.rr;
rr = rr(~isnan(rr));
estimators = {'welch', 'ar', 'lomb'};
for k = 1:numel(estimators)
  h = ecglab.hrv(rr, 'Method', estimators{k}, 'Ectopic', 'none');
  assert_istrue(h.frequency.lf > 0, [estimators{k}, ' LF positive']);
  assert_istrue(h.frequency.hf > 0, [estimators{k}, ' HF positive']);
  assert_istrue(h.frequency.lfhf > 0.3 && h.frequency.lfhf < 0.8, ...
  [estimators{k}, ' LF/HF near 0.5, got ', num2str(h.frequency.lfhf)]);
  assert_istrue(h.frequency.lfPeak >= 0.04 && h.frequency.lfPeak < 0.15, ...
  [estimators{k}, ' LF peak in band']);
  assert_istrue(h.frequency.hfPeak >= 0.15 && h.frequency.hfPeak < 0.4, ...
  [estimators{k}, ' HF peak in band']);
  % Normalised units put LF and HF on the total power minus VLF, which the
  % Task Force defines as everything but VLF, ULF + LF + HF, not LF + HF alone.
  denom = h.frequency.ulf + h.frequency.lf + h.frequency.hf;
  assert_istrue(abs(h.frequency.lfnu - 100 * h.frequency.lf / denom) < 1e-9, ...
  [estimators{k}, ' lfnu is 100 LF / (ULF + LF + HF)']);
  assert_istrue(abs(h.frequency.hfnu - 100 * h.frequency.hf / denom) < 1e-9, ...
  [estimators{k}, ' hfnu is 100 HF / (ULF + LF + HF)']);
end
% The Yule-Walker variant of the AR estimator also recovers the ratio.
hYW = ecglab.hrv(rr, 'Method', 'ar', 'ArMethod', 'yulewalker', 'Ectopic', 'none');
assert_istrue(hYW.frequency.lfhf > 0.3 && hYW.frequency.lfhf < 0.8, ...
'Yule-Walker LF/HF near 0.5');
%=============================================================================
% The normalised units obey the Task Force definition even with ULF power. The
% AR spectrum carries ULF, so lfnu must be 100 LF / (ULF + LF + HF), not
% 100 LF / (LF + HF); with ULF positive the two differ and only the first is
% the standard's. A series with content below 0.003 Hz exposes it.
rngUlf = 123;
rng(rngUlf);
nUlf = 1500;
idxUlf = (1:nUlf)';
% Beats sit near one second apart, so the beat index is close to time in
% seconds: 0.0015 cycles/beat is about 0.0017 Hz (ULF); 0.1 and 0.25 land in
% LF and HF.
ulfWave = 0.08 * sin(2 * pi * 0.0015 * idxUlf);
lfWave = 0.03 * sin(2 * pi * 0.10 * idxUlf);
hfWave = 0.02 * sin(2 * pi * 0.25 * idxUlf);
rrUlf = 0.9 + ulfWave + lfWave + hfWave + 0.005 * randn(nUlf, 1);
hUlf = ecglab.hrv(rrUlf, 'Method', 'ar', 'Ectopic', 'none');
assert_istrue(hUlf.frequency.ulf > 0, 'the AR spectrum carries ULF power');
denomUlf = hUlf.frequency.ulf + hUlf.frequency.lf + hUlf.frequency.hf;
assert_istrue(abs(hUlf.frequency.lfnu - 100 * hUlf.frequency.lf / denomUlf) < 1e-9, ...
'lfnu is 100 LF / (ULF + LF + HF), the total power minus VLF');
assert_istrue(abs(hUlf.frequency.hfnu - 100 * hUlf.frequency.hf / denomUlf) < 1e-9, ...
'hfnu is 100 HF / (ULF + LF + HF)');
% Check the LF + HF denominator gives a strictly larger lfnu here, so the test
% cannot pass by coincidence.
assert_istrue(hUlf.frequency.lfnu < 100 * hUlf.frequency.lf / ...
(hUlf.frequency.lf + hUlf.frequency.hf) - 1e-6, ...
'the ULF term lowers lfnu below the LF + HF denominator value');
% The bands written into the settings are the Task Force's.
assert_isequal(hrv.settings.bands.vlf, [0.003, 0.04]);
assert_isequal(hrv.settings.bands.lf, [0.04, 0.15]);
assert_isequal(hrv.settings.bands.hf, [0.15, 0.4]);
% The settings state estimator, resampling and detrending beside the numbers.
hWelch = ecglab.hrv(rr, 'Method', 'welch', 'Ectopic', 'none');
assert_isequal(hWelch.settings.method, 'welch');
assert_isequal(hWelch.settings.resample, 4);
assert_isequal(hWelch.settings.detrend, 1);
%=============================================================================
% A recording flows end to end: beats are detected and the result is a
% well-formed hrv struct with finite time-domain measures.
recFull = ecglab.hrv(rec);
assert_isequal(recFull.kind, 'ecglab.hrv');
assert_istrue(isfinite(recFull.time.sdnn) && recFull.time.sdnn > 0, ...
'recording SDNN finite');
%=============================================================================
% Each ectopic rule removes the planted ectopic and interpolation fills it. The
% series is sixty 1.0 s intervals with one dropped to 0.55 s; every rule flags
% it and linear interpolation restores 1.0 s. The range filter keeps 0.55 s, so
% only the ectopic rule rejects it.
flat = ones(60, 1);
flat(30) = 0.55;
rules = {'malik', 'kamath', 'karlsson', 'acar', 0.2};
for k = 1:numel(rules)
  h = ecglab.hrv(flat, 'Ectopic', rules{k}, 'Interp', 'linear');
  assert_istrue(h.rejected.ectopicRemoved >= 1, ...
  'the rule removes the ectopic interval');
  assert_isequal(h.rejected.rangeRemoved, 0);
  % The filled series is flat to within rounding: the ectopic is gone.
  assert_istrue(max(abs(h.nn - 1.0)) < 1e-9, 'interpolation fills the gap');
end
% Dropping instead of interpolating shortens the series by the rejected count.
hDrop = ecglab.hrv(flat, 'Ectopic', 'malik', 'Interp', 'none');
assert_istrue(numel(hDrop.nn) == 60 - hDrop.rejected.ectopicRemoved, ...
'none drops the rejected intervals');
assert_istrue(min(hDrop.nn) > 0.9, 'the short interval is gone');
%=============================================================================
% DFA alpha1 is near 1 on a 1/f series and alpha2 near 1.5 on a random walk.
% Both series stay near 1.0 s and positive to pass the filters; DFA is
% invariant to that offset and scale.
rng(42);
% A 1/f (pink) series by shaping a spectrum with amplitude 1/sqrt(f).
N = 4096;
fidx = (1:N / 2)';
amp = 1 ./ sqrt(fidx);
spec = [0; amp .* exp(1i * 2 * pi * rand(N / 2, 1))];
spec = [spec; conj(spec(end - 1:-1:2))];
pink = real(ifft(spec));
pink = pink(1:3000);
pink = 1.0 + 0.02 * pink / std(pink);
hPink = ecglab.hrv(pink, 'Ectopic', 'none');
assert_istrue(abs(hPink.nonlinear.alpha1 - 1) < 0.25, ...
['alpha1 near 1 on 1/f, got ', num2str(hPink.nonlinear.alpha1)]);
% A random walk: the cumulative sum of small steps.
walk = 1.0 + cumsum(0.002 * randn(3000, 1));
hWalk = ecglab.hrv(walk, 'Ectopic', 'none');
assert_istrue(abs(hWalk.nonlinear.alpha2 - 1.5) < 0.25, ...
['alpha2 near 1.5 on a random walk, got ', num2str(hWalk.nonlinear.alpha2)]);
%=============================================================================
% Sample and approximate entropy are finite and in a plausible range on the
% simulated RR series.
assert_istrue(isfinite(recFull.nonlinear.sampen) && ...
recFull.nonlinear.sampen > 0 && recFull.nonlinear.sampen < 3, 'SampEn in range');
assert_istrue(isfinite(recFull.nonlinear.apen) && ...
recFull.nonlinear.apen > 0 && recFull.nonlinear.apen < 3, 'ApEn in range');
%=============================================================================
% The errors: a bad option, too few beats, an unknown estimator, an unknown
% ectopic rule.
assert_checkerror('ecglab.hrv(ones(50, 1), ''Nope'', 1)', 'Unknown option: Nope.');
assert_checkerror('ecglab.hrv([1.0, 1.0])', ...
'Too few intervals to measure variability.');
assert_checkerror('ecglab.hrv(ones(50, 1), ''Method'', ''fourier'')', ...
'Unknown spectral estimator: fourier. Use welch, lomb or ar.');
assert_checkerror('ecglab.hrv(ones(50, 1), ''Ectopic'', ''foo'')', ...
'Unknown ectopic rule: foo.');
%=============================================================================
% Speed: hrv on a long NN series (tens of thousands of intervals) finishes in
% a few seconds. The entropy is capped to bound its quadratic cost.
rng(7);
longNN = 0.8 + 0.05 * randn(40000, 1);
tic;
hLong = ecglab.hrv(longNN, 'Ectopic', 'none');
elapsed = toc;
assert_istrue(isfinite(hLong.time.sdnn), 'long record SDNN finite');
assert_istrue(hLong.settings.entropyCapped, 'the entropy was capped');
assert_istrue(elapsed < 15, ['hrv on 40000 intervals took ', ...
num2str(elapsed), ' s']);
%=============================================================================
% On a real normal-sinus record, when the database is on disk, the measures
% land in the physiological range. The beats are the record's own reference
% annotations.
refRoot = [prefdir(), '/ecglab_reference'];
nsrdbFolder = [refRoot, '/nsrdb'];
if isfolder(nsrdbFolder)
  record = [nsrdbFolder, '/16265'];
  if isfile([record, '.atr'])
    recording = ecglab.readwfdb(record);
    ann = recording.annotations;
    isBeat = ismember(ann.symbol, 'NLRBAaJSVrFejnEfQ/');
    beatTimes = ann.time(isBeat);
    rrNsr = diff(beatTimes);
    hNsr = ecglab.hrv(rrNsr, 'Input', 'rr');
    assert_istrue(hNsr.time.sdnn > 10 && hNsr.time.sdnn < 300, ...
    ['nsrdb SDNN in range, got ', num2str(hNsr.time.sdnn), ' ms']);
    assert_istrue(hNsr.frequency.lfhf > 0.2 && hNsr.frequency.lfhf < 8, ...
    ['nsrdb LF/HF order 1, got ', num2str(hNsr.frequency.lfhf)]);
  end
else
  % The NSR Database is not on disk; the physiological-range check is skipped.
  disp('nsrdb not on disk under ecglab_reference: skipping the real-record check.');
end
%=============================================================================
