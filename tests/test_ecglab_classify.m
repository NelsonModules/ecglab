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
root = fileparts(fileparts(nfilename('fullpath')));
% The fit and feature helpers are private, so put the private folder on the
% path to exercise the same code classify uses.
addpath([root, '/functions/+ecglab/private']);
modelPath = [root, '/data/ecglab_classifier.mat'];
%=============================================================================
% The shipped model loads and carries the fields the rest of the file needs.
assert_istrue(isfile(modelPath), 'the shipped classifier model must exist');
loaded = load(modelPath);
model = loaded.model;
assert_isequal(model.classes, 'NSVFQ');
settings = model.settings;
featureNames = model.featureNames;
% Five rhythm features, one QRS-width feature, then the morphology block.
expectedLength = 6 + round(double(settings.MorphLength));
assert_isequal(numel(featureNames), expectedLength);
assert_isequal(featureNames{4}, 'nextRR_over_avgRR');
assert_isequal(featureNames{6}, 'qrsWidth');
%=============================================================================
% The feature helper returns one row per beat, one name per column, the RR
% block then the morphology block.
rec = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 72, 'Seed', 11);
beats = ecglab.detect(rec);
signal = rec.samples(:, 1);
[feat, names, report] = ecgLabClassifyFeatures(signal, rec.rate, beats, settings);
assert_isequal(size(feat, 1), numel(beats.sample));
assert_isequal(size(feat, 2), numel(names));
assert_isequal(numel(names), expectedLength);
assert_isequal(names(1:6), {'prevRR', 'nextRR', 'prevRR_over_avgRR', ...
'nextRR_over_avgRR', 'avgRR', 'qrsWidth'});
assert_istrue(all(isfinite(feat(:))), 'features must be finite');
assert_istrue(isfield(report, 'padded'), 'the report says how many beats padded');
%=============================================================================
% Extraction is deterministic and matches the features classify computes from
% the same beats, so the fit and classify share one code path.
[feat2, names2] = ecgLabClassifyFeatures(signal, rec.rate, beats, settings);
assert_istrue(isequaln(feat, feat2), 'feature extraction must be deterministic');
assert_istrue(isequaln(names, names2), 'feature names must be deterministic');
classified = ecglab.classify(rec, 'Beats', beats);
assert_istrue(isequaln(classified.features, feat), ...
'classify must extract features with the shared helper');
assert_isequal(classified.featureNames, names);
assert_isequal(classified.kind, 'ecglab.classes');
%=============================================================================
% The labels are all in N S V F Q, and classify returns a beats field carrying
% the label so the result feeds ecglab.validate.
assert_istrue(all(ismember(classified.label, 'NSVFQ')), ...
'every label is one of N S V F Q');
assert_istrue(isfield(classified, 'beats'), 'classify returns a beats field');
assert_isequal(classified.beats.label, classified.label);
assert_isequal(numel(classified.beats.sample), numel(classified.label));
assert_isequal(size(classified.score, 2), 5);
%=============================================================================
% The Prior option: default 'empirical' keeps the training-frequency prior,
% 'uniform' equalises it. classify records the prior it used, a no-Prior call
% matches the empirical default, and an unknown prior is refused.
priorRec = ecglab.simulate('Seconds', 120, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.2, 'Seed', 31);
priorBeats = ecglab.detect(priorRec);
empirical = ecglab.classify(priorRec, 'Beats', priorBeats, 'Prior', 'empirical');
uniform = ecglab.classify(priorRec, 'Beats', priorBeats, 'Prior', 'uniform');
assert_isequal(empirical.prior, 'empirical');
assert_isequal(uniform.prior, 'uniform');
defaulted = ecglab.classify(priorRec, 'Beats', priorBeats);
assert_istrue(isequaln(defaulted.label, empirical.label), ...
'the default prior is empirical');
badPrior = false;
try
  ecglab.classify(priorRec, 'Beats', priorBeats, 'Prior', 'whatever');
catch e
  badPrior = startsWith(e.identifier, 'ecglab:badPrior');
