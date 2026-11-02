%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function freq = ecgLabCleanMainsFreq(samples, rate, mains, threshold)
  % Pick the mains frequency to remove, 0 for none, once for the whole record.
  % A number means that frequency; false means none; 'auto' detects it from
  % the spectrum.
  if islogical(mains) || isnumeric(mains)
    if islogical(mains)
      if mains
        error('ecglab:badMainsMainsAuto5060', 'Mains must be auto, 50, 60 or false.');
      end
      freq = 0;
      return;
    end
    freq = double(mains);
    if ~isscalar(freq) || ~isfinite(freq) || freq <= 0 || freq >= rate / 2
      error('ecglab:badMainsMainsFrequencyPositiveNumber', 'A mains frequency must be a positive number below the Nyquist.');
    end
    return;
  end
  if ~ischar(mains) && ~isStringScalar(mains)
    error('ecglab:badMainsMainsAuto5060', 'Mains must be auto, 50, 60 or false.');
  end
  if ~strcmpi(char(mains), 'auto')
    error('ecglab:badMainsMainsAuto5060', 'Mains must be auto, 50, 60 or false.');
  end
  freq = ecgLabCleanMainsAuto(samples, rate, threshold);
end
%=============================================================================
function freq = ecgLabCleanMainsAuto(samples, rate, threshold)
  % Detect whether 50 or 60 Hz is present. Average the power spectrum over the
  % leads, then compare the line against the strongest neighbour 1 to 3 Hz
  % away: a real hum stands well above it, an ECG harmonic does not.
  samples = double(samples);
  n = size(samples, 1);
  spectrum = zeros(floor(n / 2) + 1, 1);
  for col = 1:size(samples, 2)
    x = samples(:, col) - mean(samples(:, col));
    X = fft(x);
    spectrum = spectrum + abs(X(1:floor(n / 2) + 1)) .^ 2;
  end
  half = floor(n / 2);
  frequencies = (0:half)' * (rate / n);
  freq = 0;
  best = threshold;
  for candidate = [50, 60]
    if candidate >= rate / 2 - 5
      % No room to measure the line or its neighbours below the Nyquist.
      continue;
    end
    atLine = max(spectrum(abs(frequencies - candidate) <= 0.5));
    near = spectrum((frequencies >= candidate - 3 & frequencies <= ...
    candidate - 1) | (frequencies >= candidate + 1 & frequencies <= ...
    candidate + 3));
    ratio = atLine / (max(near) + eps);
    if ratio > best
      best = ratio;
      freq = candidate;
    end
  end
end
%=============================================================================
