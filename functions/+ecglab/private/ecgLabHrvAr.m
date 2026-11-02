%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [psd, f] = ecgLabHrvAr(x, fs, order, method, nfft)
  % Autoregressive spectrum: fit an all-pole model of the given order, then
  % read its power spectral density in closed form. Gives a smooth spectrum
  % with sharp peaks on short records. Two fits are supported: Burg's lattice
  % recursion (default) and the Yule-Walker equations via Levinson-Durbin.
  x = x(:);
  switch method
    case 'burg'
      [a, e] = ecgLabHrvBurg(x, order);
    case 'yulewalker'
      [a, e] = ecgLabHrvYuleWalker(x, order);
    otherwise
      error('ecglab:badArMethod', 'ArMethod must be burg or yulewalker.');
  end
  %===========================================================================
  % One-sided PSD of the AR model: white-noise variance e over the squared
  % magnitude of polynomial A on the unit circle, doubled for the one-sided
  % convention. Total area equals the series variance, so band powers are ms^2.
  f = linspace(0, fs / 2, nfft)';
  denom = zeros(size(f));
  for j = 0:order
    denom = denom + a(j + 1) * exp(-1i * 2 * pi * f * j / fs);
  end
  psd = 2 * (e / fs) ./ abs(denom) .^ 2;
end
%=============================================================================
function [a, e] = ecgLabHrvBurg(x, order)
  % Burg's recursion. Each order's reflection coefficient minimises the sum of
  % forward and backward prediction error; polynomial and variance follow by
  % the Levinson update.
  n = numel(x);
  fwd = x;
  bwd = x;
  e = sum(x .^ 2) / n;
  a = [];
  for m = 1:order
    fm = fwd(2:end);
    bm = bwd(1:end - 1);
    k = -2 * sum(fm .* bm) / (sum(fm .^ 2) + sum(bm .^ 2));
    if m == 1
      a = k;
    else
      a = [a + k * flipud(a); k];
    end
    fwd = fm + k * bm;
    bwd = bm + k * fm;
    e = e * (1 - k ^ 2);
  end
  a = [1; a];
end
%=============================================================================
function [a, e] = ecgLabHrvYuleWalker(x, order)
  % Yule-Walker equations: the biased autocorrelation solved for the
  % coefficients by the Levinson-Durbin recursion, in order-squared time
  % without forming the Toeplitz matrix.
  n = numel(x);
  r = zeros(order + 1, 1);
  for k = 0:order
    r(k + 1) = sum(x(1:n - k) .* x(k + 1:n)) / n;
  end
  a = [];
  e = r(1);
  for m = 1:order
    if m == 1
      acc = r(2);
    else
      acc = r(m + 1) + sum(a .* r(m:-1:2));
    end
    k = -acc / e;
    if m == 1
      a = k;
    else
      a = [a + k * flipud(a); k];
    end
    e = e * (1 - k ^ 2);
  end
  a = [1; a];
end
%=============================================================================
