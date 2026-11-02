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
% The curve length detector wqrs is scored against the planted truth, then
% against one real record if on disk.
method = 'wqrs';
%=============================================================================
% A clean one-minute record at 360 Hz. On a noiseless trace the detector must
% find every planted beat within 20 ms of the R peak and invent none.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
truth = rec.truth.beats;
window20 = round(0.020 * 360);
beats = ecglab.detect(rec, 'Method', method);
assert_isequal(beats.kind, 'ecglab.beats');
assert_isequal(beats.method, 'wqrs');
[tp, fp, fn] = ecglabWqrsMatch(beats.sample, truth, window20);
assert_isequal(fn, 0);
assert_isequal(fp, 0);
assert_isequal(tp, numel(truth));
%=============================================================================
% The beats struct carries the whole data model. The wqrs evidence is the
% three usual series (length transform, threshold, filtered trace) plus the
% QRS onset and J point per beat, which the delineator can reuse.
N = size(rec.samples, 1);
K = numel(beats.sample);
assert_isequal(size(beats.sample), [K, 1]);
assert_isequal(beats.time, (beats.sample - 1) / 360);
assert_istrue(isnan(beats.rr(1)));
assert_isequal(size(beats.evidence.feature), [N, 1]);
assert_isequal(size(beats.evidence.threshold), [N, 1]);
assert_isequal(size(beats.evidence.filtered), [N, 1]);
assert_istrue(isfield(beats.evidence, 'onset'));
assert_istrue(isfield(beats.evidence, 'jpoint'));
assert_isequal(size(beats.evidence.onset), [K, 1]);
assert_isequal(size(beats.evidence.jpoint), [K, 1]);
% The onset of a beat lies before its R peak and the J point after it.
assert_istrue(all(beats.evidence.onset <= beats.sample));
assert_istrue(all(beats.evidence.jpoint >= beats.sample));
%=============================================================================
% wqrs annotates the QRS onset, and the dispatcher snaps the returned fiducial
% to the R peak. The onset kept in the evidence must sit 20 to 80 ms before the
% true R peak (truth column six).
Rcol = 6;
Rsample = rec.truth.waves(:, Rcol);
onsetMs = zeros(0, 1);
for k = 1:numel(beats.evidence.onset)
  [distance, index] = min(abs(Rsample - beats.sample(k)));
  if distance <= window20
    onsetMs(end + 1, 1) = (Rsample(index) - beats.evidence.onset(k)) / 360 * 1000; %#ok<AGROW>
  end
end
assert_istrue(median(onsetMs) >= 20);
assert_istrue(median(onsetMs) <= 80);
%=============================================================================
% With ectopic beats and 0.05 mV noise the detection is not perfect, but both
% sensitivity and positive predictivity must stay above 0.98.
recN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Noise', 0.05, 'Seed', 11);
truthN = recN.truth.beats;
beatsN = ecglab.detect(recN, 'Method', method);
[tpN, fpN, fnN] = ecglabWqrsMatch(beatsN.sample, truthN, window20);
sensitivity = tpN / (tpN + fnN);
predictivity = tpN / (tpN + fpN);
assert_istrue(sensitivity > 0.98);
assert_istrue(predictivity > 0.98);
%=============================================================================
% An inverted recording (a reversed electrode pair): the length transform is
% blind to polarity (it squares the derivative), and the snap lands the beat on
% the trough with polarity told or found.
recInv = rec;
recInv.samples = -rec.samples;
beatsAuto = ecglab.detect(recInv, 'Method', method, 'Polarity', 'auto');
[~, ~, fnAuto] = ecglabWqrsMatch(beatsAuto.sample, truth, window20);
assert_isequal(fnAuto, 0);
beatsNeg = ecglab.detect(recInv, 'Method', method, 'Polarity', 'negative');
[~, ~, fnNeg] = ecglabWqrsMatch(beatsNeg.sample, truth, window20);
assert_isequal(fnNeg, 0);
%=============================================================================
% A real record, only if the arrhythmia database is on disk. Record 100, lead
% MLII, scored against its reference beats with a 150 ms window. Both
% sensitivity and positive predictivity must clear 0.99, and the detector must
% run the 30 minute record in under two seconds.
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
  [tpM, fpM, fnM] = ecglabWqrsMatch(beatsMit.sample, refBeats, window150);
  seMit = tpM / (tpM + fnM);
  ppvMit = tpM / (tpM + fpM);
  fprintf('detect %s on mitdb/100: Se=%.4f P+=%.4f\n', method, seMit, ppvMit);
  assert_istrue(seMit > 0.99);
  assert_istrue(ppvMit > 0.99);
  % The snapped beat must land on the QRS peak, within the 30 ms a snapped beat
  % may carry on a real record.
  offsets = ecglabWqrsOffsets(beatsMit.sample, refBeats, window150, mit.rate);
  fprintf('detect %s on mitdb/100: median placement %.2f ms\n', ...
  method, median(offsets));
  assert_istrue(abs(median(offsets)) <= 30);
else
  warning('The MIT-BIH record mitdb/100 is not on disk; its checks are skipped.');
end
%=============================================================================
function [tp, fp, fn] = ecglabWqrsMatch(detected, reference, window)
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
function offsets = ecglabWqrsOffsets(detected, reference, window, rate)
  % The signed offset in milliseconds of each detected beat from its nearest
  % reference beat within the window.
  detected = sort(detected(:));
  reference = sort(reference(:));
  offsets = zeros(0, 1);
  for k = 1:numel(detected)
    [distance, index] = min(abs(reference - detected(k)));
    if distance <= window
      offsets(end + 1, 1) = (detected(k) - reference(index)) / rate * 1000; %#ok<AGROW>
    end
  end
end
%=============================================================================
