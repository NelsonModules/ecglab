%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [ksqi, psqi, bassqi] = ecgLabQualitySpectral(segment, rate)
  % The three amplitude and spectral quality indices of one window
  % (Zhao and Zhang 2018). The mean is removed first to clear the DC bin.
  x = double(segment(:));
  x = x - mean(x);
  power = mean(x .^ 2);
  %===========================================================================
  % kSQI is the Pearson kurtosis (3 is Gaussian): a clean ECG is strongly
  % peaked by the QRS, noise is near 3, a flat window scores zero.
  if power <= 0
    ksqi = 0;
  else
    ksqi = mean(x .^ 4) / (power ^ 2);
  end
  %===========================================================================
  % Power spectral density by the periodogram: the squared magnitude of the
  % FFT, kept to the non-negative frequencies.
  n = numel(x);
  spectrum = abs(fft(x)) .^ 2;
  half = floor(n / 2) + 1;
  spectrum = spectrum(1:half);
  frequency = (0:half - 1)' * (rate / n);
  %===========================================================================
  % pSQI is the power share in the QRS band 5-15 Hz against the wider 5-40 Hz
  % band: high is a clean complex, low is broadband noise.
  qrsBand = sum(spectrum(frequency >= 5 & frequency <= 15));
  wideBand = sum(spectrum(frequency >= 5 & frequency <= 40));
  if wideBand <= 0
    psqi = 0;
  else
    psqi = qrsBand / wideBand;
  end
  %===========================================================================
  % basSQI is the power share above 1 Hz: baseline wander sits below 1 Hz, so
  % a trace free of wander scores near one.
  total = sum(spectrum);
  aboveBaseline = sum(spectrum(frequency > 1));
  if total <= 0
    bassqi = 0;
  else
    bassqi = aboveBaseline / total;
  end
end
%=============================================================================
