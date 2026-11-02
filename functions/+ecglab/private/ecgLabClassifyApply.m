%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [label, score] = ecgLabClassifyApply(features, model)
  % Apply the stored linear discriminant to the whole batch of beats at once.
  % For one class the score is
  %
  %   delta_c(x) = x S^-1 mu_c' - 0.5 mu_c S^-1 mu_c' + log prior_c,
  %
  % with shared covariance S; the beat takes the class of the largest score.
  features = double(features);
  [K, F] = size(features);
  classes = model.classes;
  C = numel(classes);
  if F ~= numel(model.featureNames)
    error('ecglab:featureCount', 'The features have %d columns but the model expects %d.', F, numel(model.featureNames));
  end
  %===========================================================================
  % Standardise with the shift and scale the fit stored, so the beat meets the
  % discriminant on the same footing the training beats did.
  Z = (features - model.featureMean) ./ model.featureStd;
  %===========================================================================
  % The inverse of the pooled covariance, once for the batch. Invertible because
  % the fit added a ridge; a residual singularity is let through, not hidden.
  precision = inv(model.covariance);
  score = -inf(K, C);
  logPriors = model.logPriors;
  for index = 1:C
    if ~isfinite(logPriors(index))
      % A class with no training beat keeps its minus-infinity score and is
      % never the largest, so it is never chosen.
      continue;
    end
    mu = model.means(index, :);
    weight = precision * mu';
    bias = -0.5 * (mu * weight) + logPriors(index);
    score(:, index) = Z * weight + bias;
  end
  %===========================================================================
  % The chosen class per beat is the column of the largest score.
  [~, best] = max(score, [], 2);
  label = reshape(classes(best), [], 1);
end
%=============================================================================