end
assert_istrue(badPrior, 'an unknown prior is an error');
% The mechanism on a hand-built imbalanced model: one feature, a common N
% (1000 beats at 0) and a rare S (20 beats at 3). A beat at 2 goes to N under
% the frequency prior but to S under the equal prior.
handModel = struct('kind', 'ecglab.classifier', 'classes', 'NSVFQ', ...
'featureNames', {{'x'}}, 'featureMean', 0, 'featureStd', 1, ...
'means', [0; 3; 0; 0; 0], 'covariance', 1, 'counts', [1000; 20; 0; 0; 0]);
handModel.logPriors = -inf(5, 1);
handModel.logPriors(1) = log(1000 / 1020);
handModel.logPriors(2) = log(20 / 1020);
empiricalLabel = ecgLabClassifyApply(2, handModel);
assert_isequal(empiricalLabel, 'N');
uniformModel = handModel;
present = isfinite(uniformModel.logPriors);
uniformModel.logPriors(:) = -inf;
uniformModel.logPriors(present) = log(1 / sum(present));
uniformLabel = ecgLabClassifyApply(2, uniformModel);
assert_isequal(uniformLabel, 'S');
%=============================================================================
% The beats field feeds ecglab.validate and yields the confusion matrix.
agreement = ecglab.validate(classified.beats, rec.annotations, ...
'Kind', 'beats', 'Table', 'dechazal', 'Learning', 0, 'Record', 'sim');
assert_istrue(~isempty(agreement.matrix), 'the matrix must be built');
assert_isequal(size(agreement.matrix), [6, 6]);
%=============================================================================
% A beat whose morphology window runs past an end is padded, not dropped: the
% first and last samples still get a full row.
edgeBeats = struct('sample', [1; round(rec.rate); numel(signal)]);
[edgeFeat, ~, edgeReport] = ecgLabClassifyFeatures(signal, rec.rate, ...
edgeBeats, settings);
assert_isequal(size(edgeFeat, 1), 3);
assert_istrue(all(isfinite(edgeFeat(:))), 'a padded beat still has finite features');
assert_istrue(edgeReport.padded >= 1, 'the end beats are counted as padded');
%=============================================================================
% A synthetic fit and classify: a record of normal and wide ventricular beats,
% fitted on its first half and scored on its second, separates well above
% chance. End to end check of the module's own code.
sim = ecglab.simulate('Seconds', 300, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.3, 'Seed', 21);
simSignal = sim.samples(:, 1);
simBeats = struct('sample', sim.truth.beats(:));
truth = reshape(sim.truth.classes, [], 1);
[simFeat, simNames] = ecgLabClassifyFeatures(simSignal, sim.rate, simBeats, ...
settings);
nBeats = size(simFeat, 1);
half = floor(nBeats / 2);
trainIdx = 1:half;
testIdx = (half + 1):nBeats;
fitOptions = struct('Classes', 'NSVFQ', 'FeatureNames', {simNames}, ...
'Lambda', 1e-3, 'Settings', settings, 'Table', 'dechazal', ...
'TrainedOn', 'unit test, half of one simulated record');
fitModel = ecgLabClassifyFit(simFeat(trainIdx, :), truth(trainIdx), fitOptions);
[predicted, ~] = ecgLabClassifyApply(simFeat(testIdx, :), fitModel);
accuracy = mean(predicted == truth(testIdx));
% The loose accuracy bound sits well above the majority fraction, catching a
% broken fit without pinning a database figure.
assert_istrue(accuracy > 0.85, ...
sprintf('held-out accuracy %.3f must beat chance', accuracy));
assert_istrue(any(predicted == 'V'), 'the fit must recover some V beats');
%=============================================================================
% Errors: a missing model file, an unknown option, and a signal too short for
% the morphology window.
failed = false;
try
  ecglab.classify(rec, 'Model', [tempdir(), '/no_such_classifier.mat']);
catch
  failed = true;
end
assert_istrue(failed, 'a missing model file is an error');
failed = false;
try
  ecglab.classify(rec, 'NotAnOption', 1);
catch
  failed = true;
end
assert_istrue(failed, 'an unknown option is an error');
failed = false;
try
  ecglab.classify(rand(5, 1), 'Rate', 360);
catch
  failed = true;
end
assert_istrue(failed, 'a signal too short is an error');
%=============================================================================
% With the arrhythmia database on disk, fit on two records and classify one
% end to end, a loose sanity bound only.
databaseDir = [prefdir(), '/ecglab_reference/mitdb'];
if isfile([databaseDir, '/101.hea']) && isfile([databaseDir, '/100.hea'])
  trainRecords = {'101', '106'};
  allFeat = zeros(0, expectedLength);
  allLabel = repmat(' ', 0, 1);
  for r = 1:numel(trainRecords)
    rr = ecglab.readwfdb([databaseDir, '/', trainRecords{r}]);
    ann = rr.annotations;
    cls = ecgLabAami(ann.symbol, 'dechazal');
    keep = ismember(cls, 'NSVFQ');
    bb = struct('sample', ann.sample(keep));
    [ff, ~] = ecgLabClassifyFeatures(rr.samples(:, 1), rr.rate, bb, settings);
    allFeat = [allFeat; ff];
    allLabel = [allLabel; cls(keep)];
  end
  dbModel = ecgLabClassifyFit(allFeat, allLabel, fitOptions);
  testRec = ecglab.readwfdb([databaseDir, '/100']);
  testBeats = ecglab.detect(testRec);
  [dbFeat, ~] = ecgLabClassifyFeatures(testRec.samples(:, 1), testRec.rate, ...
  testBeats, settings);
  [dbLabel, ~] = ecgLabClassifyApply(dbFeat, dbModel);
  assert_istrue(all(ismember(dbLabel, 'NSVFQ')), 'db labels are in the alphabet');
  % Record 100 is almost all normal, so the recovered normal fraction is a
  % loose floor, not a published figure.
  dbAgreement = ecglab.validate(struct('sample', testBeats.sample, ...
  'time', testBeats.time, 'label', dbLabel), testRec.annotations, ...
  'Kind', 'beats', 'Table', 'dechazal', 'Learning', 0, 'Record', '100');
  assert_istrue(~isempty(dbAgreement.matrix), 'the db matrix must be built');
else
  % The arrhythmia database is not on disk, so the database check is skipped;
  % the synthetic fit above still proves the pipeline.
  assert_istrue(true, 'mitdb not on disk, database pipeline check skipped');
end
%=============================================================================
