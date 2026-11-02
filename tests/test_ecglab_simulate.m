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
% A simulated recording has an exactly known truth, so the module's detectors,
% delineator and classifier are all checked against it.
%=============================================================================
% The column order of the truth waves, restated from the data model.
Pon = 1; Ppeak = 2; Poff = 3; QRSon = 4; Q = 5; R = 6; S = 7; QRSoff = 8;
J = 9; Ton = 10; Tpeak = 11; Toff = 12;
%=============================================================================
% A plain one minute recording at 360 Hz, 60 bpm, with a fixed seed.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, 'Seed', 1);
assert_isequal(rec.kind, 'ecglab.recording');
assert_isequal(rec.rate, 360);
assert_isequal(rec.info.format, 'simulated');
% 60 s at 360 Hz is that many rows, and the default is the single lead II.
assert_isequal(size(rec.samples, 1), 60 * 360);
assert_isequal(size(rec.samples, 2), 1);
assert_isequal(rec.leads, {'II'});
assert_isequal(rec.units, {'mV'});
%=============================================================================
% The truth is attached, and the beat count follows the length: about 60 beats
% for 60 s at 60 bpm.
assert_istrue(isfield(rec, 'truth'));
K = numel(rec.truth.beats);
expected = 60 * 60 / 60;
assert_istrue(abs(K - expected) <= 3);
assert_isequal(rec.truth.rhythm, 'N');
assert_isequal(size(rec.truth.waves), [K, 12]);
assert_isequal(size(rec.truth.classes), [K, 1]);
assert_istrue(all(rec.truth.classes == 'N'));
%=============================================================================
% Every R lands within one sample of its planted position: the tallest sample
% in a small window around the truth agrees with the truth.
lead = rec.samples(:, 1);
found = zeros(K, 1);
for index = 1:K
  at = rec.truth.beats(index);
  lo = max(1, at - 5);
  hi = min(numel(lead), at + 5);
  window = lead(lo:hi);
  [~, where] = max(window);
  found(index) = lo + where - 1;
end
assert_istrue(max(abs(found - rec.truth.beats)) <= 1);
%=============================================================================
% The wave intervals are physiological (at 60 bpm, about PR 147 ms, QRS 117 ms,
% QT 372 ms). Interior beats only, where both neighbouring RR intervals exist.
w = rec.truth.waves;
inner = 2:(K - 1);
pr = (w(inner, QRSon) - w(inner, Pon)) / 360 * 1000;
qrs = (w(inner, QRSoff) - w(inner, QRSon)) / 360 * 1000;
qt = (w(inner, Toff) - w(inner, QRSon)) / 360 * 1000;
assert_istrue(median(pr) >= 120 && median(pr) <= 200);
assert_istrue(median(qrs) >= 80 && median(qrs) <= 120);
assert_istrue(median(qt) >= 350 && median(qt) <= 450);
% J is the end of the QRS, by definition of the data model.
assert_isequal(w(:, J), w(:, QRSoff));
% R is the reference of the phase, so its offset from the beat sample is zero.
assert_istrue(max(abs(w(:, R) - rec.truth.beats)) <= 1);
%=============================================================================
% The mean RR matches the requested heart rate within two per cent, and the
% spread is within a factor two of the requested one.
rr = rec.truth.rr;
meanRR = mean(rr, 'omitnan');
assert_istrue(abs(meanRR - 1) < 0.02);
wantStd = 60 * 1 / (60 * 60);
gotStd = std(rr, 'omitnan');
assert_istrue(gotStd > wantStd / 2 && gotStd < wantStd * 2);
%=============================================================================
% The R peak of lead II is the requested amplitude, setting the whole scale.
recA = ecglab.simulate('Seconds', 10, 'Rate', 360, 'Amplitude', 2.0, 'Seed', 8);
assert_isapprox(max(recA.samples(:, 1)), 2.0, 0.05);
%=============================================================================
% Ectopic beats are premature ventricular: early, wider QRS, no P wave. The
% requested fraction appears, each early and followed by a compensatory pause.
recE = ecglab.simulate('Seconds', 120, 'Rate', 360, 'HeartRate', 60, ...
'Ectopic', 0.15, 'Seed', 2);
isV = (recE.truth.classes == 'V');
assert_istrue(sum(isV) >= 1);
% No ectopic carries a P wave.
assert_istrue(all(isnan(recE.truth.waves(isV, Pon))));
assert_istrue(all(isnan(recE.truth.waves(isV, Ppeak))));
% A normal beat keeps its P wave.
assert_istrue(all(~isnan(recE.truth.waves(~isV, Pon))));
% The ectopic QRS is wider than a normal one.
ve = recE.truth.waves;
qrsAll = ve(:, QRSoff) - ve(:, QRSon);
assert_istrue(median(qrsAll(isV)) > 1.5 * median(qrsAll(~isV)));
% Each ectopic beat is early, then followed by a longer compensatory interval.
rrE = recE.truth.rr;
vidx = find(isV);
vidx = vidx(vidx > 1 & vidx < numel(rrE));
assert_istrue(~isempty(vidx));
for index = 1:numel(vidx)
  here = vidx(index);
  assert_istrue(rrE(here) < 0.85);
  assert_istrue(rrE(here + 1) > 1.1);
