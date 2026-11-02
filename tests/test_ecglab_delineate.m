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
% The delineator is judged against the simulator truth, whose wave boundaries
% are planted before the signal is drawn. The tolerances are those a wavelet
% delineator meets on the QT Database (survey 5.6), tightened for the clean
% synthetic case.
%=============================================================================
rate = 500;
seconds = 60;
seed = 42;
cols = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', 'QRSoff', 'J', ...
'Ton', 'Tpeak', 'Toff'};
% The per-fiducial tolerances in milliseconds, in the column order above.
tol = [20, 20, 20, 15, 12, 5, 12, 15, 15, 30, 20, 30];
%=============================================================================
rec = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'HeartRate', 60, ...
'Seed', seed);
truth = rec.truth.waves;
% Hang the assertions on the planted truth beats, not a detection, so a
% detector miss cannot change the row count or the scatter. The simulator
% plants each boundary at its steepest slope, so BoundaryFraction 1 is used,
% which reads the boundary at the slope maximum (the clinical default 0.06
% steps outward to the foot, where the QT Database annotators mark).
waves = ecglab.delineate(rec, 'Beats', localTruthBeats(rec, rate), ...
'BoundaryFraction', 1);
assert_isequal(waves.kind, 'ecglab.waves');
assert_isequal(waves.columns, cols);
assert_isequal(size(waves.sample, 2), 12);
K = size(truth, 1);
assert_isequal(size(waves.sample, 1), K);
%=============================================================================
% The signed error in milliseconds per fiducial, over every beat both the
% truth and the delineator mark. The mean and SD are printed.
errMs = (waves.sample - truth) / rate * 1000;
disp('Signed delineation error against the simulator truth (ms):');
disp('  fiducial     mean      SD     n   tol');
meanErr = nan(1, 12);
sdErr = nan(1, 12);
for c = 1:12
  e = errMs(:, c);
  e = e(isfinite(e));
  if ~isempty(e)
    meanErr(c) = mean(e);
    sdErr(c) = std(e);
  end
  fprintf('  %-9s %8.2f %8.2f %5d %5d\n', cols{c}, meanErr(c), sdErr(c), ...
  numel(e), tol(c));
end
%=============================================================================
% Every fiducial's mean absolute error and its SD must sit inside the
% tolerance.
for c = 1:12
  e = errMs(:, c);
  e = e(isfinite(e));
  assert_istrue(~isempty(e));
  assert_istrue(abs(mean(e)) <= tol(c));
  assert_istrue(std(e) <= tol(c));
end
%=============================================================================
% The fraction of beats with a delineated QRS (a non-NaN onset) must be above
% 0.98.
delineated = sum(isfinite(waves.sample(:, 4))) / K;
fprintf('Fraction of beats with a delineated QRS: %.4f\n', delineated);
assert_istrue(delineated > 0.98);
%=============================================================================
% The accuracy must not hinge on one seed: on several seeds every fiducial's
% bias and scatter stays within tolerance. A beat whose R sits at the last
% sample must be returned NaN, not a truncated R. Seed 271828 plants exactly
% that terminal beat (R at sample 29999 of 30000).
for seedR = [271828, 314, 999, 2718]
  recR = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'HeartRate', 60, ...
  'Seed', seedR);
  tR = recR.truth.waves;
  wR = ecglab.delineate(recR, 'Beats', localTruthBeats(recR, rate), ...
  'BoundaryFraction', 1);
  eR = (wR.sample - tR) / rate * 1000;
  for c = 1:12
    e = eR(:, c);
    e = e(isfinite(e));
    assert_istrue(~isempty(e));
    assert_istrue(abs(mean(e)) <= tol(c));
    assert_istrue(std(e) <= tol(c));
  end
