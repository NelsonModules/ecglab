%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function geometry = ecgLabHrvTinn(nnms)
  % The two Task Force geometric measures, on a histogram of the NN intervals
  % with bin width exactly 1/128 second = 7.8125 ms. The width is part of the
  % definition: a different width gives a different triangular index.
  binWidth = 1000 / 128;
  % Bin edges covering the data, anchored on multiples of the bin width so the
  % grid is the same for every record.
  lo = floor(min(nnms) / binWidth) * binWidth;
  hi = ceil(max(nnms) / binWidth) * binWidth;
  edges = (lo:binWidth:hi + binWidth)';
  counts = histc(nnms, edges);
  % histc puts values equal to the last edge in a final bin; drop it so the
  % centres below match the remaining bins one for one.
  counts = counts(1:end - 1);
  centres = edges(1:end - 1) + binWidth / 2;
  [peakHeight, peakBin] = max(counts);
  %===========================================================================
  % Triangular index: the NN count over the histogram height (the tallest bin),
  % a count over a count, unitless.
  geometry = struct();
  geometry.binWidth = binWidth;
  geometry.triangularIndex = sum(counts) / peakHeight;
  %===========================================================================
  % TINN: the base of the triangle that best fits the histogram by least
  % squares. The apex is the tallest bin (centre X, height Y); feet M below X
  % and N above X are searched to minimise the squared error. TINN is N - M.
  nBins = numel(counts);
  x = centres;
  y = counts;
  X = centres(peakBin);
  Y = peakHeight;
  bestError = Inf;
  bestBase = 0;
  % Search left and right feet around the apex; a degenerate N <= M is skipped.
  leftFeet = 1:peakBin;
  rightFeet = peakBin:nBins;
  for li = 1:numel(leftFeet)
    mBin = leftFeet(li);
    M = x(mBin);
    for ri = 1:numel(rightFeet)
      nBin = rightFeet(ri);
      N = x(nBin);
      if N <= M
        continue;
      end
      q = zeros(nBins, 1);
      % Rising limb from M to X, falling limb from X to N, zero outside.
      if X > M
        up = x >= M & x <= X;
        q(up) = Y * (x(up) - M) / (X - M);
      end
      if N > X
        down = x > X & x <= N;
        q(down) = Y * (N - x(down)) / (N - X);
      end
      err = sum((y - q) .^ 2);
      if err < bestError
        bestError = err;
        bestBase = N - M;
      end
    end
  end
  geometry.tinn = bestBase;
end
%=============================================================================
