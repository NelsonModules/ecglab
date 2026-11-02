%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Tests ecglab.rhythm (AF labelling and episodes) and the 'episodes' basis of
% ecglab.validate. The truth is planted; one AF record is used when on disk.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
% A simulated fibrillation recording is labelled AF over most of its length;
% a normal sinus one is not.
fib = ecglab.simulate('Seconds', 90, 'Fibrillation', true, 'Seed', 7);
rhythmFib = ecglab.rhythm(fib);
assert(strcmp(rhythmFib.kind, 'ecglab.rhythm'));
assert(rhythmFib.afBurden > 0.8, ...
'A simulated fibrillation night must be labelled atrial fibrillation.');
assert(sum(strcmp(rhythmFib.perBeat, 'AFIB')) > ...
0.8 * numel(rhythmFib.perBeat));

normal = ecglab.simulate('Seconds', 90, 'HeartRate', 70, 'Seed', 3);
rhythmNormal = ecglab.rhythm(normal);
assert(rhythmNormal.afBurden < 0.1, ...
'A simulated sinus rhythm must not be labelled atrial fibrillation.');
%=============================================================================
% Normal, fibrillation, normal: one AF episode near the two splices and a
% burden near one third. A smaller window is used on this short record.
rng(11);
recN1 = ecglab.simulate('Seconds', 80, 'HeartRate', 75, 'Seed', 21);
recAf = ecglab.simulate('Seconds', 80, 'Fibrillation', true, 'Seed', 22);
recN2 = ecglab.simulate('Seconds', 80, 'HeartRate', 75, 'Seed', 23);
rate = recN1.rate;
signal = [recN1.samples(:, 1); recAf.samples(:, 1); recN2.samples(:, 1)];
split = ecglab.rhythm(signal, 'Rate', rate, 'Window', 32, 'MinEpisode', 20);
afMask = strcmp(split.episodes.label, 'AFIB');
assert(sum(afMask) == 1, ...
'A normal, fibrillation, normal record has exactly one fibrillation episode.');
onset = split.episodes.onset(afMask);
offset = split.episodes.offset(afMask);
assert(abs(onset - 80) < 20, 'The episode onset is near the first splice.');
assert(abs(offset - 160) < 20, 'The episode offset is near the second splice.');
assert(abs(split.afBurden - 1 / 3) < 0.15, ...
'The burden is near the true fibrillation third.');
%=============================================================================
% A flip shorter than MinEpisode must not become an episode: the irregular
% patch is flagged but smoothed away, so the burden is zero.
base = 0.8;
rrRegular = base * ones(240, 1);
% The patch is irregular and unpredictable, the two marks of fibrillation.
rng(5);
rrPatch = max(base * (1 + 0.3 * randn(24, 1)), 0.3);
rrAll = [rrRegular; rrPatch; rrRegular];
sampleBeats = round(cumsum(rrAll) * rate) + 1;
beats = struct('kind', 'ecglab.beats', 'sample', sampleBeats, ...
'time', (sampleBeats - 1) / rate, 'rr', [NaN; diff((sampleBeats - 1) / rate)]);
smoothed = ecglab.rhythm(beats, 'Rate', rate, 'Window', 12, 'MinEpisode', 30);
assert(smoothed.afBurden == 0, ...
'A flip shorter than MinEpisode must not survive as an episode.');
kept = ecglab.rhythm(beats, 'Rate', rate, 'Window', 12, 'MinEpisode', 1);
assert(any(strcmp(kept.episodes.label, 'AFIB')), ...
'With a tiny MinEpisode the irregular patch is kept as an episode.');
%=============================================================================
% The fibrillation verdict depends on the shape of the RR series, not its speed:
% the same pattern at a faster or slower heart rate gives the same labels and
% burden. Smoothing is off (MinEpisode zero) so the labels are the window vote.
rng(17);
rrShape = [base * ones(120, 1); ...
max(base * (1 + 0.3 * randn(80, 1)), 0.3); base * ones(120, 1)];
rrSlow = rrShape;
rrFast = 0.6 * rrShape;
tSlow = cumsum(rrSlow);
tFast = cumsum(rrFast);
beatsSlow = struct('kind', 'ecglab.beats', 'sample', round(tSlow * rate) + 1, ...
'time', tSlow, 'rr', [NaN; diff(tSlow)]);
beatsFast = struct('kind', 'ecglab.beats', 'sample', round(tFast * rate) + 1, ...
'time', tFast, 'rr', [NaN; diff(tFast)]);
slow = ecglab.rhythm(beatsSlow, 'Rate', rate, 'Window', 40, 'MinEpisode', 0);
fast = ecglab.rhythm(beatsFast, 'Rate', rate, 'Window', 40, 'MinEpisode', 0);
assert(slow.afBurden > 0, ...
'The irregular patch is flagged at the slow heart rate.');
assert(isequal(slow.perBeat, fast.perBeat), ...
'The per-beat labels do not change when the heart rate is scaled.');
assert(abs(slow.afBurden - fast.afBurden) < 1e-12, ...
'The atrial fibrillation burden is invariant to the heart rate.');
%=============================================================================
% The 'episodes' basis of ecglab.validate on hand-built rhythm structs. A
% covered reference episode scores Se one; a spurious detection lowers PPV.
reference = ecgLabTestRhythm([0; 100], [100; 200], {'N'; 'AFIB'});
perfect = ecgLabTestRhythm([0; 100], [100; 200], {'N'; 'AFIB'});
ag = ecglab.validate(perfect, reference, 'Kind', 'episodes');
assert(strcmp(ag.basis, 'episodes'));
assert(abs(ag.episodeSe - 1) < 1e-9, 'A covered reference episode is Se one.');
assert(abs(ag.episodePpv - 1) < 1e-9);
assert(abs(ag.durationSe - 1) < 1e-9, 'The reference time is fully covered.');
assert(abs(ag.durationPpv - 1) < 1e-9);