end
%=============================================================================
% Atrial fibrillation makes the recording irregular and P-less: the RR
% coefficient of variation is larger than the sinus one and the rhythm is AFIB.
recF = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 60, ...
'Fibrillation', true, 'Seed', 3);
assert_isequal(recF.truth.rhythm, 'AFIB');
cvFib = std(recF.truth.rr, 'omitnan') / mean(recF.truth.rr, 'omitnan');
cvSinus = std(rr, 'omitnan') / mean(rr, 'omitnan');
assert_istrue(cvFib > cvSinus);
assert_istrue(cvFib > 0.1);
assert_istrue(all(isnan(recF.truth.waves(:, Pon))));
assert_istrue(all(isnan(recF.truth.waves(:, Ppeak))));
%=============================================================================
% With the same seed the morphology is identical, so the difference of a noisy
% and a quiet recording is the noise alone, with the requested RMS.
quiet = ecglab.simulate('Seconds', 30, 'Rate', 360, 'Seed', 4, 'Noise', 0);
noisy = ecglab.simulate('Seconds', 30, 'Rate', 360, 'Seed', 4, 'Noise', 0.1);
delta = noisy.samples - quiet.samples;
rms = sqrt(mean(delta(:) .^ 2));
assert_istrue(abs(rms - 0.1) < 0.01);
%=============================================================================
% Twelve leads carry the standard names and relative gains: each column is its
% gain over lead II times lead II. Artifacts are off, so the ratio is exact.
rec12 = ecglab.simulate('Seconds', 10, 'Rate', 360, 'Seed', 5, 'Leads', 12);
names = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', ...
'V5', 'V6'};
assert_isequal(rec12.leads, names);
gains = [0.6, 1.0, 0.4, -0.8, 0.1, 0.7, -0.5, 0.4, 0.6, 0.8, 1.0, 1.2];
two = rec12.samples(:, 2);
for index = 1:12
  assert_isapprox(rec12.samples(:, index), gains(index) * two, 1e-9);