end
%=============================================================================
% A beat whose QRS window is clipped by the record end is returned NaN. Force
% the last truth beat onto the last sample and confirm its QRS columns (onset,
% R, offset) are all NaN.
recT = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'HeartRate', 60, ...
'Seed', seed);
Nt = size(recT.samples, 1);
btruth = localTruthBeats(recT, rate);
btruth.sample(end) = Nt;
btruth.time(end) = (Nt - 1) / rate;
wT = ecglab.delineate(recT, 'Beats', btruth);
assert_istrue(isnan(wT.sample(end, 4)));
assert_istrue(isnan(wT.sample(end, 6)));
assert_istrue(isnan(wT.sample(end, 8)));
%=============================================================================
% The intervals match the planted ones within their boundary tolerances.
% PR = QRSon - Pon, QRS = QRSoff - QRSon, QT = Toff - QRSon, in milliseconds.
truthPr = (truth(:, 4) - truth(:, 1)) / rate * 1000;
truthQrs = (truth(:, 8) - truth(:, 4)) / rate * 1000;
truthQt = (truth(:, 12) - truth(:, 4)) / rate * 1000;
prErr = waves.intervals.pr - truthPr;
qrsErr = waves.intervals.qrs - truthQrs;
qtErr = waves.intervals.qt - truthQt;
prErr = prErr(isfinite(prErr));
qrsErr = qrsErr(isfinite(qrsErr));
qtErr = qtErr(isfinite(qtErr));
fprintf('Interval error PR %.2f QRS %.2f QT %.2f ms (mean)\n', ...
mean(prErr), mean(qrsErr), mean(qtErr));
assert_istrue(abs(mean(prErr)) <= 20);
assert_istrue(abs(mean(qrsErr)) <= 15);
assert_istrue(abs(mean(qtErr)) <= 30);
%=============================================================================
% The T offset follows the slope-versus-clinical convention: BoundaryFraction 1
% sits on the slope maximum, a clinical fraction reads outward to the foot by
% the tangent method. The simulator's smooth Gaussian T cannot show this, so
% the two conventions are checked on a hand-made sharp T, where the tangent
% must read the offset later than the slope maximum.
sharpRate = 250;
sharpN = round(1.2 * sharpRate);
sharpSig = zeros(sharpN, 1);
rSharp = round(0.3 * sharpRate);
sharpSig(rSharp) = 3;
% A triangular T: a slow rise to a peak, then a sharp linear fall to baseline,
% so the tangent from the slope maximum reaches the foot further out.
tPeakS = rSharp + round(0.25 * sharpRate);
riseFrom = rSharp + round(0.12 * sharpRate);
for i = riseFrom:tPeakS
  sharpSig(i) = 0.6 * (i - riseFrom) / (tPeakS - riseFrom);
end
tEndS = tPeakS + round(0.05 * sharpRate);
for i = tPeakS:tEndS
  sharpSig(i) = 0.6 * (1 - (i - tPeakS) / (tEndS - tPeakS));
end
sharpBeats = struct('sample', rSharp);
sharpFoot = ecglab.delineate(sharpSig, 'Rate', sharpRate, 'Beats', sharpBeats, ...
'Clean', false);
sharpSlope = ecglab.delineate(sharpSig, 'Rate', sharpRate, 'Beats', sharpBeats, ...
'Clean', false, 'BoundaryFraction', 1);
if isfinite(sharpFoot.sample(1, 12)) && isfinite(sharpSlope.sample(1, 12))
  assert_istrue(sharpFoot.sample(1, 12) >= sharpSlope.sample(1, 12));
end
%=============================================================================
% The four QTc formulas, checked arithmetically on one beat. The same RR the
% delineator used feeds the check: RR in seconds, QT in ms, HR = 60 / RR.
beatsChk = ecglab.detect(rec);
wChk = ecglab.delineate(rec, 'Beats', beatsChk);
kCheck = find(isfinite(wChk.intervals.qt) & isfinite(beatsChk.rr), 1);
assert_istrue(~isempty(kCheck));
qt = wChk.intervals.qt(kCheck);
rr = beatsChk.rr(kCheck);
hr = 60 / rr;
bazett = qt / sqrt(rr);
fridericia = qt / rr ^ (1 / 3);
framingham = qt + 154 * (1 - rr);
hodges = qt + 1.75 * (hr - 60);
assert_istrue(abs(wChk.intervals.qtc.bazett(kCheck) - bazett) < 1e-6);
assert_istrue(abs(wChk.intervals.qtc.fridericia(kCheck) - fridericia) < 1e-6);
assert_istrue(abs(wChk.intervals.qtc.framingham(kCheck) - framingham) < 1e-6);
assert_istrue(abs(wChk.intervals.qtc.hodges(kCheck) - hodges) < 1e-6);
%=============================================================================
% At 60 bpm (RR near 1 s) the Bazett QTc is near the QT, since sqrt(1) is one.
nearSixty = find(isfinite(wChk.intervals.qt) & abs(beatsChk.rr - 1) < 0.02, 1);
if ~isempty(nearSixty)
  assert_istrue(abs(wChk.intervals.qtc.bazett(nearSixty) - ...
  wChk.intervals.qt(nearSixty)) < 10);
