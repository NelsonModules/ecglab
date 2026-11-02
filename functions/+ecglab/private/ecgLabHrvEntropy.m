%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sampen, apen] = ecgLabHrvEntropy(x, m, r)
  % Sample entropy (Richman and Moorman 2000) and approximate entropy (Pincus
  % 1991): the regularity of the series. Both count how often length-m
  % templates stay close (within r times the standard deviation) and how often
  % that closeness survives one more sample; a more regular series scores
  % lower. Sample entropy ignores self-matches, so it does not bias toward
  % regularity the way approximate entropy does. The count is quadratic in the
  % series length: a loop over templates with a vectorised Chebyshev distance.
  x = x(:);
  n = numel(x);
  tolerance = r * std(x);
  if tolerance <= 0 || n < m + 2
    sampen = NaN;
    apen = NaN;
    return;
  end
  [bSum, bPhi] = ecgLabHrvEntropyCount(x, m, tolerance);
  [aSum, aPhi] = ecgLabHrvEntropyCount(x, m + 1, tolerance);
  %===========================================================================
  % Sample entropy is the negative log of the ratio of the length m+1 matches
  % to the length m matches, both counted without self-matches.
  if bSum > 0 && aSum > 0
    sampen = -log(aSum / bSum);
  else
    % No match at one length leaves the ratio undefined.
    sampen = NaN;
  end
  %===========================================================================
  % Approximate entropy is the difference of the two averaged log match
  % densities, counting each template against itself.
  apen = bPhi - aPhi;
end
%=============================================================================
function [matchSum, phi] = ecgLabHrvEntropyCount(x, m, tolerance)
  % Two counts over length-m templates. matchSum is the number of template
  % pairs within tolerance, excluding self-matches (sample entropy). phi is the
  % mean log match fraction including the self-match (approximate entropy).
  n = numel(x);
  count = n - m + 1;
  % The embedding: one row per template, one column per lag.
  embed = zeros(count, m);
  for j = 1:m
    embed(:, j) = x(j:j + count - 1);
  end
  matchSum = 0;
  phiAccumulator = 0;
  for i = 1:count
    distance = max(abs(embed - embed(i, :)), [], 2);
    within = distance <= tolerance;
    withSelf = sum(within);
    matchSum = matchSum + withSelf - 1;
    phiAccumulator = phiAccumulator + log(withSelf / count);
  end
  phi = phiAccumulator / count;
end
%=============================================================================