end
% V1 has a positive S wave: the negative gain turns the downward S upward.
s1 = rec12.truth.waves(2, S);
assert_istrue(rec12.samples(s1, 7) > 0);
% Leads named by hand keep the names and look up the same gains.
recN = ecglab.simulate('Seconds', 5, 'Rate', 360, 'Seed', 6, ...
'Leads', {'V2', 'II'});
assert_isequal(recN.leads, {'V2', 'II'});
assert_isapprox(recN.samples(:, 1), 0.4 / 1.0 * recN.samples(:, 2), 1e-9);
%=============================================================================
% The annotations are filled from the truth: a rhythm mark at the first sample,
% then one beat mark per R with its class as the symbol.
assert_isequal(rec.annotations.kind, 'ecglab.annotations');
assert_isequal(rec.annotations.symbol(1), '+');
assert_isequal(rec.annotations.aux{1}, '(N');
assert_isequal(rec.annotations.sample(1), 1);
beatMarks = rec.annotations.sample(2:end);
assert_isequal(beatMarks, rec.truth.beats);
assert_isequal(rec.annotations.symbol(2:end), rec.truth.classes);
% A fibrillating recording opens with an AFIB rhythm mark.
assert_isequal(recF.annotations.aux{1}, '(AFIB');
%=============================================================================
% The same seed gives the same recording, NaN waves included (reproducible).
one = ecglab.simulate('Seconds', 20, 'Rate', 360, 'Seed', 7, 'Ectopic', 0.1);
two = ecglab.simulate('Seconds', 20, 'Rate', 360, 'Seed', 7, 'Ectopic', 0.1);
assert_istrue(isequaln(one, two));
%=============================================================================
% A seeded call leaves the global generator as it found it, so simulating a
% fixture mid-test does not perturb the rest of the test.
rng(123);
before = rng();
ecglab.simulate('Seconds', 5, 'Rate', 360, 'Seed', 1);
assert_isequal(rng(), before);
%=============================================================================
% A bad option is refused, with the module's two standard messages.
assert_checkerror('ecglab.simulate(''Nope'', 1)', 'Unknown option: Nope.');
assert_checkerror('ecglab.simulate(''Seconds'')', ...
'Options come in name and value pairs.');
%=============================================================================
% Each value check refuses a bad number with a clear error.
assert_checkerror('ecglab.simulate(''Rate'', 0)', ...
'The rate must be one positive number of hertz.');
assert_checkerror('ecglab.simulate(''Seconds'', -1)', ...
'The length must be a positive number of seconds.');
assert_checkerror('ecglab.simulate(''HeartRate'', 0)', ...
'The heart rate must be a positive number of beats a minute.');
assert_checkerror('ecglab.simulate(''Ectopic'', 2)', ...
'The ectopic fraction must be between zero and one.');
assert_checkerror('ecglab.simulate(''Seed'', 1.5)', ...
'The seed must be a non-negative integer.');
assert_checkerror('ecglab.simulate(''Leads'', 99)', ...
'A lead count must be between one and twelve.');
%=============================================================================
% Baseline wander and mains hum are added to every lead. Subtracting a quiet
% recording leaves the artifact alone; the baseline is a 0.2 Hz sine, RMS
% amplitude over root two.
quietA = ecglab.simulate('Seconds', 30, 'Rate', 360, 'Seed', 10);
withB = ecglab.simulate('Seconds', 30, 'Rate', 360, 'Seed', 10, 'Baseline', 0.3);
db = withB.samples - quietA.samples;
assert_isapprox(sqrt(mean(db(:) .^ 2)), 0.3 / sqrt(2), 0.02);
assert_isapprox(max(abs(db(:))), 0.3, 0.02);
% The mains is a 60 Hz sine; over whole cycles its RMS is the amplitude over
% root two.
withM = ecglab.simulate('Seconds', 30, 'Rate', 360, 'Seed', 10, 'Mains', 0.2);
dm = withM.samples - quietA.samples;
assert_isapprox(sqrt(mean(dm(:) .^ 2)), 0.2 / sqrt(2), 0.02);
%=============================================================================
% Atrial fibrillation plants a 0.05 mV f-wave at 6 Hz instead of the P wave.
% Its size is read by projecting the lead onto a 6 Hz sine and cosine.
tinyF = ecglab.simulate('Seconds', 60, 'Rate', 360, 'Fibrillation', true, ...
'Amplitude', 0.01, 'Seed', 3);
tinyN = ecglab.simulate('Seconds', 60, 'Rate', 360, 'Amplitude', 0.01, 'Seed', 1);
nF = size(tinyF.samples, 1);
tF = (0:nF - 1)' / 360;
xF = tinyF.samples(:, 1);
xN = tinyN.samples(:, 1);
mag6 = sqrt((2 / nF * sum(xF .* sin(2 * pi * 6 * tF))) ^ 2 + ...
(2 / nF * sum(xF .* cos(2 * pi * 6 * tF))) ^ 2);
mag5 = sqrt((2 / nF * sum(xF .* sin(2 * pi * 5 * tF))) ^ 2 + ...
(2 / nF * sum(xF .* cos(2 * pi * 5 * tF))) ^ 2);
mag6n = sqrt((2 / nF * sum(xN .* sin(2 * pi * 6 * tF))) ^ 2 + ...
(2 / nF * sum(xN .* cos(2 * pi * 6 * tF))) ^ 2);
assert_isapprox(mag6, 0.05, 0.1);
assert_istrue(mag6 > 10 * mag5);
assert_istrue(mag6 > 10 * mag6n);
%=============================================================================
