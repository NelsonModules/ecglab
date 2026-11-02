%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function baseline = ecgLabCleanSpline(signal, rate)
  % Cubic spline through the isoelectric level before each QRS. ecglab.detect
  % finds the R peaks, the level is read about 90 ms before R (one knot per
  % beat), and a natural cubic spline is evaluated at every sample. This is the
  % only baseline method that runs a detector first.
  signal = signal(:);
  n = numel(signal);
  beats = ecglab.detect(signal, 'Rate', rate);
  r = beats.sample;
  % Isoelectric knot per beat, taken as the median of a short window. Beats too
  % close to an end are dropped; the ends are anchored below.
  offset = round(0.09 * rate);
  half = max(1, round(0.015 * rate));
  knot = r - offset;
  knot = knot(knot > half & knot < n - half);
  if numel(knot) < 2
    % Too few beats to span a baseline, so return zeros (no correction).
    baseline = zeros(n, 1);
    return;
  end
  window = (-half:half)' + knot(:)';
  level = median(signal(window), 1)';
  % Anchor the first and last sample to the nearest knot level so the spline
  % does not swing past the outer knots.
  knots = [1; knot(:); n];
  values = [level(1); level(:); level(end)];
  [knots, keep] = unique(knots);
  values = values(keep);
  baseline = ecgLabCleanCubic(knots, values, (1:n)');
end
%=============================================================================
function y = ecgLabCleanCubic(xk, yk, xq)
  % Natural cubic spline solved without interp1 'spline'. The second
  % derivatives M come from a tridiagonal system solved by the Thomas
  % algorithm (a loop over knots), then the piecewise cubic is evaluated on the
  % whole query vector at once. The natural end condition sets zero curvature
  % at the outer knots.
  xk = xk(:);
  yk = yk(:);
  m = numel(xk);
  h = diff(xk);
  lower = zeros(m, 1);
  diagonal = ones(m, 1);
  upper = zeros(m, 1);
  rhs = zeros(m, 1);
  for i = 2:m - 1
    lower(i) = h(i - 1);
    diagonal(i) = 2 * (h(i - 1) + h(i));
    upper(i) = h(i);
    rhs(i) = 6 * ((yk(i + 1) - yk(i)) / h(i) - (yk(i) - yk(i - 1)) / h(i - 1));
  end
  cp = zeros(m, 1);
  dp = zeros(m, 1);
  cp(1) = upper(1) / diagonal(1);
  dp(1) = rhs(1) / diagonal(1);
  for i = 2:m
    denom = diagonal(i) - lower(i) * cp(i - 1);
    cp(i) = upper(i) / denom;
    dp(i) = (rhs(i) - lower(i) * dp(i - 1)) / denom;
  end
  M = zeros(m, 1);
  M(m) = dp(m);
  for i = m - 1:-1:1
    M(i) = dp(i) - cp(i) * M(i + 1);
  end
  % Interval index of each query sample, in O(n): knots are integer sample
  % positions, so a cumulative count of knots at or before each sample gives
  % its interval, with no search.
  xq = xq(:);
  nq = numel(xq);
  marker = zeros(nq, 1);
  kk = min(max(round(xk), 1), nq);
  marker(kk) = 1;
  seg = cumsum(marker);
  seg = min(max(seg, 1), m - 1);
  hi = h(seg);
  left = (xk(seg + 1) - xq) ./ hi;
  right = (xq - xk(seg)) ./ hi;
  y = left .* yk(seg) + right .* yk(seg + 1) + ...
  ((left .^ 3 - left) .* M(seg) + (right .^ 3 - right) .* M(seg + 1)) .* ...
  (hi .^ 2) / 6;
end
%=============================================================================