% An extra detected episode with no reference: Se stays one, but episode PPV
% is a half and duration PPV drops by the spurious twenty seconds.
noisy = ecgLabTestRhythm([0; 50; 70; 100], [50; 70; 100; 200], ...
{'N'; 'AFIB'; 'N'; 'AFIB'});
ag2 = ecglab.validate(noisy, reference, 'Kind', 'episodes');
assert(abs(ag2.episodeSe - 1) < 1e-9);
assert(abs(ag2.episodePpv - 0.5) < 1e-9, 'One of two detections is spurious.');
assert(abs(ag2.durationSe - 1) < 1e-9);
assert(abs(ag2.durationPpv - 100 / 120) < 1e-9, ...
'Twenty spurious seconds against a hundred true ones.');
% The per-second agreement and Cohen's kappa are defined over the two labels.
assert(ag2.secondSe >= 0 && ag2.secondSe <= 1);
assert(ag2.secondSp >= 0 && ag2.secondSp <= 1);
assert(ag.kappa > 0.99, 'Two identical timelines agree almost perfectly.');
%=============================================================================
% The P-wave condition: an irregular RR series alone is labelled fibrillation,
% a P wave on every beat withdraws the label, no P wave leaves it standing.
rng(31);
rrIrr = max(0.8 * (1 + 0.3 * randn(200, 1)), 0.3);
sampleIrr = round(cumsum(rrIrr) * rate) + 1;
beatsIrr = struct('kind', 'ecglab.beats', 'sample', sampleIrr, ...
'time', (sampleIrr - 1) / rate, 'rr', [NaN; diff((sampleIrr - 1) / rate)]);
rrOnly = ecglab.rhythm(beatsIrr, 'Rate', rate, 'Window', 32, 'MinEpisode', 1);
assert(rrOnly.afBurden > 0, ...
'An irregular unpredictable RR series alone is labelled fibrillation.');
tWaves = beatsIrr.time;
withP = ecglab.rhythm(beatsIrr, 'Rate', rate, 'Window', 32, ...
'MinEpisode', 1, 'Waves', ecgLabTestWaves(tWaves, true));
assert(withP.settings.usedWaves, 'The delineation was used.');
assert(withP.afBurden == 0, ...
'A present P wave on every beat withdraws the fibrillation label.');
withoutP = ecglab.rhythm(beatsIrr, 'Rate', rate, 'Window', 32, ...
'MinEpisode', 1, 'Waves', ecgLabTestWaves(tWaves, false));
assert(withoutP.afBurden > 0, ...
'An absent P wave on every beat keeps the fibrillation label.');
% A Waves argument that is not a delineation is refused.
failed = false;
try
  ecglab.rhythm(beatsIrr, 'Rate', rate, 'Waves', struct('kind', 'nope'));
