%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [irregularity, meanRR, pFraction] = ecgLabRhythmWindowStats(rr, ...
  pAbsent, window, step)
  % Per-window statistics for every moving window at once, via cumulative sums:
  % mean RR, normalised RMS of successive RR differences (irregularity, Dash
  % 2009), and the share of window beats with no P wave. A window of WINDOW
  % beats holds WINDOW - 1 intervals and WINDOW - 2 successive differences.
  rr = rr(:);
  nIntervals = numel(rr);
  nBeats = nIntervals + 1;
  starts = (1:step:(nBeats - window + 1))';
  % Mean RR per window: sum of its WINDOW - 1 intervals over their count.
  csr = [0; cumsum(rr)];
  sumRR = csr(starts + window - 1) - csr(starts);
  meanRR = sumRR / (window - 1);
  % RMS of successive differences per window, over WINDOW - 2 of them.
  dd = diff(rr);
  csdd = [0; cumsum(dd .^ 2)];
  sumSq = csdd(starts + window - 2) - csdd(starts);
  rmssd = sqrt(sumSq / (window - 2));
  irregularity = zeros(size(meanRR));
  positive = meanRR > 0;
  irregularity(positive) = rmssd(positive) ./ meanRR(positive);
  % The P-absence share of each window, over its WINDOW beats.
  csp = [0; cumsum(double(pAbsent(:)))];
  pFraction = (csp(starts + window) - csp(starts)) / window;
end
%=============================================================================
