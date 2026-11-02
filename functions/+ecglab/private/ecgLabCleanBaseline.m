%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function cleaned = ecgLabCleanBaseline(signal, rate, method, cut)
  % Remove the baseline by the chosen method, returning the same length.
  % Dispatch by name; each method holds only its arithmetic.
  signal = signal(:);
  switch method
    case 'none'
      cleaned = signal;
    case 'highpass'
      cleaned = ecgLabCleanHighpass(signal, rate, cut);
    case 'median'
      cleaned = signal - ecgLabCleanMedian(signal, rate);
    case 'spline'
      cleaned = signal - ecgLabCleanSpline(signal, rate);
    otherwise
      % Guard against a method added to the switch but not to clean.m.
      error('ecglab:unknownBaseline', 'Unknown baseline method: %s.', method);
  end
end
%=============================================================================
function cleaned = ecgLabCleanHighpass(signal, rate, cut)
  % Zero-phase Butterworth high pass. filtfilt runs a second-order filter
  % forwards and backwards (fourth-order roll-off, no phase shift). The cut is
  % clamped just below the Nyquist.
  nyquist = rate / 2;
  cut = min(max(cut, 0), nyquist - eps);
  if cut <= 0
    cleaned = signal;
    return;
  end
  [b, a] = butter(2, cut / nyquist, 'high');
  cleaned = filtfilt(b, a, signal);
end
%=============================================================================
