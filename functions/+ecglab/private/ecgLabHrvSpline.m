%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function v = ecgLabHrvSpline(x, y, q)
  % Natural cubic spline of y over knots x, evaluated at q. The core's interp1
  % 'spline' is superlinear in the knot count and too slow for a long record,
  % so the spline is built from its tridiagonal system: the Thomas algorithm
  % finds the second derivatives in two sweeps, then the pieces are evaluated
  % on the whole query grid at once.
  x = x(:);
  y = y(:);
  q = q(:);
  n = numel(x);
  if n < 3
    % Fewer than three knots: a cubic is not defined, fall back to a line.
    v = interp1(x, y, q, 'linear');
    return;
  end
  h = diff(x);
  %===========================================================================
  % Tridiagonal system for the interior second derivatives, with natural end
  % conditions (zero at both ends). It has n - 2 unknowns; the diagonals and
  % right-hand side are built as vectors, then solved in place.
  lower = h(1:end - 1);
  upper = h(2:end);
  diagonal = 2 * (lower + upper);
  rhs = 6 * (diff(y(2:end)) ./ upper - diff(y(1:end - 1)) ./ lower);
  m = numel(diagonal);
  % Forward elimination: carry a modified diagonal and right-hand side.
  cc = zeros(m, 1);
  dd = zeros(m, 1);
  cc(1) = upper(1) / diagonal(1);
  dd(1) = rhs(1) / diagonal(1);
  for i = 2:m
    pivot = diagonal(i) - lower(i) * cc(i - 1);
    cc(i) = upper(i) / pivot;
    dd(i) = (rhs(i) - lower(i) * dd(i - 1)) / pivot;
  end
  % Back substitution gives the interior second derivatives.
  interior = zeros(m, 1);
  interior(m) = dd(m);
  for i = m - 1:-1:1
    interior(i) = dd(i) - cc(i) * interior(i + 1);
  end
  secondDeriv = [0; interior; 0];
  %===========================================================================
  % Locate each query point's knot interval: interp1 of the knot indices
  % against the knot positions gives the fractional position at once, and its
  % floor is the interval. The last knot is pulled back into the last interval
  % so its cubic is evaluated.
  position = interp1(x, (1:n)', q, 'linear');
  idx = floor(position);
  idx = max(min(idx, n - 1), 1);
  hi = h(idx);
  xl = x(idx);
  xr = x(idx + 1);
  ml = secondDeriv(idx);
  mr = secondDeriv(idx + 1);
  yl = y(idx);
  yr = y(idx + 1);
  a = xr - q;
  b = q - xl;
  v = ml .* a .^ 3 ./ (6 * hi) + mr .* b .^ 3 ./ (6 * hi) + ...
  (yl ./ hi - ml .* hi / 6) .* a + (yr ./ hi - mr .* hi / 6) .* b;
end
%=============================================================================
