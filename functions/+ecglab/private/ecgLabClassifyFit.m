%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function model = ecgLabClassifyFit(features, labels, options)
  % Fit a linear discriminant classifier: one Gaussian per class sharing one
  % covariance. The model is a struct of numbers saved in a small .mat.
  % FEATURES is K by F, LABELS a K by 1 char in the class alphabet, OPTIONS
  % holds Classes, FeatureNames, Lambda (ridge fraction), Settings, Table and
  % TrainedOn.
  features = double(features);
  labels = reshape(char(labels), [], 1);
  classes = char(options.Classes);
  [K, F] = size(features);
  if numel(labels) ~= K
    error('ecglab:labelCount', 'There must be one label per feature row.');
  end
  if K < numel(classes) + 1
    error('ecglab:tooFewBeatsFitNeedsMoreBeats', 'The fit needs more beats than classes.');
  end
  %===========================================================================
  % Standardise features to zero mean and unit variance so every column weighs
  % the same under the ridge. The shift and scale are stored for the apply.
  featureMean = mean(features, 1);
  featureStd = std(features, 0, 1);
  featureStd(featureStd < eps) = 1;
  Z = (features - featureMean) ./ featureStd;
  %===========================================================================
  % Class means and pooled within-class scatter. A label outside the alphabet
  % is ignored; an empty class gets a zero mean and a log prior of -inf below.
  C = numel(classes);
  means = zeros(C, F);
  counts = zeros(C, 1);
  scatter = zeros(F, F);
  for index = 1:C
    mask = labels == classes(index);
    counts(index) = sum(mask);
    if counts(index) == 0
      continue;
    end
    Zc = Z(mask, :);
    mu = mean(Zc, 1);
    means(index, :) = mu;
    centred = Zc - mu;
    scatter = scatter + (centred' * centred);
  end
  present = counts > 0;
  total = sum(counts);
  % Pooled covariance: scatter over the degrees of freedom (unbiased pooling).
  pooled = scatter / max(1, total - sum(present));
  %===========================================================================
  % Add a ridge to the diagonal to keep the covariance invertible: a fraction
  % Lambda of the mean diagonal.
  lambdaCoef = double(options.Lambda);
  ridge = lambdaCoef * mean(diag(pooled));
  covariance = pooled + ridge * eye(F);
  %===========================================================================
  % Log priors from the class frequencies. An absent class is -inf, so it can
  % never be chosen.
  logPriors = -inf(C, 1);
  logPriors(present) = log(counts(present) / total);
  %===========================================================================
  model = struct();
  model.kind = 'ecglab.classifier';
  model.method = 'linear discriminant (pooled covariance, ridge, log priors)';
  model.classes = classes;
  model.featureNames = options.FeatureNames;
  model.featureMean = featureMean;
  model.featureStd = featureStd;
  model.means = means;
  model.covariance = covariance;
  model.logPriors = logPriors;
  model.counts = counts;
  model.lambda = lambdaCoef;
  model.ridge = ridge;
  model.settings = options.Settings;
  model.table = char(options.Table);
  model.trainedOn = char(options.TrainedOn);
end
%=============================================================================
