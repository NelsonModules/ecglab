%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function baseline = ecgLabCleanMedian(signal, rate)
  % Two-stage sliding-median baseline estimate. A 200 ms median removes the QRS
  % complexes, a 600 ms median of that removes the P and T waves. The caller
  % subtracts the result. A median keeps the ST level under a tall narrow QRS.
  signal = signal(:);
  w1 = round(0.2 * rate);
  w2 = round(0.6 * rate);
  stage1 = ecgLabCleanGridMedian(signal, w1, rate);
  baseline = ecgLabCleanGridMedian(stage1, w2, rate);
end
%=============================================================================
function y = ecgLabCleanGridMedian(x, w, rate)
  % Sliding median of window W. Overlapping windows form the columns of a
  % matrix and the median is taken down each column with one sort. To stay
  % fast, the median is evaluated on a grid of one column every 80 ms and
  % linearly interpolated between; the baseline is well below 1 Hz, so this
  % matches the per-sample median closely. The window is forced odd.
  x = x(:);
  n = numel(x);
  if mod(w, 2) == 0
    w = w + 1;
  end
  half = (w - 1) / 2;
  middle = (w + 1) / 2;
  % Replicate the ends so every window is full and the baseline does not dip
  % at the first and last half window.
  padded = [repmat(x(1), half, 1); x; repmat(x(n), half, 1)];
  step = max(1, round(0.08 * rate));
  grid = unique([1:step:n, n]);
  % Column j holds the window centred at grid(j): rows are offsets 0..w-1 from
  % its start in the padded signal. Sort each column and take the middle row.
  idx = (0:w - 1)' + grid;
  sorted = sort(padded(idx), 1);
  gridValue = sorted(middle, :)';
  y = interp1(grid', gridValue, (1:n)', 'linear');
end
%=============================================================================
