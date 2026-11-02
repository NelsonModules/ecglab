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
method = 'wavelet';
%=============================================================================
% The stationary wavelet transform is read through the detector, which stores
% the squared detail coefficients as evidence.feature. The transform is db3 at
% level round(log2(rate / 22.5)), which is 4 at 360 Hz.
rate = 360;
seconds = 4;
N = round(seconds * rate);
level = round(log2(rate / 22.5));
assert_isequal(level, 4);
%=============================================================================
% A step: the detail rejects the constant level, so the squared detail is near
% zero inside each flat stretch and wakes only at the edge.
step = zeros(N, 1);
step(round(N / 2):end) = 1;
bStep = ecglab.detect(step, 'Rate', rate, 'Method', method);
featStep = bStep.evidence.feature;
mid = round(N / 2);
interiorLeft = featStep(round(0.2 * N):round(0.4 * N));
interiorRight = featStep(round(0.6 * N):round(0.8 * N));
edge = featStep(mid - 40:mid + 40);
assert_istrue(max(interiorLeft) < 1e-6);
assert_istrue(max(interiorRight) < 1e-6);
assert_istrue(max(edge) > 1e-3);
%=============================================================================
% An impulse: the detail is the transform's impulse response, localised and
% zero beyond the cascaded filter support (well under 64 samples), so the
% squared detail is exactly zero far from the spike.
impulse = zeros(N, 1);
spike = round(N / 2);
impulse(spike) = 1;
bImp = ecglab.detect(impulse, 'Rate', rate, 'Method', method);
featImp = bImp.evidence.feature;
far = [featImp(1:spike - 128); featImp(spike + 128:end)];
assert_istrue(max(far) < 1e-12);
assert_istrue(sum(featImp) > 0);
assert_istrue(abs(sum(bImp.evidence.filtered)) >= 0);
%=============================================================================
% The detail band is a band pass that selects the QRS: a 16 Hz sine (centre of
% the band, roughly 11 to 22 Hz at 360 Hz and level 4) carries more detail
% energy than a 4 Hz sine below it or a 60 Hz sine above it.
t = (0:N - 1)' / rate;
energyCentre = ecglabWaveletEnergy(sin(2 * pi * 16 * t), rate, method);
energyLow = ecglabWaveletEnergy(sin(2 * pi * 4 * t), rate, method);
energyHigh = ecglabWaveletEnergy(sin(2 * pi * 60 * t), rate, method);
assert_istrue(energyCentre > energyLow);
assert_istrue(energyCentre > energyHigh);
%=============================================================================
% A clean one-minute record at 360 Hz. On a noiseless trace the detector must
% find every planted beat within 20 ms and invent none.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
truth = rec.truth.beats;
window20 = round(0.020 * 360);
beats = ecglab.detect(rec, 'Method', method);
assert_isequal(beats.kind, 'ecglab.beats');
[tp, fp, fn] = ecglabWaveletMatch(beats.sample, truth, window20);
assert_isequal(fn, 0);
assert_isequal(fp, 0);
assert_isequal(tp, numel(truth));
%=============================================================================
% The evidence carries the squared detail as feature, the threshold and the
% band-passed trace, each the length of the signal, and records the level and
% wavelet used.
Nrec = size(rec.samples, 1);
assert_isequal(size(beats.evidence.feature), [Nrec, 1]);
assert_isequal(size(beats.evidence.threshold), [Nrec, 1]);
assert_isequal(size(beats.evidence.filtered), [Nrec, 1]);
assert_isequal(beats.evidence.settings.level, level);
assert_isequal(beats.evidence.settings.wavelet, 'db3');
%=============================================================================
% The a trous transform's private helper must not be named ecgLabDetect*, or
% detect would offer it as a method 'swt' and the default consensus would call
% it. So 'swt' is not a method (it raises unknown-method), and consensus with
% its default method list runs to a beats struct that never lists 'swt'.
assert_checkerror('ecglab.detect(rec, ''Method'', ''swt'')', ...
'Unknown detection method: swt.');
consensusDefault = ecglab.detect(rec, 'Method', 'consensus');
assert_isequal(consensusDefault.kind, 'ecglab.beats');
assert_istrue(iscell(consensusDefault.settings.Methods));
assert_isfalse(any(strcmp('swt', consensusDefault.settings.Methods)));
%=============================================================================
% With ectopic beats and 0.05 mV noise, both sensitivity and positive
% predictivity must stay above 0.98.
recN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Noise', 0.05, 'Seed', 11);
truthN = recN.truth.beats;
beatsN = ecglab.detect(recN, 'Method', method);
[tpN, fpN, fnN] = ecglabWaveletMatch(beatsN.sample, truthN, window20);
sensitivity = tpN / (tpN + fnN);
predictivity = tpN / (tpN + fpN);
assert_istrue(sensitivity > 0.98);
assert_istrue(predictivity > 0.98);
%=============================================================================
% An inverted recording (a reversed electrode pair): with polarity found
% automatically or told negative, every planted beat is still recovered.
recInv = rec;
recInv.samples = -rec.samples;
beatsAuto = ecglab.detect(recInv, 'Method', method, 'Polarity', 'auto');
[~, ~, fnAuto] = ecglabWaveletMatch(beatsAuto.sample, truth, window20);
assert_isequal(fnAuto, 0);
beatsNeg = ecglab.detect(recInv, 'Method', method, 'Polarity', 'negative');
[~, ~, fnNeg] = ecglabWaveletMatch(beatsNeg.sample, truth, window20);
assert_isequal(fnNeg, 0);
%=============================================================================
% A real record, only if the arrhythmia database is on disk. Record 100, lead
% MLII, scored against its reference beats with a 150 ms window. Both
% sensitivity and positive predictivity must clear 0.99, and the 30 minute
% record must run in under two seconds.
recordPath = [prefdir(), '/ecglab_reference/mitdb/100.hea'];
if isfile(recordPath)
  mit = ecglab.reference('mitdb/100');
  ann = mit.annotations;
  isBeat = ismember(ann.symbol, 'NLRBAaJSVrFejnE/fQ?'.');
  refBeats = ann.sample(isBeat);
  window150 = round(0.150 * mit.rate);
  t0 = tic();
  beatsMit = ecglab.detect(mit, 'Method', method, 'Lead', 'MLII');
  elapsed = toc(t0);
  fprintf('detect %s on mitdb/100 (30 min): %.3f s\n', method, elapsed);
  assert_istrue(elapsed < 2);
  [tpM, fpM, fnM] = ecglabWaveletMatch(beatsMit.sample, refBeats, window150);
  seMit = tpM / (tpM + fnM);
  ppvMit = tpM / (tpM + fpM);
  fprintf('detect %s on mitdb/100: Se=%.4f P+=%.4f\n', method, seMit, ppvMit);
  assert_istrue(seMit > 0.99);
  assert_istrue(ppvMit > 0.99);
else
  warning('The MIT-BIH record mitdb/100 is not on disk; its checks are skipped.');
end
%=============================================================================
function e = ecglabWaveletEnergy(signal, rate, method)
  % The total squared-detail energy on a signal, read from the evidence.
  b = ecglab.detect(signal, 'Rate', rate, 'Method', method);
  e = sum(b.evidence.feature);
end
%=============================================================================
function [tp, fp, fn] = ecglabWaveletMatch(detected, reference, window)
  % Match detected to reference beats by a two-pointer walk over the sorted
  % series, each mark used once, the standard comparator rule.
  detected = sort(detected(:));
  reference = sort(reference(:));
  nd = numel(detected);
  nr = numel(reference);
  i = 1;
  j = 1;
  tp = 0;
  while i <= nd && j <= nr
    if abs(detected(i) - reference(j)) <= window
      tp = tp + 1;
      i = i + 1;
      j = j + 1;
    elseif detected(i) < reference(j)
      i = i + 1;
    else
      j = j + 1;
    end
  end
  fp = nd - tp;
  fn = nr - tp;
end
%=============================================================================
