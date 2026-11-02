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
% Cleaning must remove baseline wander and mains hum and leave the QRS height,
% the ST level and the beat positions. Each fixture is a clean simulated twin
% plus a known artifact, so the cleaned signal is compared with the truth.
%=============================================================================
rate = 360;
seconds = 60;
seed = 1;
% The clean twin and the contaminated record share the seed; the only
% difference is a 0.5 mV 0.2 Hz baseline and a 0.1 mV 50 Hz mains line.
ref = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'Seed', seed);
dirty = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'Seed', seed, ...
'Baseline', 0.5, 'BaselineFrequency', 0.2, 'Mains', 0.1, ...
'MainsFrequency', 50);
N = size(ref.samples, 1);
truthBeats = ref.truth.beats;
%=============================================================================
% The power at one frequency, summed over the bins within 0.1 Hz of it.
fftPower = @(x, f) localBandPower(x, rate, f, 0.1);
%=============================================================================
% Baseline by zero-phase high pass, mains by auto. The power at 0.2 Hz and at
% 50 Hz each falls by at least 20 dB.
cleaned = ecglab.clean(dirty, 'Baseline', 'highpass', 'Mains', 'auto');
assert_isequal(cleaned.kind, 'ecglab.recording');
assert_isequal(size(cleaned.samples), size(dirty.samples));
x0 = dirty.samples(:, 1);
x1 = cleaned.samples(:, 1);
dropBaseline = 10 * log10(fftPower(x0, 0.2) / fftPower(x1, 0.2));
dropMains = 10 * log10(fftPower(x0, 50) / fftPower(x1, 50));
assert_istrue(dropBaseline >= 20);
assert_istrue(dropMains >= 20);
%=============================================================================
% The QRS height must survive: the peak-to-trough height in a 100 ms window
% about each true R is within 5 per cent of the clean twin.
ampRef = localQrsAmplitude(ref.samples(:, 1), truthBeats, rate);
ampClean = localQrsAmplitude(x1, truthBeats, rate);
inner = 2:(numel(truthBeats) - 1);
ratio = ampClean(inner) ./ ampRef(inner);
assert_istrue(max(abs(ratio - 1)) <= 0.05);
%=============================================================================
% Detection on the contaminated and the cleaned record gives the same count
% and every beat moves by less than 20 ms.
beatsDirty = ecglab.detect(dirty);
beatsClean = ecglab.detect(cleaned);
assert_istrue(abs(numel(beatsDirty.sample) - numel(beatsClean.sample)) <= 1);
shift = localMatchShift(beatsDirty.sample, beatsClean.sample, rate);
assert_istrue(shift <= 20);
%=============================================================================
% The ST level must survive: the mean of an 80 ms window 80 ms after R, minus
% the PQ level, is within 0.05 mV of the clean twin. The high pass is shown on
% the 0.5 mV 0.2 Hz wander; the median on a 0.25 mV 0.15 Hz respiratory wander.
stRef = localStLevel(ref.samples(:, 1), truthBeats, rate);
cleanHp = ecglab.clean(dirty, 'Baseline', 'highpass', 'Mains', false);
stHp = localStLevel(cleanHp.samples(:, 1), truthBeats, rate);
assert_istrue(max(abs(stHp(inner) - stRef(inner))) <= 0.05);
resp = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'Seed', seed, ...
'Baseline', 0.25, 'BaselineFrequency', 0.15);
cleanMed = ecglab.clean(resp, 'Baseline', 'median', 'Mains', false);
stMed = localStLevel(cleanMed.samples(:, 1), truthBeats, rate);
assert_istrue(max(abs(stMed(inner) - stRef(inner))) <= 0.05);
%=============================================================================
% Auto mains removes only what is there: 50 on a 50 Hz record, 60 on a 60 Hz
% one, and nothing on a clean one.
dirty60 = ecglab.simulate('Seconds', seconds, 'Rate', rate, 'Seed', seed, ...
'Mains', 0.1, 'MainsFrequency', 60);
picked50 = ecglab.clean(dirty, 'Baseline', 'none', 'Mains', 'auto');
picked60 = ecglab.clean(dirty60, 'Baseline', 'none', 'Mains', 'auto');
pickedNone = ecglab.clean(ref, 'Baseline', 'none', 'Mains', 'auto');
assert_isequal(picked50.info.cleaning.mains, 50);
assert_isequal(picked60.info.cleaning.mains, 60);
assert_isequal(pickedNone.info.cleaning.mains, 0);
%=============================================================================
% The cleaning report: baseline method and cut, mains frequency removed, and
% the RMS subtracted per lead (positive here, given the wander).
info = cleaned.info.cleaning;
assert_isequal(info.baseline.method, 'highpass');
assert_isequal(info.baseline.cut, 0.5);
assert_isequal(info.mains, 50);
assert_isequal(numel(info.baselineRemoved), size(dirty.samples, 2));
assert_istrue(info.baselineRemoved(1) > 0.2);
%=============================================================================
% On a clean record both baselines leave the signal almost untouched and agree
% with each other. The edges are left out, where every filter has a transient.
idHp = ecglab.clean(ref, 'Baseline', 'highpass', 'Mains', false);
idMed = ecglab.clean(ref, 'Baseline', 'median', 'Mains', false);
edge = round(rate);
keep = (edge + 1):(N - edge);
refLead = ref.samples(keep, 1);
assert_istrue(max(abs(idHp.samples(keep, 1) - refLead)) <= 0.1);
assert_istrue(max(abs(idMed.samples(keep, 1) - refLead)) <= 0.1);
assert_istrue(max(abs(idHp.samples(keep, 1) - idMed.samples(keep, 1))) <= 0.1);
%=============================================================================
% A plain vector is cleaned as a lead and comes back the same shape and
% orientation, with no recording wrapper and no cleaning report.
vec = dirty.samples(:, 1);
cleanVec = ecglab.clean(vec, 'Rate', rate, 'Baseline', 'highpass');
assert_isequal(size(cleanVec), size(vec));
assert_istrue(isnumeric(cleanVec));
rowVec = vec.';
cleanRow = ecglab.clean(rowVec, 'Rate', rate, 'Baseline', 'highpass');
assert_isequal(size(cleanRow), size(rowVec));
%=============================================================================
% The spline baseline fits a curve through the PQ level before each QRS (it
% detects beats itself) and removes the 0.2 Hz wander like the others.
cleanSpline = ecglab.clean(dirty, 'Baseline', 'spline', 'Mains', false);
dropSpline = 10 * log10(fftPower(x0, 0.2) / ...
fftPower(cleanSpline.samples(:, 1), 0.2));
assert_istrue(dropSpline >= 20);
%=============================================================================
% The Lead option cleans only the named leads and leaves the rest unchanged.
twoLead = ecglab.simulate('Seconds', 20, 'Rate', rate, 'Seed', 2, ...
'Leads', {'II', 'V1'}, 'Baseline', 0.5, 'BaselineFrequency', 0.2);
onlyII = ecglab.clean(twoLead, 'Lead', 'II', 'Baseline', 'highpass', ...
'Mains', false);
assert_isequal(onlyII.samples(:, 2), twoLead.samples(:, 2));
assert_istrue(max(abs(onlyII.samples(:, 1) - twoLead.samples(:, 1))) > 0);
assert_isequal(onlyII.info.cleaning.baselineRemoved(2), 0);
%=============================================================================
% Mains harmonics: with harmonics on, the 50 Hz line and its 100 and 150 Hz
% echoes are all removed, every multiple below the Nyquist.
harm = ref.samples(:, 1) + 0.1 * sin(2 * pi * 50 * (0:N - 1)' / rate) + ...
0.1 * sin(2 * pi * 100 * (0:N - 1)' / rate);
cleanHarm = ecglab.clean(harm, 'Rate', rate, 'Baseline', 'none', ...
'Mains', 50, 'MainsHarmonics', true);
drop100 = 10 * log10(fftPower(harm, 100) / fftPower(cleanHarm, 100));
assert_istrue(drop100 >= 20);
%=============================================================================
% Errors: an unknown baseline method, an unknown option, and a signal too
% short to filter are each refused.
assert_checkerror('ecglab.clean(dirty, ''Baseline'', ''nope'')', ...
'Unknown baseline method: nope.');
assert_checkerror('ecglab.clean(dirty, ''Nope'', 1)', 'Unknown option: Nope.');
assert_checkerror('ecglab.clean([1 2 3 4 5], ''Rate'', 360)', ...
'The signal is too short to clean.');
%=============================================================================
% Speed guard for the two-stage median: a 30 minute random walk at 360 Hz is
% cleaned by the fast sliding median under a generous bound.
bigN = 30 * 60 * 360;
walk = cumsum(randn(bigN, 1)) / 100;
tic;
ecglab.clean(walk, 'Rate', 360, 'Baseline', 'median', 'Mains', false);
medSeconds = toc;
assert_istrue(medSeconds < 5);
%=============================================================================
% Only when the Noise Stress Test Database is on disk: record 118e06 is
% cleaned, and detection must not agree worse with the annotations after
% cleaning than before, measured the EC57 way. Skipped otherwise.
nstdb = [prefdir(), '/ecglab_reference/nstdb'];
if isdir(nstdb)
  record = [nstdb, '/118e06'];
  rec = ecglab.readwfdb(record);
  before = ecglab.detect(rec);
  agBefore = ecglab.validate(before, rec.annotations, 'Record', '118e06');
  cln = ecglab.clean(rec, 'Baseline', 'highpass', 'Mains', 'auto');
  after = ecglab.detect(cln);
  agAfter = ecglab.validate(after, rec.annotations, 'Record', '118e06');
  fprintf('nstdb 118e06 before cleaning: Se %.4f PPV %.4f\n', ...
  agBefore.se, agBefore.ppv);
  fprintf('nstdb 118e06 after  cleaning: Se %.4f PPV %.4f\n', ...
  agAfter.se, agAfter.ppv);
  % The F1 (harmonic mean of sensitivity and positive predictivity) must not
  % drop: cleaning may not make detection worse.
  f1Before = 2 * agBefore.se * agBefore.ppv / (agBefore.se + agBefore.ppv);
  f1After = 2 * agAfter.se * agAfter.ppv / (agAfter.se + agAfter.ppv);
  assert_istrue(f1After >= f1Before - 0.01);
else
  fprintf('Skipped the nstdb check: %s is not on disk.\n', nstdb);
end
%=============================================================================
function p = localBandPower(x, rate, f, halfWidth)
  % The power in a narrow band about f, from the single-sided magnitude
  % spectrum, so a line that leaks across bins is counted whole.
  x = x(:) - mean(x(:));
  n = numel(x);
  X = fft(x);
  half = floor(n / 2) + 1;
  mag2 = abs(X(1:half)) .^ 2;
  freq = (0:half - 1)' * (rate / n);
  band = abs(freq - f) <= halfWidth;
  p = sum(mag2(band)) + eps;
end
%=============================================================================
function amp = localQrsAmplitude(x, beats, rate)
  % The peak to trough height of each beat, over a 100 ms window about R.
  half = round(0.05 * rate);
  n = numel(x);
  amp = zeros(numel(beats), 1);
  for k = 1:numel(beats)
    lo = max(1, beats(k) - half);
    hi = min(n, beats(k) + half);
    seg = x(lo:hi);
    amp(k) = max(seg) - min(seg);
  end
end
%=============================================================================
function level = localStLevel(x, beats, rate)
  % The ST level: the mean of an 80 ms window 80 ms after R, minus the PQ
  % level read just before the complex.
  n = numel(x);
  level = zeros(numel(beats), 1);
  for k = 1:numel(beats)
    pqLo = max(1, beats(k) - round(0.10 * rate));
    pqHi = max(1, beats(k) - round(0.04 * rate));
    stLo = min(n, beats(k) + round(0.08 * rate));
    stHi = min(n, beats(k) + round(0.16 * rate));
    level(k) = mean(x(stLo:stHi)) - mean(x(pqLo:pqHi));
  end
end
%=============================================================================
function shift = localMatchShift(a, b, rate)
  % The largest time gap, in milliseconds, between a beat of a and its nearest
  % beat of b.
  a = a(:);
  b = b(:);
  worst = 0;
  for k = 1:numel(a)
    worst = max(worst, min(abs(b - a(k))));
  end
  shift = worst / rate * 1000;
end
%=============================================================================
