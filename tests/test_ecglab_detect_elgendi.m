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
method = 'elgendi';
%=============================================================================
% A clean one-minute record at 360 Hz. On a noiseless trace the detector must
% find every planted beat within 20 ms and invent none.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
truth = rec.truth.beats;
window20 = round(0.020 * 360);
beats = ecglab.detect(rec, 'Method', method);
assert_isequal(beats.kind, 'ecglab.beats');
[tp, fp, fn] = ecglabElgendiMatch(beats.sample, truth, window20);
assert_isequal(fn, 0);
assert_isequal(fp, 0);
assert_isequal(tp, numel(truth));
%=============================================================================
% The evidence carries MA_peak as feature, THR1 as threshold, and the
% band-passed trace, each the length of the signal. Both the feature and the
% threshold are non-negative.
Nrec = size(rec.samples, 1);
assert_isequal(size(beats.evidence.feature), [Nrec, 1]);
assert_isequal(size(beats.evidence.threshold), [Nrec, 1]);
assert_isequal(size(beats.evidence.filtered), [Nrec, 1]);
assert_istrue(all(beats.evidence.feature >= 0));
assert_istrue(all(beats.evidence.threshold >= 0));
%=============================================================================
% With ectopic beats and 0.05 mV noise, both sensitivity and positive
% predictivity must stay above 0.98.
recN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Noise', 0.05, 'Seed', 11);
truthN = recN.truth.beats;
beatsN = ecglab.detect(recN, 'Method', method);
[tpN, fpN, fnN] = ecglabElgendiMatch(beatsN.sample, truthN, window20);
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
[~, ~, fnAuto] = ecglabElgendiMatch(beatsAuto.sample, truth, window20);
assert_isequal(fnAuto, 0);
beatsNeg = ecglab.detect(recInv, 'Method', method, 'Polarity', 'negative');
[~, ~, fnNeg] = ecglabElgendiMatch(beatsNeg.sample, truth, window20);
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
  [tpM, fpM, fnM] = ecglabElgendiMatch(beatsMit.sample, refBeats, window150);
  seMit = tpM / (tpM + fnM);
  ppvMit = tpM / (tpM + fpM);
  fprintf('detect %s on mitdb/100: Se=%.4f P+=%.4f\n', method, seMit, ppvMit);
  assert_istrue(seMit > 0.99);
  assert_istrue(ppvMit > 0.99);
else
  warning('The MIT-BIH record mitdb/100 is not on disk; its checks are skipped.');
end
%=============================================================================
function [tp, fp, fn] = ecglabElgendiMatch(detected, reference, window)
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
