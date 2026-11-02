%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% CLASSES = ECGLAB.CLASSIFY(X) labels every beat of X N, S, V, F or Q.
% CLASSES = ECGLAB.CLASSIFY(X, 'Name', value, ...) sets the lead, the beats
% and the model.
%
%   X is an ecglab.recording (beats found with ecglab.detect unless 'Beats' is
%   given) or a plain signal vector with 'Rate' in hertz and 'Beats' given.
%   Each beat is reduced to a feature vector of its RR rhythm and shape (see
%   ecgLabClassifyFeatures), and a linear discriminant fitted on DS1 of the
%   arrhythmia database assigns one of the five ANSI/AAMI classes by the
%   de Chazal table: N (normal and bundle branch block), S (supraventricular
%   ectopic), V (ventricular ectopic), F (fusion) and Q (paced or
%   unclassifiable).
%
%   The model is trained and applied on the 'dechazal' table; 'Table' is kept
%   in the result for the record, not to retrain.
%
%   CLASSES is the classes struct of the data model: kind 'ecglab.classes',
%   label (K x 1 char in N S V F Q), features (K x F), featureNames (1 x F),
%   score (K x 5, discriminant score per class in order N S V F Q), method,
%   trainedOn (model provenance and the leave-DS2-out protocol), settings (the
%   extraction windows) and beats. The beats field is an ecglab.beats struct
%   (sample, time, rr, label) so the result goes straight to ecglab.validate:
%
%     classes = ecglab.classify(recording);
%     agreement = ecglab.validate(classes.beats, recording.annotations, ...
%       'Kind', 'beats', 'Table', 'dechazal');
%
%   Options (name and value, matched without regard to case):
%     'Beats'  the beats to classify, an ecglab.beats struct or a vector of
%              1-based sample indices; by default ecglab.detect finds them on
%              a recording, and for a plain vector they must be given.
%     'Lead'   the lead to read, a name or a column index; the default is the
%              first of MLII, II, I, V5, or the first lead, the detector's own.
%     'Rate'   the sampling rate in hertz, required when X is a plain vector.
%     'Model'  a path to a model .mat; the default is the shipped model under
%              data/ecglab_classifier.mat.
%     'Table'  the class table, kept in the result; the model is trained on
%              'dechazal' whatever this says.
%     'Prior'  the class prior the decision uses: 'empirical' (default) keeps
%              the training-frequency prior, best for overall accuracy;
%              'uniform' equalises it, lifting the rare classes. The choice only
%              reweights the class scores and is recorded in .prior.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 60, 'Ectopic', 0.1, 'Seed', 1);
%     classes = ecglab.classify(recording);
%     sum(classes.label == 'V')
%
%   See also ecglab.detect, ecglab.validate, ecglab.simulate.
function classes = classify(X, varargin)
  nargoutchk(0, 1);
  here = fileparts(fileparts(fileparts(nfilename('fullpath'))));
  defaults = struct('Beats', [], 'Lead', [], 'Rate', [], ...
  'Model', [here, '/data/ecglab_classifier.mat'], 'Table', 'dechazal', ...
  'Prior', 'empirical');
  options = ecgLabOptions(defaults, varargin);
  model = ecgLabClassifyLoad(options.Model);
  % The class prior is a decision-time choice: it changes only the log-prior
  % term added to each class score, not the model's means or covariance.
  prior = ecgLabClassifyPrior(options.Prior);
  model = ecgLabClassifyApplyPrior(model, prior);
  %===========================================================================
  % The lead and the beats. For a recording with no beats given, detect first
  % and read features from the lead the detector used. A plain vector must be
  % given its beats; it is not detected here.
  if isempty(options.Beats)
    if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
      beats = ecglab.detect(X, 'Lead', options.Lead);
      [signal, rate, leadName] = ecgLabClassifySignal(X, beats.lead, ...
      options.Rate);
    else
      error('ecglab:needBeats', 'A plain signal vector needs its beats, given as Beats.');
    end
  else
    [signal, rate, leadName] = ecgLabClassifySignal(X, options.Lead, ...
    options.Rate);
    beats = ecgLabClassifyBeats(options.Beats, rate);
  end
  %===========================================================================
  % The signal must hold one beat's morphology window, else every feature would
  % be padding.
  windowSamples = round((model.settings.Before + model.settings.After) * rate);
  if numel(signal) < windowSamples
    error('ecglab:tooShortSignalShorterThanMorphology', 'The signal is shorter than the morphology window of one beat.');
  end
  %===========================================================================
  [features, featureNames] = ecgLabClassifyFeatures(signal, rate, beats, ...
  model.settings);
  [label, score] = ecgLabClassifyApply(features, model);
  %===========================================================================
  classes = struct();
  classes.kind = 'ecglab.classes';
  classes.label = label;
  classes.features = features;
  classes.featureNames = featureNames;
  classes.score = score;
  classes.scoreClasses = model.classes;
  classes.method = model.method;
  classes.trainedOn = model.trainedOn;
  classes.table = char(options.Table);
  classes.prior = prior;
  classes.lead = leadName;
  classes.settings = model.settings;
  % Carry the label onto sample, time and rr so the result is a valid test side
  % for ecglab.validate.
  classes.beats = struct('kind', 'ecglab.beats', 'sample', beats.sample, ...
  'time', beats.time, 'rr', beats.rr, 'label', label, 'lead', leadName);