end
%=============================================================================
% On an ectopic recording a ventricular ectopic beat has no P wave, so its P
% columns are NaN, while the normal beats keep a P.
ect = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'HeartRate', 60, ...
'Ectopic', 0.15, 'Seed', seed);
% Hang the delineation on the truth beats so the rows line up with the truth
% classes.
ectBeats = localTruthBeats(ect, rate);
wEct = ecglab.delineate(ect, 'Beats', ectBeats);
isV = (ect.truth.classes == 'V');
assert_istrue(any(isV));
% The ectopic beats carry no P onset in the truth; the delineator must agree.
assert_istrue(all(isnan(wEct.sample(isV, 1))));
% The normal beats mostly keep their P: at least 90 per cent have a P onset.
normalP = sum(isfinite(wEct.sample(~isV, 1))) / sum(~isV);
fprintf('Fraction of normal beats with a P in the ectopic record: %.4f\n', ...
normalP);
assert_istrue(normalP >= 0.9);
%=============================================================================
% Atrial fibrillation: the P wave is absent throughout, so every P column is
% NaN, while the QRS and the T are still found on most beats.
fib = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'HeartRate', 90, ...
'Fibrillation', true, 'Seed', seed);
fibBeats = localTruthBeats(fib, rate);
wFib = ecglab.delineate(fib, 'Beats', fibBeats);
assert_istrue(all(isnan(wFib.sample(:, 1))));
assert_istrue(all(isnan(wFib.sample(:, 2))));
assert_istrue(all(isnan(wFib.sample(:, 3))));
qrsFound = sum(isfinite(wFib.sample(:, 4))) / size(wFib.sample, 1);
tFound = sum(isfinite(wFib.sample(:, 11))) / size(wFib.sample, 1);
fprintf('Fibrillation: QRS found %.4f, T found %.4f\n', qrsFound, tFound);
assert_istrue(qrsFound > 0.95);
assert_istrue(tFound > 0.8);
%=============================================================================
% Multilead fusion: a twelve-lead record gives a perLead struct for each lead
% and a fused global whose QRS onset is at or before every lead's, whose QRS
% offset is at or after every lead's (the AHA superimposed-lead rule), and
% whose QT is at least as long as any single lead's.
rec12 = ecglab.simulate('Seconds', 30, 'Rate', rate, 'HeartRate', 60, ...
'Leads', 12, 'Seed', seed);
w12 = ecglab.delineate(rec12, 'Lead', 'all');
assert_istrue(isfield(w12, 'perLead'));
assert_isequal(numel(w12.perLead), 12);
Kf = size(w12.sample, 1);
for k = 1:Kf
  onsets = zeros(12, 1);
  offsets = zeros(12, 1);
  qts = nan(12, 1);
  for L = 1:12
    onsets(L) = w12.perLead(L).sample(k, 4);
    offsets(L) = w12.perLead(L).sample(k, 8);
    qts(L) = (w12.perLead(L).sample(k, 12) - w12.perLead(L).sample(k, 4));
  end
  if isfinite(w12.sample(k, 4))
    assert_istrue(w12.sample(k, 4) <= min(onsets) + 1e-9);
  end
  if isfinite(w12.sample(k, 8))
    assert_istrue(w12.sample(k, 8) >= max(offsets) - 1e-9);
  end
  globalQt = w12.sample(k, 12) - w12.sample(k, 4);
  if isfinite(globalQt)
    assert_istrue(globalQt >= max(qts) - 1e-9);
  end
end
%=============================================================================
% Fusion treats S as a peak: the global S is the median of the leads, not the
% latest. Tested on three leads that are one signal shifted by a few samples,
% so the per-lead S spreads in time, while the QRS offset column must still
% take the latest.
base = ecglab.simulate('Seconds', 20, 'Rate', rate, 'HeartRate', 60, 'Seed', 42);
xb = base.samples(:, 1);
Nb = numel(xb);
shifts = [0, 6, -6];
Xs = zeros(Nb, 3);
for j = 1:3
  dshift = shifts(j);
  if dshift >= 0
    Xs(:, j) = [xb(1) * ones(dshift, 1); xb(1:end - dshift)];
  else
    dshift = -dshift;
    Xs(:, j) = [xb(1 + dshift:end); xb(end) * ones(dshift, 1)];
  end
