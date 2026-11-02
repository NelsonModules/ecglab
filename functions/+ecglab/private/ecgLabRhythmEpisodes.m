%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [episodes, perBeat, afBurden] = ecgLabRhythmEpisodes(isAF, times, ...
  minEpisode)
  % Turn the per-beat fibrillation verdict into episodes tiling the span, with
  % runs shorter than MinEpisode smoothed away. Bridge short sinus gaps first,
  % then drop short fibrillation runs; order matters so real episodes around a
  % doubted gap join before any length test removes them.
  times = times(:);
  nBeats = numel(times);
  label = logical(isAF(:));
  t0 = times(1);
  t1 = times(end);
  %===========================================================================
  % Bridge a short sinus gap between two fibrillation runs.
  [startIdx, endIdx, value] = ecgLabRhythmRuns(label);
  for run = 1:numel(value)
    if value(run)
      continue;
    end
    if run == 1 || run == numel(value)
      continue;
    end
    duration = ecgLabRhythmRunDuration(times, startIdx(run), endIdx(run), ...
    t0, t1, nBeats);
    if duration < minEpisode
      label(startIdx(run):endIdx(run)) = true;
    end
  end
  %===========================================================================
  % Drop a short fibrillation run.
  [startIdx, endIdx, value] = ecgLabRhythmRuns(label);
  for run = 1:numel(value)
    if ~value(run)
      continue;
    end
    duration = ecgLabRhythmRunDuration(times, startIdx(run), endIdx(run), ...
    t0, t1, nBeats);
    if duration < minEpisode
      label(startIdx(run):endIdx(run)) = false;
    end
  end
  %===========================================================================
  % The episodes are the maximal runs of the final label, tiling the span.
  [startIdx, endIdx, value] = ecgLabRhythmRuns(label);
  count = numel(value);
  onset = zeros(count, 1);
  offset = zeros(count, 1);
  labelText = cell(count, 1);
  for run = 1:count
    if startIdx(run) == 1
      onset(run) = t0;
    else
      onset(run) = (times(startIdx(run) - 1) + times(startIdx(run))) / 2;
    end
    if endIdx(run) == nBeats
      offset(run) = t1;
    else
      offset(run) = (times(endIdx(run)) + times(endIdx(run) + 1)) / 2;
    end
    labelText{run} = ecgLabRhythmName(value(run));
  end
  episodes = struct('onset', onset, 'offset', offset, 'label', {labelText});
  %===========================================================================
  perBeat = cell(nBeats, 1);
  for b = 1:nBeats
    perBeat{b} = ecgLabRhythmName(label(b));
  end
  span = t1 - t0;
  if span > 0
    afBurden = sum((offset - onset) .* strcmp(labelText, 'AFIB')) / span;
  else
    afBurden = 0;
  end
end
%=============================================================================
function [startIdx, endIdx, value] = ecgLabRhythmRuns(x)
  % Maximal runs of a logical vector: start index, end index and value of each.
  x = x(:);
  n = numel(x);
  if n == 0
    startIdx = zeros(0, 1);
    endIdx = zeros(0, 1);
    value = false(0, 1);
    return;
  end
  startIdx = [1; find(diff(x) ~= 0) + 1];
  endIdx = [startIdx(2:end) - 1; n];
  value = x(startIdx);
end
%=============================================================================
function duration = ecgLabRhythmRunDuration(times, i, j, t0, t1, nBeats)
  % A run's duration in seconds, measured between midpoints to its neighbours
  % so a one-beat run still has a length and runs tile the span without gaps.
  if i == 1
    onset = t0;
  else
    onset = (times(i - 1) + times(i)) / 2;
  end
  if j == nBeats
    offset = t1;
  else
    offset = (times(j) + times(j + 1)) / 2;
  end
  duration = offset - onset;
end
%=============================================================================
function name = ecgLabRhythmName(isAF)
  if isAF
    name = 'AFIB';
  else
    name = 'N';
  end
end
%=============================================================================