end
%=============================================================================
function prior = ecgLabClassifyPrior(value)
  % Validate the prior name: training-frequency or equal.
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badPrior', 'The Prior must be ''empirical'' or ''uniform''.');
  end
  prior = lower(char(value));
  if ~any(strcmp(prior, {'empirical', 'uniform'}))
    error('ecglab:badPrior', 'The Prior must be ''empirical'' or ''uniform''.');
  end
end
%=============================================================================
function model = ecgLabClassifyApplyPrior(model, prior)
  % 'empirical' keeps the fitted log priors. 'uniform' equalises them over the
  % classes present (a class with no training beat keeps its -inf prior, so it
  % is never chosen), making the decision the Mahalanobis-nearest class mean.
  if strcmp(prior, 'uniform')
    present = isfinite(model.logPriors);
    model.logPriors(:) = -inf;
    model.logPriors(present) = log(1 / sum(present));
  end
end
%=============================================================================
function model = ecgLabClassifyLoad(modelPath)
  modelPath = char(modelPath);
  if ~isfile(modelPath)
    error('ecglab:missingModel', 'The classifier model %s is not on disk.', modelPath);
  end
  loaded = load(modelPath);
  if ~isfield(loaded, 'model') || ~isstruct(loaded.model)
    error('ecglab:badModelFileSDoesNot', 'The file %s does not hold a classifier model.', modelPath);
  end
  model = loaded.model;
  required = {'classes', 'featureNames', 'featureMean', 'featureStd', ...
  'means', 'covariance', 'logPriors', 'settings'};
  for index = 1:numel(required)
    if ~isfield(model, required{index})
      error('ecglab:badModelModelMissingFieldS', 'The model is missing the field %s.', required{index});
    end
  end
end
%=============================================================================
function beats = ecgLabClassifyBeats(given, rate)
  % Normalise given beats into sample, time and rr, whether they arrived as a
  % beats struct or a vector of sample indices.
  if isstruct(given)
    if ~isfield(given, 'sample')
      error('ecglab:noSampleBeatsStructCarrySample', 'The beats struct must carry a sample field.');
    end
    sample = round(double(given.sample(:)));
    if isfield(given, 'time') && numel(given.time) == numel(sample)
      time = double(given.time(:));
    else
      time = (sample - 1) / rate;
    end
    if isfield(given, 'rr') && numel(given.rr) == numel(sample)
      rr = double(given.rr(:));
    else
      rr = [NaN; diff(time)];
    end
  elseif isnumeric(given) && isvector(given)
    sample = round(double(given(:)));
    time = (sample - 1) / rate;
    rr = [NaN; diff(time)];
  else
    error('ecglab:badBeatsBeatsEcglabBeatsStruct', 'Beats must be an ecglab.beats struct or a vector of sample indices.');
  end
  [sample, order] = sort(sample);
  time = time(order);
  if numel(rr) == numel(order)
    rr = rr(order);
  else
    rr = [NaN; diff(time)];
  end
  beats = struct('kind', 'ecglab.beats', 'sample', sample, 'time', time, ...
  'rr', rr);
end
%=============================================================================