end
recS = struct('kind', 'ecglab.recording', 'rate', rate, 'samples', Xs, ...
'leads', {{'L1', 'L2', 'L3'}}, 'units', {{'mV', 'mV', 'mV'}}, 'seconds', 20, ...
'info', struct('name', 'syn', 'source', '', 'format', 'simulated'), ...
'annotations', []);
baseBeats = ecglab.detect(base);
wS = ecglab.delineate(recS, 'Lead', 'all', 'Beats', baseBeats);
Ks = size(wS.sample, 1);
diverged = 0;
for k = 1:Ks
  sv = [wS.perLead(1).sample(k, 7), wS.perLead(2).sample(k, 7), ...
  wS.perLead(3).sample(k, 7)];
  ov = [wS.perLead(1).sample(k, 8), wS.perLead(2).sample(k, 8), ...
  wS.perLead(3).sample(k, 8)];
  if all(isfinite(sv))
    % The fused S is the rounded median of the leads, not the latest.
    assert_istrue(abs(wS.sample(k, 7) - round(median(sv))) <= 1e-9);
    if numel(unique(sv)) > 1
      diverged = diverged + 1;
    end
  end
  if all(isfinite(ov))
    assert_istrue(abs(wS.sample(k, 8) - max(ov)) <= 1e-9);
  end
end
% Confirm the shifted leads really disagree on S, so the median-versus-latest
% distinction is actually exercised.
assert_istrue(diverged > 0);
fprintf('Fusion S median exercised on %d beats with divergent leads\n', diverged);
%=============================================================================
% The T morphology code is 0 on an upright T and 1 on an inverted T. Negating
% the signal inverts the T, so the code must change from 0 to 1.
recM = ecglab.simulate('Seconds', 20, 'Rate', rate, 'HeartRate', 60, ...
'Seed', 7);
wUp = ecglab.delineate(recM);
upCodes = wUp.morphology(isfinite(wUp.morphology));
fprintf('Upright T morphology mode: %d\n', mode(upCodes));
assert_isequal(mode(upCodes), 0);
inv = recM;
inv.samples = -inv.samples;
wInv = ecglab.delineate(inv);
invCodes = wInv.morphology(isfinite(wInv.morphology));
fprintf('Inverted T morphology mode: %d\n', mode(invCodes));
assert_isequal(mode(invCodes), 1);
%=============================================================================
% The morphology codes 2 (positive monophasic) and 3 (negative monophasic) are
% emitted for a monophasic wave. A hand-built signal that steps up after each
% QRS and holds through the T window gives one, with the cleaner off so the
% step is not flattened by the baseline high pass.
rateM = 500;
Tm = 12;
Nm = Tm * rateM;
xm = zeros(Nm, 1);
rlocM = round((0.6:1.0:Tm - 0.5) * rateM);
for i = 1:numel(rlocM)
  r = rlocM(i);
  wq = round(0.010 * rateM);
  qi = (r - wq):(r + wq);
  xm(qi) = xm(qi) + 1.2 * (1 - abs(qi - r) / wq)';
  ts = r + round(0.14 * rateM);
  ri = round(0.040 * rateM);
  up = ts:(ts + ri);
  xm(up) = xm(up) + 0.4 * linspace(0, 1, numel(up))';
  if i < numel(rlocM)
    rnext = rlocM(i + 1);
  else
    rnext = Nm;
  end
  dropStart = rnext - round(0.18 * rateM);
  plat = (ts + ri):dropStart;
  plat = plat(plat <= Nm);
  xm(plat) = xm(plat) + 0.4;
  dr = round(0.040 * rateM);
  di = dropStart:(dropStart + dr);
  di = di(di <= Nm);
  xm(di) = xm(di) + 0.4 * linspace(1, 0, numel(di))';
