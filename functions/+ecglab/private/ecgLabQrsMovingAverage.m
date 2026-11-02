%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function y = ecgLabQrsMovingAverage(x, width)
  % Pan-Tompkins moving-window integration: a centered average over a cumulative
  % sum, each window divided by its true sample count to keep edges correct.
  width = max(1, round(width));
  x = x(:);
  N = numel(x);
  cumulative = [0; cumsum(x)];
  half = floor(width / 2);
  lo = (1:N)' - half;
  hi = lo + width - 1;
  lo = max(lo, 1);
  hi = min(hi, N);
  y = (cumulative(hi + 1) - cumulative(lo)) ./ (hi - lo + 1);
end
%=============================================================================