catch e
  failed = startsWith(e.identifier, 'ecglab:badWaves');
end
assert(failed, 'A Waves argument that is not a delineation is refused.');
%=============================================================================
% Errors: a bad option, a signal too short, and an unknown kind from validate.
failed = false;
try
  ecglab.rhythm(normal, 'Nope', 1);
catch e
  failed = startsWith(e.identifier, 'ecglab:unknownOption');
end
assert(failed, 'An unknown option is refused.');

failed = false;
try
  ecglab.rhythm(randn(200, 1), 'Rate', 360);
catch e
  failed = startsWith(e.identifier, 'ecglab:tooShort');
end
assert(failed, 'A signal too short is refused.');

failed = false;
try
  ecglab.validate(perfect, reference, 'Kind', 'nonsense');
catch e
  failed = startsWith(e.identifier, 'ecglab:validateKind');
end
assert(failed, 'An unknown kind is reported by validate.');

% The episodes basis scores AFIB only: there is no 'Label' option, so passing
% one is an unknown option.
failed = false;
try
  ecglab.validate(perfect, reference, 'Kind', 'episodes', 'Label', 'AFIB');
catch e
  failed = startsWith(e.identifier, 'ecglab:unknownOption');
end
assert(failed, 'The episodes basis takes no Label option; AFIB is fixed.');
%=============================================================================
% One AF Database record, only when on disk: detected, validated against its
% own .atr annotations, and the AF duration sensitivity must clear a loose bound.
afdbFolder = [prefdir(), '/ecglab_reference/afdb'];
if isfile([afdbFolder, '/04015.dat'])
  recording = ecglab.reference('afdb/04015', 'Download', false);
  detected = ecglab.rhythm(recording);
  agAf = ecglab.validate(detected, recording, 'Kind', 'episodes');
  assert(agAf.durationSe > 0.5, ...
  'The atrial fibrillation duration sensitivity clears a loose bound.');
else
  disp('AF Database record 04015 is not on disk; the real-record check is skipped.');
end
%=============================================================================
function r = ecgLabTestRhythm(onset, offset, label)
  % A minimal rhythm struct for the episodes-basis test: contiguous episodes
  % tiling the span, so validate can rebuild the label timeline.
  r = struct();
  r.kind = 'ecglab.rhythm';
  r.episodes = struct('onset', onset(:), 'offset', offset(:), ...
  'label', {label(:)});
  r.perBeat = {};
  r.afBurden = NaN;
  r.settings = struct('span', [min(onset(:)), max(offset(:))]);
end
%=============================================================================
function w = ecgLabTestWaves(times, pPresent)
  % A minimal ecglab.waves struct for the P-absence test: the R column carries
  % each beat time, the P onset and peak columns are finite only when present.
  n = numel(times);
  t = nan(n, 12);
  t(:, 6) = times(:);
  if pPresent
    t(:, 1) = times(:) - 0.2;
    t(:, 2) = times(:) - 0.15;
  end
  w = struct();
  w.kind = 'ecglab.waves';
  w.columns = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', 'QRSoff', ...
  'J', 'Ton', 'Tpeak', 'Toff'};
  w.sample = nan(n, 12);
  w.time = t;
end
%=============================================================================
