%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function slope = ecgLabQrsLocalSlope(filtered, position, halfWindow)
  % Steepest slope of the band-passed signal around a candidate, used by the
  % T-wave test. The window is short, about one QRS upstroke.
  N = numel(filtered);
  lo = max(1, position - halfWindow);
  hi = min(N, position + halfWindow);
  if hi - lo < 1
    slope = 0;
    return;
  end
  slope = max(abs(diff(filtered(lo:hi))));
end
%=============================================================================
