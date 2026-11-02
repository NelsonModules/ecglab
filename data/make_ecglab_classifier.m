%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_CLASSIFIER() fits the linear discriminant of ecglab.classify on
% the DS1 training set of the MIT-BIH Arrhythmia Database and writes the
% shipped model to data/ecglab_classifier.mat.
%
% The inter-patient split is de Chazal, O'Dwyer and Reilly (2004): DS1 trains,
% DS2 tests. The four paced records (102, 104, 107, 217) are in neither set.
% Each beat's class is the AAMI class by the 'dechazal' table.
%
% Training features are aligned to the true .atr beat locations, not a
% detector's, so the model is not taught a detector's placement error. At test
% time the classifier meets detected beats.
%
% MAKE_ECGLAB_CLASSIFIER(RECORDS) fits on only the named records.
function make_ecglab_classifier(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  % The feature extraction and fit are private to the package; put the private
  % folder on the path so this shares the exact code ecglab.classify runs.
  addpath([moduleRoot, '/functions/+ecglab/private']);
  databaseDir = [prefdir(), '/ecglab_reference/mitdb'];
  %===========================================================================
  % The de Chazal DS1 training records. Verified against docs/survey.md 5.7.
  ds1 = {'101', '106', '108', '109', '112', '114', '115', '116', '118', ...
  '119', '122', '124', '201', '203', '205', '207', '208', '209', '215', ...
  '220', '223', '230'};
  if nargin < 1 || isempty(records)
    records = ds1;
  end
  if ischar(records)
    records = {records};
  end
  %===========================================================================
  % The extraction windows, fixed from reasoning, not tuned on the test set:
  % 0.2 s before and 0.4 s after the R span the QRS and T; 48 morphology points;
  % 10 context beats each side. The ridge is 1e-3 of the mean feature variance.
  settings = struct('Before', 0.2, 'After', 0.4, 'MorphLength', 48, ...
  'Context', 10);
  lambda = 1e-3;
  classes = 'NSVFQ';
  %===========================================================================
  % Accumulate features and labels over DS1. Records are read one at a time, so
  % memory holds the features, not whole recordings.
  allFeatures = [];
  allLabels = repmat(' ', 0, 1);
  perRecord = {};
  featureNames = {};
  for index = 1:numel(records)
    name = records{index};
    recording = ecglab.readwfdb([databaseDir, '/', name]);
    annotations = recording.annotations;
    % The AAMI class of every annotation; only the five beat classes N S V F Q
    % are kept, non-beat marks dropped. DS1 has no paced record, so Q is the
    % rare unclassifiable beat.
    beatClass = ecgLabAami(annotations.symbol, 'dechazal');
    keep = ismember(beatClass, classes);
    beats = struct('sample', annotations.sample(keep));
    [features, featureNames] = ecgLabClassifyFeatures(recording.samples(:, 1), ...
    recording.rate, beats, settings);
    labels = beatClass(keep);
    allFeatures = [allFeatures; features];
    allLabels = [allLabels; labels];
    perRecord{end + 1} = struct('record', name, 'beats', sum(keep));
    fprintf('%s: %d beats kept.\n', name, sum(keep));
  end
  if isempty(allFeatures)
    error('ecglab:noTrainingData', ...
    'No beats were accumulated; is the database on disk?');
  end
  %===========================================================================
  provenance = ecgLabClassifierProvenance(records, settings, lambda);
  fitOptions = struct('Classes', classes, 'FeatureNames', {featureNames}, ...
  'Lambda', lambda, 'Settings', settings, 'Table', 'dechazal', ...
  'TrainedOn', provenance);
  model = ecgLabClassifyFit(allFeatures, allLabels, fitOptions);
  model.trainRecords = records;
  model.perRecord = perRecord;
  %===========================================================================
  outPath = [here, '/ecglab_classifier.mat'];
  save(outPath, 'model');
  info = dir(outPath);
  fprintf('Wrote %s (%d beats, %d bytes).\n', outPath, ...
  size(allFeatures, 1), info.bytes);
  for index = 1:numel(classes)
    fprintf('  class %s: %d beats.\n', classes(index), model.counts(index));
  end
end
%=============================================================================
function text = ecgLabClassifierProvenance(records, settings, lambda)
  % The note the model carries into every classes struct, so a result records
  % how it was made.
  text = sprintf(['Linear discriminant fitted on DS1 of the MIT-BIH ', ...
  'Arrhythmia Database (%d records) with the de Chazal 2004 inter-patient ', ...
  'split, leave-DS2-out: no beat of a DS2 patient is in the training. ', ...
  'Reference .atr beat locations, dechazal class table, features [%.2f s ', ...
  'before, %.2f s after, %d morphology points, %d context beats], ridge ', ...
  '%.0e of the mean feature variance. Built by ', ...
  'data/make_ecglab_classifier.m.'], numel(records), settings.Before, ...
  settings.After, settings.MorphLength, settings.Context, lambda);
end
%=============================================================================
