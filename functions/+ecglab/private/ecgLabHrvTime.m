%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function time = ecgLabHrvTime(nn, options)
  % Time-domain measures (1996 Task Force) on the NN series in milliseconds.
  % SDNN is the standard deviation over all NN (N - 1 convention); RMSSD and
  % SDSD use the successive differences; NN50 and NN20 count differences over
  % 50 and 20 ms. Each quantity is named as the standard names it.
  nnms = nn * 1000;
  d = diff(nnms);
  nd = numel(d);
  time = struct();
  time.meanNN = mean(nnms);
  % Mean heart rate from the instantaneous rates, not 60 / mean(NN): the Task
  % Force means the average beat-to-beat rate.
  time.meanHR = mean(60 ./ nn);
  time.sdnn = std(nnms);
  time.rmssd = sqrt(mean(d .^ 2));
  time.sdsd = std(d);
  time.nn50 = sum(abs(d) > 50);
  time.pnn50 = 100 * time.nn50 / nd;
  time.nn20 = sum(abs(d) > 20);
  time.pnn20 = 100 * time.nn20 / nd;
  %===========================================================================
  % SDANN and the SDNN index split the record into fixed segments (five minutes
  % by default). SDANN is the spread of the segment means (slow rate drift);
  % the SDNN index is the mean of the segment spreads (within-segment
  % variation). Both need more than one segment, and a spread needs more than
  % one interval.
  segment = double(options.Segment);
  tcum = cumsum(nn);
  segId = floor(tcum / segment);
  ids = unique(segId);
  segMeans = zeros(numel(ids), 1);
  segStds = NaN(numel(ids), 1);
  for k = 1:numel(ids)
    block = nnms(segId == ids(k));
    segMeans(k) = mean(block);
    if numel(block) >= 2
      segStds(k) = std(block);
    end
  end
  if numel(ids) >= 2
    time.sdann = std(segMeans);
  else
    time.sdann = NaN;
  end
  valid = ~isnan(segStds);
  if any(valid)
    time.sdnnIndex = mean(segStds(valid));
  else
    time.sdnnIndex = NaN;
  end
  %===========================================================================
  % The geometric measures share one histogram with bin width 1/128 s =
  % 7.8125 ms. The triangular index is the NN count over the histogram height;
  % TINN is the base of the triangle fitted to it by least squares.
  geometry = ecgLabHrvTinn(nnms);
  time.triangularIndex = geometry.triangularIndex;
  time.tinn = geometry.tinn;
  time.histogramBinWidth = geometry.binWidth;
end
%=============================================================================
