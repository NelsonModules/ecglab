%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function value = ecgLabQualityBsqi(times1, times2, matchWindow)
  % bSQI of one window (Li, Mark and Clifford 2008): the F1 agreement of two
  % QRS detectors, 2 M / (n1 + n2) for M matched pairs. No beats scores zero.
  n1 = numel(times1);
  n2 = numel(times2);
  if n1 + n2 == 0
    value = 0;
    return;
  end
  matched = ecgLabQualityBsqiMatch(times1, times2, matchWindow);
  value = 2 * matched / (n1 + n2);
end
%=============================================================================
function matched = ecgLabQualityBsqiMatch(times1, times2, window)
  % Count matching beats by a two-pointer walk over the two sorted lists: a
  % pair within the window matches and both advance, else the earlier advances.
  times1 = sort(times1(:));
  times2 = sort(times2(:));
  n1 = numel(times1);
  n2 = numel(times2);
  i = 1;
  j = 1;
  matched = 0;
  while i <= n1 && j <= n2
    if abs(times1(i) - times2(j)) <= window
      matched = matched + 1;
      i = i + 1;
      j = j + 1;
    elseif times1(i) < times2(j)
      i = i + 1;
    else
      j = j + 1;
    end
  end
end
%=============================================================================
