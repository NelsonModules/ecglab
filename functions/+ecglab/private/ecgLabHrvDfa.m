%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function alpha = ecgLabHrvDfa(x, boxes)
  % Detrended fluctuation analysis (Peng 1995). Integrate the series into a
  % profile; for each box size cut the profile into non-overlapping windows,
  % remove a straight line from each, and take the RMS of the residual as the
  % fluctuation. Alpha is the log-log slope of fluctuation against box size.
  % Windows of a box size are detrended together by one least-squares solve,
  % so the only loop is over box sizes.
  x = x(:);
  profile = cumsum(x - mean(x));
  n = numel(profile);
  boxes = boxes(:);
  boxes = boxes(boxes >= 4 & boxes <= floor(n / 2));
  if numel(boxes) < 2
    % Too short to see a slope over the requested range: a missing measurement.
    alpha = NaN;
    return;
  end
  fluctuation = zeros(numel(boxes), 1);
  for bi = 1:numel(boxes)
    boxSize = boxes(bi);
    windows = floor(n / boxSize);
    block = reshape(profile(1:windows * boxSize), boxSize, windows);
    % Straight-line design matrix; the backslash fits every window at once.
    design = [ones(boxSize, 1), (1:boxSize)'];
    coefficients = design \ block;
    residual = block - design * coefficients;
    fluctuation(bi) = sqrt(mean(residual(:) .^ 2));
  end
  valid = fluctuation > 0;
  if sum(valid) < 2
    alpha = NaN;
    return;
  end
  line = polyfit(log10(boxes(valid)), log10(fluctuation(valid)), 1);
  alpha = line(1);
end
%=============================================================================
