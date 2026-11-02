%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function rr = ecgLabSimulateRr(hrmean, hrstd, n, sf)
  % Bimodal RR spectrum of McSharry et al. 2003: Gaussian peaks at 0.1 and
  % 0.25 Hz, width 0.01 Hz, low-to-high power ratio 0.5. The RR series is the
  % inverse FFT of sqrt(spectrum) with antisymmetric random phases (so it is
  % real), rescaled to the requested mean and SD.
  %
  % The HR spread in bpm becomes an RR spread by the delta method:
  % sigma_RR = 60 * sigma_HR / HR^2 at the mean.
  %
  % N is a power of two for the inverse FFT; SF is the spectrum's rate and only
  % sets the shape.
  flo = 0.1;
  fhi = 0.25;
  flostd = 0.01;
  fhistd = 0.01;
  ratio = 0.5;
  w1 = 2 * pi * flo;
  w2 = 2 * pi * fhi;
  c1 = 2 * pi * flostd;
  c2 = 2 * pi * fhistd;
  sigma1 = ratio;
  sigma2 = 1;
  rrmean = 60 / hrmean;
  rrstd = 60 * hrstd / (hrmean * hrmean);
  df = sf / n;
  w = (0:n - 1)' * 2 * pi * df;
  low = sigma1 * exp(-0.5 * ((w - w1) / c1) .^ 2) / sqrt(2 * pi * c1 ^ 2);
  high = sigma2 * exp(-0.5 * ((w - w2) / c2) .^ 2) / sqrt(2 * pi * c2 ^ 2);
  spectrum = low + high;
  % Mirror the positive half onto the negative frequencies so the result is
  % real.
  half = n / 2;
  mirrored = [spectrum(1:half); spectrum(half:-1:1)];
  amplitude = (sf / 2) * sqrt(mirrored);
  phases = 2 * pi * rand(half - 1, 1);
  phase = [0; phases; 0; -flipud(phases)];
  series = (1 / n) * real(ifft(amplitude .* exp(1i * phase)));
  spread = std(series);
  if spread > 0
    series = (series - mean(series)) / spread;
  end
  rr = rrmean + series * rrstd;
  % Floor the RR so a large spread cannot produce a zero or negative interval.
  rr = max(rr, 0.25 * rrmean);
end
%=============================================================================
