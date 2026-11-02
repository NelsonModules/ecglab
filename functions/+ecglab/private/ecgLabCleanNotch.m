%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function cleaned = ecgLabCleanNotch(signal, rate, freq, quality, harmonics)
  % Remove the mains line at FREQ with a second-order IIR notch, applied with
  % filtfilt for zero phase shift. With HARMONICS true the notch is repeated at
  % every multiple of FREQ below the Nyquist.
  signal = signal(:);
  nyquist = rate / 2;
  if harmonics
    lines = freq:freq:(nyquist - 1);
  else
    lines = freq;
  end
  cleaned = signal;
  for index = 1:numel(lines)
    [b, a] = ecgLabCleanNotchDesign(lines(index), rate, quality);
    cleaned = filtfilt(b, a, cleaned);
  end
end
%=============================================================================
function [b, a] = ecgLabCleanNotchDesign(freq, rate, quality)
  % Biquad coefficients for a band-reject notch. Zeros on the unit circle give
  % zero gain at FREQ; poles just inside keep the notch narrow. The width is
  % set by the quality factor Q = freq / bandwidth, via alpha.
  omega = 2 * pi * freq / rate;
  alpha = sin(omega) / (2 * quality);
  a0 = 1 + alpha;
  b = [1, -2 * cos(omega), 1] / a0;
  a = [1, -2 * cos(omega) / a0, (1 - alpha) / a0];
end
%=============================================================================
