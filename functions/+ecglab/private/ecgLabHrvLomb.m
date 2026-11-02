%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [psd, f] = ecgLabHrvLomb(t, y, fmax)
  % Lomb-Scargle periodogram: the spectrum of an unevenly sampled series, so
  % the NN series needs no resampling. For each trial frequency a phase offset
  % tau makes the sine and cosine fits orthogonal, and the periodogram is the
  % least-squares power at that frequency (Lomb 1976, Scargle 1982). The loop
  % is over frequencies, each a vector operation over the beats.
  t = t(:);
  y = y(:);
  y = y - mean(y);
  span = t(end) - t(1);
  if span <= 0
    psd = [];
    f = [];
    return;
  end
  % Four times oversampled in frequency for a smooth periodogram, capped so a
  % long record does not ask for tens of thousands of frequencies.
  df = 1 / (4 * span);
  nf = min(max(round(fmax / df), 256), 2000);
  f = linspace(fmax / nf, fmax, nf)';
  psd = zeros(nf, 1);
  for i = 1:nf
    w = 2 * pi * f(i);
    tau = atan2(sum(sin(2 * w * t)), sum(cos(2 * w * t))) / (2 * w);
    ct = cos(w * (t - tau));
    st = sin(w * (t - tau));
    cc = sum(ct .^ 2);
    ss = sum(st .^ 2);
    pc = 0;
    if cc > 0
      pc = (sum(y .* ct)) ^ 2 / cc;
    end
    ps = 0;
    if ss > 0
      ps = (sum(y .* st)) ^ 2 / ss;
    end
    psd(i) = 0.5 * (pc + ps);
  end
  %===========================================================================
  % Scale the periodogram so its integral equals the series variance, matching
  % Welch and the AR model; this only puts the powers in ms^2.
  area = trapz(f, psd);
  if area > 0
    psd = psd * var(y) / area;
  end
end
%=============================================================================
