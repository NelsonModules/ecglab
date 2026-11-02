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
% A detector is scored against the planted R peaks of a simulated record, the
% only exactly known truth. The one real record is read only if on disk.
methods = {'pantompkins', 'hamilton'};
%=============================================================================
% A clean one-minute record at 360 Hz. On a noiseless trace every method must
% find every planted beat within 20 ms and invent none.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
truth = rec.truth.beats;
window20 = round(0.020 * 360);
for m = 1:numel(methods)
  beats = ecglab.detect(rec, 'Method', methods{m});
  assert_isequal(beats.kind, 'ecglab.beats');
  [tp, fp, fn] = ecglabDetectMatch(beats.sample, truth, window20);
  assert_isequal(fn, 0);
  assert_isequal(fp, 0);
  assert_isequal(tp, numel(truth));
end
%=============================================================================
% The beats struct carries the whole data model: samples, time, RR (NaN on the
% first beat), method, lead, settings, and three evidence series the length of
% the signal.
beats = ecglab.detect(rec, 'Method', 'pantompkins');
N = size(rec.samples, 1);
K = numel(beats.sample);
assert_isequal(size(beats.sample), [K, 1]);
assert_isequal(beats.time, (beats.sample - 1) / 360);
assert_istrue(isnan(beats.rr(1)));
assert_isapprox(beats.rr(2:end), diff(beats.time), 1e-9);
assert_isequal(beats.method, 'pantompkins');
assert_isequal(beats.lead, 'II');
assert_istrue(isstruct(beats.settings));
assert_isequal(beats.settings.Refractory, 0.2);
assert_isequal(size(beats.evidence.feature), [N, 1]);
assert_isequal(size(beats.evidence.threshold), [N, 1]);
assert_isequal(size(beats.evidence.filtered), [N, 1]);
%=============================================================================
% With ectopic beats and 0.05 mV noise the detection is not perfect, but both
% sensitivity and positive predictivity must stay above 0.98.
recN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Noise', 0.05, 'Seed', 11);
truthN = recN.truth.beats;
window20 = round(0.020 * 360);
for m = 1:numel(methods)
  beats = ecglab.detect(recN, 'Method', methods{m});
  [tp, fp, fn] = ecglabDetectMatch(beats.sample, truthN, window20);
  sensitivity = tp / (tp + fn);
  predictivity = tp / (tp + fp);
  assert_istrue(sensitivity > 0.98);
  assert_istrue(predictivity > 0.98);
end
%=============================================================================
% An inverted recording (a reversed electrode pair): the R peak is the deepest
% trough, and with polarity told or found automatically the beat snaps to it.
recInv = rec;
recInv.samples = -rec.samples;
for m = 1:numel(methods)
  beatsAuto = ecglab.detect(recInv, 'Method', methods{m}, 'Polarity', 'auto');
  [~, ~, fnAuto] = ecglabDetectMatch(beatsAuto.sample, truth, window20);
  assert_isequal(fnAuto, 0);
  beatsNeg = ecglab.detect(recInv, 'Method', methods{m}, 'Polarity', 'negative');
  [~, ~, fnNeg] = ecglabDetectMatch(beatsNeg.sample, truth, window20);
  assert_isequal(fnNeg, 0);
end
%=============================================================================
% Snapping moves every beat to the R peak of the band-passed signal. The truth
% R is in its sixth wave column; with snapping on, every beat lands within
% 20 ms of it.
Rcol = 6;
Rsample = rec.truth.waves(:, Rcol);
for m = 1:numel(methods)
  beats = ecglab.detect(rec, 'Method', methods{m}, 'Snap', true);
  [tp, ~, fn] = ecglabDetectMatch(beats.sample, Rsample, window20);
  assert_isequal(fn, 0);
  assert_isequal(tp, numel(Rsample));
end
%=============================================================================
% Consensus pools the fiducials of several methods and keeps a beat only where
% enough agree. With two methods and two votes, every planted beat survives
% and nothing is added.
con = ecglab.detect(rec, 'Method', 'consensus', 'Methods', methods, 'Votes', 2);
assert_isequal(con.method, 'consensus');
[tp, fp, fn] = ecglabDetectMatch(con.sample, truth, window20);
assert_isequal(fn, 0);
assert_isequal(fp, 0);
% A consensus evidence carries one vote count per beat and the samples each
% method contributed.
assert_isequal(size(con.evidence.votes), [numel(con.sample), 1]);
assert_istrue(all(con.evidence.votes >= 2));
assert_istrue(isfield(con.evidence, 'pantompkins'));
assert_istrue(isfield(con.evidence, 'hamilton'));
%=============================================================================
% Requiring two votes drops a beat only one method invents. On a noisy trace
% the consensus holds no single-method sample, is at least as precise as
% either method alone, and still finds the beats.
recNoisy = ecglab.simulate('Seconds', 120, 'Rate', 360, 'HeartRate', 72, ...
'Noise', 0.15, 'Seed', 21);
truthNoisy = recNoisy.truth.beats;
pt = ecglab.detect(recNoisy, 'Method', 'pantompkins');
ha = ecglab.detect(recNoisy, 'Method', 'hamilton');
con2 = ecglab.detect(recNoisy, 'Method', 'consensus', 'Methods', methods, ...
'Votes', 2);
win6 = round(0.060 * 360);
% Every consensus beat is backed by both methods.
for index = 1:numel(con2.sample)
  nearPt = any(abs(pt.sample - con2.sample(index)) <= win6);
  nearHa = any(abs(ha.sample - con2.sample(index)) <= win6);
  assert_istrue(nearPt && nearHa);
