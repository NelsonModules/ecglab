%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_CLASSIFICATION() measures ecglab.classify on the DS2 test set of
% the MIT-BIH Arrhythmia Database (de Chazal 2004 inter-patient split) and
% writes data/ecglab_classification_mitdb.md.
%
% For each DS2 record the beats are detected, classified and compared to the
% .atr annotations with ecglab.validate, which pairs each beat within 150 ms
% and builds the 5 by 5 confusion matrix. Per-class Se and +P use the matched
% block; the detector's miss and extra counts are reported separately.
%
% DS2 shares no patient with the training set, so these are inter-patient
% figures. S positive predictivity is low by nature (de Chazal: 38.5 percent).
%
% MAKE_ECGLAB_CLASSIFICATION(RECORDS) runs only the named records.
function make_ecglab_classification(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/mitdb'];
  outPath = [here, '/ecglab_classification_mitdb.md'];
  modelPath = [here, '/ecglab_classifier.mat'];
  %===========================================================================
  % The de Chazal DS2 test records. Verified against docs/survey.md 5.7.
  ds2 = {'100', '103', '105', '111', '113', '117', '121', '123', '200', ...
  '202', '210', '212', '213', '214', '219', '221', '222', '228', '231', ...
  '232', '233', '234'};
  ds1 = {'101', '106', '108', '109', '112', '114', '115', '116', '118', ...
  '119', '122', '124', '201', '203', '205', '207', '208', '209', '215', ...
  '220', '223', '230'};
  if nargin < 1 || isempty(records)
    records = ds2;
  end
  if ischar(records)
    records = {records};
  end
  detector = 'pantompkins';
  window = 0.15;
  %===========================================================================
  % Detect, classify and validate record by record, each record read once. The
  % per-record agreements are pooled and the detector counts summed. Each record
  % is scored with both priors on the same detected beats: empirical (default)
  % and uniform (lifts the rare classes).
  agreements = {};
  agreementsUniform = {};
  for index = 1:numel(records)
    name = records{index};
    recording = ecglab.readwfdb([databaseDir, '/', name]);
    beats = ecglab.detect(recording, 'Method', detector);
    classified = ecglab.classify(recording, 'Beats', beats, ...
    'Model', modelPath, 'Prior', 'empirical');
    % Learning 0: the classification literature scores every beat, not from five
    % minutes in as the detection comparator does.
    agreement = ecglab.validate(classified.beats, recording.annotations, ...
    'Kind', 'beats', 'Window', window, 'Learning', 0, 'Table', 'dechazal', ...
    'Record', name);
    agreements{end + 1} = agreement;
    classifiedUniform = ecglab.classify(recording, 'Beats', beats, ...
    'Model', modelPath, 'Prior', 'uniform');
    agreementUniform = ecglab.validate(classifiedUniform.beats, ...
    recording.annotations, 'Kind', 'beats', 'Window', window, 'Learning', 0, ...
    'Table', 'dechazal', 'Record', name);
    agreementsUniform{end + 1} = agreementUniform;
    fprintf('%s: tp %d fp %d fn %d.\n', name, agreement.tp, ...
    agreement.fp, agreement.fn);
  end
  %===========================================================================
  % Pool the 6 by 6 matrices, then measure. The matched 5 by 5 block is the
  % classification; the X row and O column are the detector.
  pooled = zeros(6, 6);
  pooledUniform = zeros(6, 6);
  tp = 0;
  fp = 0;
  fn = 0;
  for index = 1:numel(agreements)
    if ~isempty(agreements{index}.matrix)
      pooled = pooled + agreements{index}.matrix;
    end
    if ~isempty(agreementsUniform{index}.matrix)
      pooledUniform = pooledUniform + agreementsUniform{index}.matrix;
    end
    tp = tp + agreements{index}.tp;
    fp = fp + agreements{index}.fp;
    fn = fn + agreements{index}.fn;
  end
  matched = pooled(1:5, 1:5);
  %===========================================================================
  lines = ecgLabClassMakeReport(records, ds1, ds2, detector, window, ...
  modelPath, pooled, matched, tp, fp, fn, pooledUniform);
  fid = fopen(outPath, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotWriteS', 'Cannot write %s.', outPath);
  end
  for index = 1:numel(lines)
    fprintf(fid, '%s\n', lines{index});
  end
  fclose(fid);
  fprintf('Wrote %s.\n', outPath);
end
%=============================================================================
function lines = ecgLabClassMakeReport(records, ds1, ds2, detector, window, ...
  modelPath, pooled, matched, tp, fp, fn, pooledUniform)
  classes = 'NSVFQ';
  total = sum(matched(:));
  accuracy = 0;
  if total > 0
    accuracy = sum(diag(matched)) / total;
  end
  lines = {};
  lines{end + 1} = '# Beat classification on the MIT-BIH Arrhythmia Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_classification.m.'];
  lines{end + 1} = '';
  lines{end + 1} = ['- Database: MIT-BIH Arrhythmia Database (mitdb), ', ...
  sprintf('%d DS2 record(s) scored.', numel(records))];
  lines{end + 1} = ['- Split: de Chazal, O''Dwyer and Reilly 2004, ', ...
  'inter-patient. No beat of a DS2 patient is in the training.'];
  lines{end + 1} = ['- DS1 (train): ', strjoin(ds1, ' '), '.'];
  lines{end + 1} = ['- DS2 (test): ', strjoin(ds2, ' '), '.'];
  lines{end + 1} = ['- The four paced records 102 104 107 217 are in ', ...
  'neither set.'];
  lines{end + 1} = ['- Detector: ', detector, ' (the realistic path; the ', ...
  'classifier meets detected beats, not reference beats).'];
  lines{end + 1} = sprintf('- Matching window: %g ms.', window * 1000);
  lines{end + 1} = '- Class table: dechazal. Reference: the .atr annotations.';
  lines{end + 1} = ['- Training beats aligned to the reference .atr ', ...
  'locations; test beats detected.'];
  lines{end + 1} = ['- Model: data/ecglab_classifier.mat, built by ', ...
  'data/make_ecglab_classifier.m.'];
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
  %===========================================================================
  lines{end + 1} = '';
  lines{end + 1} = '## Pooled confusion matrix';
  lines{end + 1} = '';
  lines{end + 1} = ['Rows are the reference class, columns the assigned ', ...
  'label. The last row X is a detected beat with no reference within the ', ...
  'window (a detector extra); the last column O is a reference beat the ', ...
  'detector missed. The per-class figures below use the N..Q by N..Q ', ...
  'block; X and O are the detector, reported under it.'];
  lines{end + 1} = '';
  header = '| ref \\ label | N | S | V | F | Q | O (missed) |';
  lines{end + 1} = header;
  lines{end + 1} = '|---|---:|---:|---:|---:|---:|---:|';
  rowLabels = {'N', 'S', 'V', 'F', 'Q', 'X (extra)'};
  for r = 1:6
    row = sprintf('| %s |', rowLabels{r});
    for c = 1:6
      row = [row, sprintf(' %d |', pooled(r, c))];
    end
    lines{end + 1} = row;
  end
  %===========================================================================
  lines{end + 1} = '';
  lines{end + 1} = '## Per-class sensitivity and positive predictivity';
  lines{end + 1} = '';
  lines{end + 1} = ['Computed on the matched 5 by 5 block (beats the ', ...
  'detector found and the validator paired), the way de Chazal reports ', ...
  'them: Se = TP / reference beats of the class, +P = TP / beats assigned ', ...
  'the class. The de Chazal 2004 column is the reference PAPER''s figures, ', ...
  'not ours, printed for comparison (their VEB is class V, their SVEB is ', ...
  'class S).'];
  lines{end + 1} = '';
  lines{end + 1} = ['| Class | TP | ref | assigned | Se (%) | +P (%) | ', ...
  'de Chazal 2004 Se / +P (%) |'];
  lines{end + 1} = '|---|---:|---:|---:|---:|---:|---|';
  rowSum = sum(matched, 2);
  colSum = sum(matched, 1);
  reference = {'N', '86.9 / 99.2'; 'S', '75.9 / 38.5'; 'V', '77.7 / 81.9'; ...
  'F', '(not tabulated)'};
  for index = 1:4
    c = index;
    tpc = matched(c, c);
    se = ecgLabClassRatio(tpc, rowSum(c));
    pp = ecgLabClassRatio(tpc, colSum(c));
    lines{end + 1} = sprintf('| %s | %d | %d | %d | %.1f | %.1f | %s |', ...
    classes(c), tpc, rowSum(c), colSum(c), 100 * se, 100 * pp, ...
    reference{index, 2});
  end
  lines{end + 1} = '';
  lines{end + 1} = sprintf(['Overall classification accuracy on the ', ...
  'matched beats: %.1f percent (de Chazal 2004: 85.9 percent). Matched ', ...
  'beats: %d.'], 100 * accuracy, total);
  %===========================================================================
  % The uniform-prior variant, ecglab.classify('Prior','uniform'). The prior is
  % a decision-time choice that does not refit the model; the equal prior lifts
  % the rare classes. Same detected beats, so only the matched block is rescored.
  matchedUniform = pooledUniform(1:5, 1:5);
  totalUniform = sum(matchedUniform(:));
  accuracyUniform = 0;
  if totalUniform > 0
    accuracyUniform = sum(diag(matchedUniform)) / totalUniform;
  end
  rowSumU = sum(matchedUniform, 2);
  colSumU = sum(matchedUniform, 1);
  lines{end + 1} = '';
  lines{end + 1} = '## Per-class with the uniform prior';
  lines{end + 1} = '';
  lines{end + 1} = ['ecglab.classify(..., ''Prior'', ''uniform'') on the same ', ...
  'detected beats. The equal prior lifts the minority-class sensitivity the ', ...
  'frequency prior suppresses, at the cost of overall accuracy; the choice ', ...
  'belongs to the caller and the purpose (finding the rare beats, or the ', ...
  'best overall accuracy). The empirical prior above is the default and the ', ...
  'headline of this table.'];
  lines{end + 1} = '';
  lines{end + 1} = ['| Class | TP | ref | assigned | Se (%) | +P (%) | ', ...
  'empirical Se / +P (%) |'];
  lines{end + 1} = '|---|---:|---:|---:|---:|---:|---|';
  for index = 1:4
    c = index;
    tpc = matchedUniform(c, c);
    se = ecgLabClassRatio(tpc, rowSumU(c));
    pp = ecgLabClassRatio(tpc, colSumU(c));
    seE = ecgLabClassRatio(matched(c, c), sum(matched(c, :)));
    ppE = ecgLabClassRatio(matched(c, c), sum(matched(:, c)));
    lines{end + 1} = sprintf('| %s | %d | %d | %d | %.1f | %.1f | %.1f / %.1f |', ...
    classes(c), tpc, rowSumU(c), colSumU(c), 100 * se, 100 * pp, ...
    100 * seE, 100 * ppE);
  end
  lines{end + 1} = '';
  lines{end + 1} = sprintf(['Overall accuracy with the uniform prior: %.1f ', ...
  'percent (empirical: %.1f percent). The uniform prior trades overall ', ...
  'accuracy for minority-class sensitivity.'], 100 * accuracyUniform, ...
  100 * accuracy);
  %===========================================================================
  lines{end + 1} = '';
  lines{end + 1} = '## Detector contribution';
  lines{end + 1} = '';
  detSe = ecgLabClassRatio(tp, tp + fn);
  detPpv = ecgLabClassRatio(tp, tp + fp);
  lines{end + 1} = sprintf(['Over the DS2 records the detector (%s) paired ', ...
  '%d beats, missed %d and added %d: gross sensitivity %.2f percent, ', ...
  'positive predictivity %.2f percent. The missed beats are the O column ', ...
  'of the matrix, the extras its X row; they are the detector''s error, ', ...
  'kept apart from the classifier''s.'], detector, tp, fn, fp, ...
  100 * detSe, 100 * detPpv);
  lines{end + 1} = '';
  lines{end + 1} = ['Research software, not a medical device. ecglab is ', ...
  'for research and education. It is not a medical device and must not be ', ...
  'used for clinical diagnosis, patient monitoring, treatment decisions, ', ...
  'or any medical purpose.'];
end
%=============================================================================
function value = ecgLabClassRatio(numerator, denominator)
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
