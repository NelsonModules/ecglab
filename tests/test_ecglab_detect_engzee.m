%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% The Engelse-Zeelenberg detector is scored against the planted R peaks of a
% simulated record, the only exactly known truth. The one real record is read
% only if on disk.
method = 'engzee';
%=============================================================================
% A clean one-minute record at 360 Hz. The single scan finds each complex by
% the swing of the differentiated signal; on a noiseless trace it keeps both
% sensitivity and positive predictivity above 0.99, with 20 ms placement.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
truth = rec.truth.beats;
window20 = round(0.020 * 360);
beats = ecglab.detect(rec, 'Method', method);
assert_isequal(beats.kind, 'ecglab.beats');
assert_isequal(beats.method, method);
[tp, fp, fn] = ecglabEngzeeMatch(beats.sample, truth, window20);
assert_istrue(tp / (tp + fn) > 0.99);
assert_istrue(tp / (tp + fp) > 0.99);
%=============================================================================
% The beats struct carries the whole data model: samples, time, RR (NaN on the
% first beat), lead, settings, and the evidence series. The feature is the
% low-passed derivative y2 and the threshold the adaptive M in force.
N = size(rec.samples, 1);
K = numel(beats.sample);
assert_isequal(size(beats.sample), [K, 1]);
assert_isequal(beats.time, (beats.sample - 1) / 360);
assert_istrue(isnan(beats.rr(1)));
assert_isapprox(beats.rr(2:end), diff(beats.time), 1e-9);
assert_isequal(beats.lead, 'II');
assert_isequal(size(beats.evidence.feature), [N, 1]);
assert_isequal(size(beats.evidence.threshold), [N, 1]);
assert_isequal(size(beats.evidence.filtered), [N, 1]);
% The threshold in force is the positive M, kept above zero once the signal is
% learned.
assert_istrue(all(beats.evidence.threshold >= 0));
%=============================================================================
% With ectopic beats and 0.05 mV noise the detection is not perfect, but both
% sensitivity and positive predictivity must stay above 0.98.
recN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Noise', 0.05, 'Seed', 11);
truthN = recN.truth.beats;
beatsN = ecglab.detect(recN, 'Method', method);
[tpN, fpN, fnN] = ecglabEngzeeMatch(beatsN.sample, truthN, window20);
sensitivity = tpN / (tpN + fnN);
predictivity = tpN / (tpN + fpN);
assert_istrue(sensitivity > 0.98);
assert_istrue(predictivity > 0.98);
%=============================================================================
% An inverted recording (a reversed electrode pair): the single scan confirms
% a complex by swings in each direction, which an inversion only mirrors, and
% the snap lands the beat on the trough. Planted beats are recovered.
recInv = rec;
recInv.samples = -rec.samples;
beatsAuto = ecglab.detect(recInv, 'Method', method, 'Polarity', 'auto');
[tpA, ~, fnA] = ecglabEngzeeMatch(beatsAuto.sample, truth, window20);
assert_istrue(tpA / (tpA + fnA) > 0.99);
beatsNeg = ecglab.detect(recInv, 'Method', method, 'Polarity', 'negative');
[tpG, ~, fnG] = ecglabEngzeeMatch(beatsNeg.sample, truth, window20);
assert_istrue(tpG / (tpG + fnG) > 0.99);
%=============================================================================
% A plain signal vector is detected when its rate is given.
vec = rec.samples(:, 1);
beatsVec = ecglab.detect(vec, 'Rate', 360, 'Method', method);
[tpV, ~, fnV] = ecglabEngzeeMatch(beatsVec.sample, truth, window20);
assert_istrue(tpV / (tpV + fnV) > 0.99);
%=============================================================================
% A real record, only if the arrhythmia database is on disk. Record 100, lead
% MLII, scored against its reference beats with a 150 ms window. Both
% sensitivity and positive predictivity must clear 0.99, and the method must
% run the 30 minute record in under two seconds.
recordPath = [prefdir(), '/ecglab_reference/mitdb/100.hea'];
if isfile(recordPath)
  mit = ecglab.readwfdb([prefdir(), '/ecglab_reference/mitdb/100']);
  ann = mit.annotations;
  isBeat = ismember(ann.symbol, 'NLRBAaJSVrFejnE/fQ?'.');
  refBeats = ann.sample(isBeat);
  window150 = round(0.150 * mit.rate);
  t0 = tic();
  beatsMit = ecglab.detect(mit, 'Method', method, 'Lead', 'MLII');
  elapsed = toc(t0);
  fprintf('detect %s on mitdb/100 (30 min): %.3f s\n', method, elapsed);
  assert_istrue(elapsed < 2);
  [tpM, fpM, fnM] = ecglabEngzeeMatch(beatsMit.sample, refBeats, window150);
  se = tpM / (tpM + fnM);
  ppv = tpM / (tpM + fpM);
  fprintf('detect %s on mitdb/100: Se=%.4f P+=%.4f\n', method, se, ppv);
  assert_istrue(se > 0.99);
  assert_istrue(ppv > 0.99);
else
  warning('The MIT-BIH record mitdb/100 is not on disk; its checks are skipped.');
end
%=============================================================================
function [tp, fp, fn] = ecglabEngzeeMatch(detected, reference, window)
  % Match detected to reference beats by a two-pointer walk over the sorted
  % series: a detection within the window is a true positive; otherwise the
  % earlier mark advances. Each mark is used once, the standard comparator rule.
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
