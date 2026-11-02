%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function filtered = ecgLabQrsBandpass(signal, rate, low, high, order)
  % Zero-phase Butterworth band pass (filtfilt), so no fiducial is shifted by
  % group delay. The upper edge is clamped just below Nyquist.
  nyquist = rate / 2;
  high = min(high, nyquist - 1);
  if low >= high
    % Rate too low for the band: return the signal unfiltered.
    filtered = signal(:);
    return;
  end
  [b, a] = butter(order, [low, high] / nyquist);
  filtered = filtfilt(b, a, signal(:));
end
%=============================================================================