end
[tpC, fpC, fnC] = ecglabDetectMatch(con2.sample, truthNoisy, window20);
[tpP, fpP, ~] = ecglabDetectMatch(pt.sample, truthNoisy, window20);
[tpH, fpH, ~] = ecglabDetectMatch(ha.sample, truthNoisy, window20);
precC = tpC / max(1, tpC + fpC);
precP = tpP / max(1, tpP + fpP);
precH = tpH / max(1, tpH + fpH);
assert_istrue(precC >= precP);
assert_istrue(precC >= precH);
assert_istrue(tpC / (tpC + fnC) > 0.95);
%=============================================================================
% A plain signal vector is detected when its rate is given, and a lead is
% chosen by name or by index.
vec = rec.samples(:, 1);
beatsVec = ecglab.detect(vec, 'Rate', 360);
[~, ~, fnVec] = ecglabDetectMatch(beatsVec.sample, truth, window20);
assert_isequal(fnVec, 0);
rec2 = ecglab.simulate('Seconds', 20, 'Rate', 360, 'Seed', 5, ...
'Leads', {'V2', 'II'});
byName = ecglab.detect(rec2, 'Lead', 'II');
assert_isequal(byName.lead, 'II');
byIndex = ecglab.detect(rec2, 'Lead', 1);
assert_isequal(byIndex.lead, 'V2');
%=============================================================================
% Errors: an unknown method, an unknown lead, a signal shorter than three
% seconds, and the two standard option errors.
assert_checkerror('ecglab.detect(rec, ''Method'', ''nope'')', ...
'Unknown detection method: nope.');
assert_checkerror('ecglab.detect(rec, ''Lead'', ''V9'')', ...
'The recording has no lead named V9.');
shortSignal = rec.samples(1:round(2.5 * 360), 1);
assert_checkerror('ecglab.detect(shortSignal, ''Rate'', 360)', ...
'The signal is shorter than three seconds.');
assert_checkerror('ecglab.detect(vec)', ...
'A signal vector needs its sampling rate, given as Rate.');
assert_checkerror('ecglab.detect(rec, ''Polarity'', ''up'')', ...
'The polarity must be auto, positive or negative.');
assert_checkerror('ecglab.detect(rec, ''Nope'', 1)', 'Unknown option: Nope.');
%=============================================================================
% A real record, only if the arrhythmia database is on disk. Record 100, lead
% MLII, scored against its reference beats with a 150 ms window. Both
% sensitivity and positive predictivity must clear 0.99, and each method must
% run the 30 minute record in under two seconds.
recordPath = [prefdir(), '/ecglab_reference/mitdb/100.hea'];
if isfile(recordPath)
  mit = ecglab.reference('mitdb/100');
  ann = mit.annotations;
  isBeat = ismember(ann.symbol, 'NLRBAaJSVrFejnE/fQ?'.');
  refBeats = ann.sample(isBeat);
  window150 = round(0.150 * mit.rate);
  for m = 1:numel(methods)
    t0 = tic();
    beats = ecglab.detect(mit, 'Method', methods{m}, 'Lead', 'MLII');
    elapsed = toc(t0);
    fprintf('detect %s on mitdb/100 (30 min): %.3f s\n', methods{m}, elapsed);
    assert_istrue(elapsed < 2);
    [tp, fp, fn] = ecglabDetectMatch(beats.sample, refBeats, window150);
    sensitivity = tp / (tp + fn);
    predictivity = tp / (tp + fp);
    fprintf('detect %s on mitdb/100: Se=%.4f P+=%.4f\n', methods{m}, ...
    sensitivity, predictivity);
    assert_istrue(sensitivity > 0.99);
    assert_istrue(predictivity > 0.99);
    % The 'auto' polarity must place the snapped beat on the QRS peak where the
    % reference marks sit. The 150 ms score window hides a placement shift, so
    % this asserts the placement directly, within the 30 ms a snapped beat may
    % carry on a real record.
    offsets = ecglabDetectOffsets(beats.sample, refBeats, window150, mit.rate);
    fprintf('detect %s on mitdb/100: median placement %.2f ms\n', ...
    methods{m}, median(offsets));
    assert_istrue(abs(median(offsets)) <= 30);
  end
else
  warning('The MIT-BIH record mitdb/100 is not on disk; its checks are skipped.');
end
%=============================================================================
function [tp, fp, fn] = ecglabDetectMatch(detected, reference, window)
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
function offsets = ecglabDetectOffsets(detected, reference, window, rate)
  % The signed offset in milliseconds of each detected beat from its nearest
  % reference beat within the window; positive means after the reference.
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