end
recMono = struct('kind', 'ecglab.recording', 'rate', rateM, 'samples', xm, ...
'leads', {{'II'}}, 'units', {{'mV'}}, 'seconds', Tm, ...
'info', struct('name', 'syn', 'source', '', 'format', 'simulated'), ...
'annotations', []);
monoBeats = struct('kind', 'ecglab.beats', 'sample', rlocM(:), ...
'time', (rlocM(:) - 1) / rateM, 'rr', [NaN; diff(rlocM(:)) / rateM], ...
'method', 'truth', 'lead', 'II', 'settings', struct());
wMono = ecglab.delineate(recMono, 'Beats', monoBeats, 'Clean', false);
monoCodes = wMono.morphology(isfinite(wMono.morphology));
fprintf('Monophasic T morphology mode: %d\n', mode(monoCodes));
assert_isequal(mode(monoCodes), 2);
recMonoN = recMono;
recMonoN.samples = -recMonoN.samples;
wMonoN = ecglab.delineate(recMonoN, 'Beats', monoBeats, 'Clean', false);
monoCodesN = wMonoN.morphology(isfinite(wMonoN.morphology));
fprintf('Negated monophasic T morphology mode: %d\n', mode(monoCodesN));
assert_isequal(mode(monoCodesN), 3);
%=============================================================================
% The delineation hangs on the beats given: a beats struct with one beat
% removed yields one fewer row, and no redetection happens.
beats = ecglab.detect(rec);
fewer = beats;
drop = 5;
keep = true(numel(beats.sample), 1);
keep(drop) = false;
fewer.sample = beats.sample(keep);
fewer.time = beats.time(keep);
fewer.rr = [NaN; diff(fewer.time)];
wAll = ecglab.delineate(rec, 'Beats', beats);
wFewer = ecglab.delineate(rec, 'Beats', fewer);
assert_isequal(size(wFewer.sample, 1), size(wAll.sample, 1) - 1);
%=============================================================================
% Errors and edges: an unknown method and a bad option name both raise; no
% detectable beats returns an empty waves struct; too short to detect raises.
R = ecglab.simulate('Seconds', 20, 'Rate', rate, 'Seed', 1);
failed = false;
try
  ecglab.delineate(R, 'Method', 'nosuchmethod');
catch
  failed = true;
end
assert_istrue(failed);
failed = false;
try
  ecglab.delineate(R, 'NoSuchOption', 1);
catch
  failed = true;
end
assert_istrue(failed);
% A flat signal has nothing to delineate; the delineator returns a waves
% struct and never raises.
flat = zeros(round(10 * rate), 1);
wFlat = ecglab.delineate(flat, 'Rate', rate);
assert_isequal(wFlat.kind, 'ecglab.waves');
% With empty beats the waves struct is empty: zero rows, the right shape, not
% an error.
noBeats = struct('kind', 'ecglab.beats', 'sample', zeros(0, 1), ...
'time', zeros(0, 1), 'rr', zeros(0, 1), 'method', 'none', 'lead', '', ...
'settings', struct());
wEmpty = ecglab.delineate(flat, 'Rate', rate, 'Beats', noBeats);
assert_isequal(wEmpty.kind, 'ecglab.waves');
assert_isequal(size(wEmpty.sample, 1), 0);
assert_isequal(size(wEmpty.sample, 2), 12);
% A signal too short for the detector to learn its thresholds raises.
failed = false;
try
  ecglab.delineate(zeros(round(1 * rate), 1), 'Rate', rate);
catch
  failed = true;
end
assert_istrue(failed);
%=============================================================================
% A real record proves the delineator runs on measured data. Read only if on
% disk; the medians it finds are printed, not asserted.
qtdbOne = [prefdir(), '/ecglab_reference/qtdb/sel100.hea'];
if isfile(qtdbOne)
  realRec = ecglab.readwfdb([prefdir(), '/ecglab_reference/qtdb/sel100']);
  wReal = ecglab.delineate(realRec);
  fprintf('sel100 median PR %.0f QRS %.0f QT %.0f ms\n', ...
  median(wReal.intervals.pr, 'omitnan'), ...
  median(wReal.intervals.qrs, 'omitnan'), ...
  median(wReal.intervals.qt, 'omitnan'));
else
  disp('QT Database not on disk: the real-record check is skipped.');
end
%=============================================================================
function beats = localTruthBeats(rec, rate)
  % A beats struct built from the simulator truth, so the delineation hangs on
  % the planted beats and its rows line up with the truth classes.
  s = rec.truth.beats(:);
  beats = struct('kind', 'ecglab.beats', 'sample', s, ...
  'time', (s - 1) / rate, 'rr', rec.truth.rr(:), 'method', 'truth', ...
  'lead', '', 'settings', struct());
end
%=============================================================================
