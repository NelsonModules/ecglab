%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_RHYTHM() detects the rhythm of every AF Database record with a
% signal, scores it against the .atr rhythm annotations with the episodes basis
% of ecglab.validate, and writes the table to data/ecglab_rhythm_afdb.md.
%
% MAKE_ECGLAB_RHYTHM(RECORDS) runs only the named records (char or cellstr).
%
% For each record the rhythm is detected from the signal and compared with the
% reference rhythm from the '+' marks. Atrial fibrillation episodes and time are
% scored per ANSI/AAMI EC57 (survey 5.1): episode and duration Se and +P, plus
% per-second AF Se, Sp and Cohen's kappa. Published per-window figures are
% printed as those papers' numbers, not measured here.
%
% Records are read from prefdir()/ecglab_reference/afdb; nothing is downloaded.
function pooled = make_ecglab_rhythm(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  % run(loader.m) inside a function resets the argument state, so nargin reads as
  % zero afterwards even when RECORDS was supplied; capture the request before
  % loading the module.
  hasRecords = nargin >= 1 && ~isempty(records);
  if hasRecords
    requested = records;
  end
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/afdb'];
  if hasRecords
    records = requested;
  else
    records = ecgLabMakeRhythmRecords(databaseDir);
  end
  if ischar(records)
    records = {records};
  end
  outPath = [here, '/ecglab_rhythm_afdb.md'];
  %===========================================================================
  % One pass over the records. Each is read once, its rhythm detected and scored
  % against the same marks. A record with no signal, or one that fails to read,
  % detect or score, is skipped.
  agreements = {};
  skipped = {};
  for index = 1:numel(records)
    name = records{index};
    base = [databaseDir, '/', name];
    if ~isfile([base, '.hea']) || ~isfile([base, '.dat']) || ...
      ~isfile([base, '.atr'])
      skipped{end + 1} = name;
      continue;
    end
    try
      rec = ecglab.reference(['afdb/', name], 'Download', false);
      detected = ecglab.rhythm(rec);
      ag = ecglab.validate(detected, rec, 'Kind', 'episodes', 'Record', name);
      agreements{end + 1} = ag;
      fprintf('%s: ep Se %.3f +P %.3f, dur Se %.3f +P %.3f, sec Se %.3f Sp %.3f\n', ...
      name, ag.episodeSe, ag.episodePpv, ag.durationSe, ag.durationPpv, ...
      ag.secondSe, ag.secondSp);
    catch reason
      skipped{end + 1} = name;
      fprintf('Skipped %s: %s\n', name, reason.message);
    end
  end
  if isempty(agreements)
    error('ecglab:noRecordsNoAfDatabaseRecord', 'No AF Database record with a signal was scored.');
  end
  %===========================================================================
  % Pool the per-record agreements. The gross figure sums counts then takes the
  % rate, so long or fibrillation-rich records weigh more; the average figure
  % means the per-record rates, so every record weighs the same. Both are
  % reported.
  pooled = ecgLabMakeRhythmPool(agreements);
  lines = ecgLabMakeRhythmHeader(records, agreements, skipped);
  lines = [lines; ecgLabMakeRhythmTable(agreements, pooled)];
  ecgLabMakeRhythmWrite(outPath, lines);
  fprintf('Wrote %s (%d records scored, %d skipped).\n', outPath, ...
  numel(agreements), numel(skipped));
end
%=============================================================================
function records = ecgLabMakeRhythmRecords(databaseDir)
  % Every AF Database record with a signal on disk, from the RECORDS list, kept
  % to those with a .dat (the first two records ship annotations without signal).
  recordsFile = [databaseDir, '/RECORDS'];
  names = {};
  if isfile(recordsFile)
    parts = strsplit(strtrim(fileread(recordsFile)), char(10));
    for index = 1:numel(parts)
      one = strtrim(parts{index});
      if ~isempty(one)
        names{end + 1} = one;
      end
    end
  else
    listing = dir([databaseDir, '/*.dat']);
    for index = 1:numel(listing)
      names{end + 1} = listing(index).name(1:end - 4);
    end
  end
  records = {};
  for index = 1:numel(names)
    if isfile([databaseDir, '/', names{index}, '.dat'])
      records{end + 1} = names{index};
    end
  end
end
%=============================================================================
function pooled = ecgLabMakeRhythmPool(agreements)
  count = numel(agreements);
  refEpisodes = 0;
  detEpisodes = 0;
  refHit = 0;
  detHit = 0;
  refTime = 0;
  detTime = 0;
  covered = 0;
  tp = 0;
  fn = 0;
  fp = 0;
  tn = 0;
  durSe = nan(count, 1);
  durPpv = nan(count, 1);
  secSe = nan(count, 1);
  secSp = nan(count, 1);
  for index = 1:count
    a = agreements{index};
    refEpisodes = refEpisodes + a.refEpisodes;
    detEpisodes = detEpisodes + a.detEpisodes;
    refHit = refHit + a.refEpisodesHit;
    detHit = detHit + a.detEpisodesHit;
    refTime = refTime + a.refTime;
    detTime = detTime + a.detTime;
    covered = covered + a.coveredTime;
    tp = tp + a.tp;
    fn = fn + a.fn;
    fp = fp + a.fp;
    tn = tn + a.tn;
    durSe(index) = a.durationSe;
    durPpv(index) = a.durationPpv;
    secSe(index) = a.secondSe;
    secSp(index) = a.secondSp;
  end
  pooled = struct();
  pooled.grossEpisodeSe = ecgLabMakeRhythmRatio(refHit, refEpisodes);
  pooled.grossEpisodePpv = ecgLabMakeRhythmRatio(detHit, detEpisodes);
  pooled.grossDurationSe = ecgLabMakeRhythmRatio(covered, refTime);
  pooled.grossDurationPpv = ecgLabMakeRhythmRatio(covered, detTime);
  pooled.grossSecondSe = ecgLabMakeRhythmRatio(tp, tp + fn);
  pooled.grossSecondSp = ecgLabMakeRhythmRatio(tn, tn + fp);
  pooled.kappa = ecgLabMakeRhythmKappa(tp, fn, fp, tn);
  pooled.averageDurationSe = ecgLabMakeRhythmMean(durSe);
  pooled.averageDurationPpv = ecgLabMakeRhythmMean(durPpv);
  pooled.averageSecondSe = ecgLabMakeRhythmMean(secSe);
  pooled.averageSecondSp = ecgLabMakeRhythmMean(secSp);
  pooled.refEpisodes = refEpisodes;
  pooled.detEpisodes = detEpisodes;
  pooled.refAfMinutes = refTime / 60;
  pooled.detAfMinutes = detTime / 60;
end
%=============================================================================
function value = ecgLabMakeRhythmRatio(numerator, denominator)
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
function value = ecgLabMakeRhythmMean(column)
  use = ~isnan(column);
  if any(use)
    value = mean(column(use));
  else
    value = NaN;
  end
end
%=============================================================================
function kappa = ecgLabMakeRhythmKappa(tp, fn, fp, tn)
  n = tp + fn + fp + tn;
  if n == 0
    kappa = NaN;
    return;
  end
  po = (tp + tn) / n;
  pe = ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / (n * n);
  if abs(1 - pe) < eps
    kappa = 1;
  else
    kappa = (po - pe) / (1 - pe);
  end
end
%=============================================================================
function lines = ecgLabMakeRhythmHeader(records, agreements, skipped)
  lines = {};
  lines{end + 1} = '# Atrial fibrillation on the AF Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_rhythm.m.'];
  lines{end + 1} = '';
  lines{end + 1} = sprintf(['- Database: MIT-BIH Atrial Fibrillation ', ...
  'Database (afdb), %d record(s) requested, %d scored.'], numel(records), ...
  numel(agreements));
  lines{end + 1} = ['- Detection: ecglab.rhythm with its default window of ', ...
  '128 beats, stepped one beat, on beats from the default detector; the ', ...
  'RR series alone (no delineation), so the coefficient of sample entropy ', ...
  'and the normalised RMSSD decide.'];
  lines{end + 1} = ['- Thresholds: coefficient of sample entropy above -1 ', ...
  'at template length one with a tolerance of 0.1 of the mean RR, and a ', ...
  'normalised RMSSD above 0.1; taken from the literature (survey 5.8), not ', ...
  'fitted to this database.'];
  lines{end + 1} = ['- Reference: the record''s own .atr rhythm marks; the ', ...
  'label scored is fixed to AFIB (the episodes basis takes no option to name ', ...
  'another rhythm, as validate.m owns the option set; atrial flutter and ', ...
  'junctional rhythm count as not-AFIB, the detector not separating them from ', ...
  'the RR series).'];
  lines{end + 1} = ['- Figures: ANSI/AAMI EC57 episode and duration ', ...
  'sensitivity and positive predictivity (epicmp, survey 5.1), and the ', ...
  'per-second atrial fibrillation sensitivity and specificity and Cohen''s ', ...
  'kappa over the two labels.'];
  lines{end + 1} = ['- Published per-window figures, for comparison only and ', ...
  'measured by those papers on this database, not here: Tateno and Glass ', ...
  '2001 Se 94.4 Sp 97.2; Petrenas et al. 2015 Se 97.1 Sp 98.3 (survey 5.8).'];
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
  if ~isempty(skipped)
    lines{end + 1} = ['- Skipped (no signal or annotator on disk, or a read ', ...
    'error): ', strjoin(skipped, ', '), '.'];
  end
  lines = lines(:);
