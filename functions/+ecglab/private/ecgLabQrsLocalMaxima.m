%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function peaks = ecgLabQrsLocalMaxima(x, minGap)
  % Local maxima of a signal, kept at least minGap samples apart (a sign change
  % in the first difference); of two within minGap, the taller is kept.
  x = x(:);
  N = numel(x);
  if N < 3
    peaks = zeros(0, 1);
    return;
  end
  rising = diff(x);
  isPeak = false(N, 1);
  isPeak(2:N - 1) = rising(1:N - 2) > 0 & rising(2:N - 1) <= 0;
  candidates = find(isPeak);
  if isempty(candidates)
    peaks = zeros(0, 1);
    return;
  end
  minGap = max(1, round(minGap));
  kept = zeros(numel(candidates), 1);
  count = 0;
  lastPos = -inf;
  lastVal = -inf;
  for index = 1:numel(candidates)
    here = candidates(index);
    value = x(here);
    if here - lastPos < minGap
      % Too close to the last kept peak: replace only if taller.
      if value > lastVal
        kept(count) = here;
        lastPos = here;
        lastVal = value;
      end
    else
      count = count + 1;
      kept(count) = here;
      lastPos = here;
      lastVal = value;
    end
  end
  peaks = kept(1:count);
end
%=============================================================================
