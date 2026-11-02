%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function series = ecgLabQrsHoldSeries(positions, values, N, initial)
  % Step function of length N: the threshold value held constant between
  % candidate peaks, built in one pass by filling each segment.
  series = zeros(N, 1);
  if isempty(positions)
    series(:) = initial;
    return;
  end
  positions = round(positions(:));
  values = values(:);
  first = max(1, positions(1));
  if first > 1
    series(1:first - 1) = initial;
  end
  for index = 1:numel(positions)
    start = max(1, positions(index));
    if index < numel(positions)
      stop = max(start, positions(index + 1) - 1);
    else
      stop = N;
    end
    stop = min(stop, N);
    series(start:stop) = values(index);
  end
end
%=============================================================================