end
%=============================================================================
function lines = ecgLabMakeRhythmTable(agreements, pooled)
  lines = {};
  lines{end + 1} = '';
  lines{end + 1} = '## Per record';
  lines{end + 1} = '';
  lines{end + 1} = ['| Record | Ref AF ep | Det AF ep | Ep Se | Ep +P | ', ...
  'Dur Se | Dur +P | Sec Se | Sec Sp | Kappa | Ref AF min |'];
  lines{end + 1} = '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|';
  for index = 1:numel(agreements)
    a = agreements{index};
    lines{end + 1} = ['| ', a.record, ' | ', ...
    sprintf('%d', a.refEpisodes), ' | ', sprintf('%d', a.detEpisodes), ' | ', ...
    ecgLabMakeRhythmPct(a.episodeSe), ' | ', ecgLabMakeRhythmPct(a.episodePpv), ...
    ' | ', ecgLabMakeRhythmPct(a.durationSe), ' | ', ...
    ecgLabMakeRhythmPct(a.durationPpv), ' | ', ...
    ecgLabMakeRhythmPct(a.secondSe), ' | ', ecgLabMakeRhythmPct(a.secondSp), ...
    ' | ', ecgLabMakeRhythmNum(a.kappa), ' | ', ...
    sprintf('%.1f', a.refTime / 60), ' |'];
  end
  lines{end + 1} = '';
  lines{end + 1} = '## Pooled over the database';
  lines{end + 1} = '';
  lines{end + 1} = '| Figure | Gross | Average |';
  lines{end + 1} = '|---|---:|---:|';
  lines{end + 1} = ['| Episode sensitivity | ', ...
  ecgLabMakeRhythmPct(pooled.grossEpisodeSe), ' | - |'];
  lines{end + 1} = ['| Episode positive predictivity | ', ...
  ecgLabMakeRhythmPct(pooled.grossEpisodePpv), ' | - |'];
  lines{end + 1} = ['| Duration sensitivity | ', ...
  ecgLabMakeRhythmPct(pooled.grossDurationSe), ' | ', ...
  ecgLabMakeRhythmPct(pooled.averageDurationSe), ' |'];
  lines{end + 1} = ['| Duration positive predictivity | ', ...
  ecgLabMakeRhythmPct(pooled.grossDurationPpv), ' | ', ...
  ecgLabMakeRhythmPct(pooled.averageDurationPpv), ' |'];
  lines{end + 1} = ['| Per-second sensitivity | ', ...
  ecgLabMakeRhythmPct(pooled.grossSecondSe), ' | ', ...
  ecgLabMakeRhythmPct(pooled.averageSecondSe), ' |'];
  lines{end + 1} = ['| Per-second specificity | ', ...
  ecgLabMakeRhythmPct(pooled.grossSecondSp), ' | ', ...
  ecgLabMakeRhythmPct(pooled.averageSecondSp), ' |'];
  lines{end + 1} = ['| Per-second Cohen kappa | ', ...
  ecgLabMakeRhythmNum(pooled.kappa), ' | - |'];
  lines{end + 1} = '';
  lines{end + 1} = sprintf(['_Pooled reference atrial fibrillation: %.1f ', ...
  'min over %d episodes; detected %.1f min over %d episodes._'], ...
  pooled.refAfMinutes, pooled.refEpisodes, pooled.detAfMinutes, ...
  pooled.detEpisodes);
  lines{end + 1} = '';
  lines{end + 1} = ['_For comparison, the per-window figures those papers ', ...
  'report on this database (not a figure of EC57, and not measured here): ', ...
  'Tateno and Glass 2001 Se 94.4 Sp 97.2; Petrenas et al. 2015 Se 97.1 ', ...
  'Sp 98.3._'];
  lines = lines(:);
end
%=============================================================================
function text = ecgLabMakeRhythmPct(value)
  if isnan(value)
    text = '-';
  else
    text = sprintf('%.1f', value * 100);
  end
end
%=============================================================================
function text = ecgLabMakeRhythmNum(value)
  if isnan(value)
    text = '-';
  else
    text = sprintf('%.3f', value);
  end
end
%=============================================================================
function ecgLabMakeRhythmWrite(outPath, lines)
  fid = fopen(outPath, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotWriteS', 'Cannot write %s.', outPath);
  end
  for index = 1:numel(lines)
    fprintf(fid, '%s\n', lines{index});
  end
  fclose(fid);
end
%=============================================================================
