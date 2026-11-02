%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectElgendi(signal, rate, options)
  % Elgendi et al. (2010, 2013) QRS detector: two moving averages, no running
  % threshold. The signal is band-passed to the QRS band and squared into an
  % energy, then smoothed by a short average (QRS width) and a long one (beat
  % width). Where the short rises above the long (plus a small offset) a block
  % of interest opens; a block at least a QRS wide holds one beat, at its
  % largest band-passed sample.
  %
  % Input is a column in mV; fiducials come back as 1-based samples, to be
  % snapped to R by the caller.
  N = numel(signal);
  %===========================================================================
  % Band-pass 8 to 20 Hz (the 2010 paper's QRS band), second-order Butterworth
  % applied zero-phase, so the complex is not delayed.
  filtered = ecgLabQrsBandpass(signal, rate, 8, 20, 2);
  %===========================================================================
  % Emphasis step: clip the negative part to zero (so a downward lobe raises no
  % second block) and square, giving the energy the averages smooth.
  clipped = filtered;
  clipped(clipped < 0) = 0;
  squared = clipped .^ 2;
  %===========================================================================
  % Two moving averages (centered cumulative sums). MA_peak over W1 = 97 ms
  % follows a single complex; MA_beat over W2 = 611 ms follows the local
  % background. Both widths are the 2013 paper's optimised values.
  w1 = max(1, round(0.097 * rate));
  w2 = max(1, round(0.611 * rate));
  maPeak = ecgLabQrsMovingAverage(squared, w1);
  maBeat = ecgLabQrsMovingAverage(squared, w2);
  %===========================================================================
  % Threshold THR1 = MA_beat + beta * mean(squared), beta = 0.08; the offset
  % keeps flat low-energy stretches from opening spurious blocks. A block of
  % interest is a run where MA_peak stays above THR1.
  beta = 0.08;
  threshold = maBeat + beta * mean(squared);
  mask = maPeak > threshold;
  %===========================================================================
  % Runs of the mask from the rises and falls of its first difference: a 0-to-1
  % step starts a block, a 1-to-0 step ends it. Keep a block only when it is at
  % least W1 wide (the paper's THR2 = W1).
  edges = diff([0; double(mask); 0]);
  starts = find(edges == 1);
  stops = find(edges == -1) - 1;
  wide = (stops - starts + 1) >= w1;
  starts = starts(wide);
  stops = stops(wide);
  if isempty(starts)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(maPeak, threshold, filtered);
    return;
  end
  %===========================================================================
  % Beat of each block: the largest band-passed sample inside it. The peak
  % value is kept too, so a merge can favour the stronger block.
  blockCount = numel(starts);
  beats = zeros(blockCount, 1);
  peakValue = zeros(blockCount, 1);
  for index = 1:blockCount
    lo = starts(index);
    hi = stops(index);
    [value, offset] = max(filtered(lo:hi));
    beats(index) = lo + offset - 1;
    peakValue(index) = value;
  end
  %===========================================================================
  % Merge two blocks whose beats fall closer than 0.3 s (one complex seen
  % twice), keeping the stronger. A refractory longer than 0.3 s widens the gap.
  mergeGap = max(round(0.3 * rate), ...
  max(1, round(double(options.Refractory) * rate)));
  keep = true(blockCount, 1);
  last = 0;
  for index = 1:blockCount
    if last > 0 && beats(index) - beats(last) < mergeGap
      if peakValue(index) > peakValue(last)
        keep(last) = false;
        last = index;
      else
        keep(index) = false;
      end
    else
      last = index;
    end
  end
  sample = beats(keep);
  sample = sort(sample(:));
  %===========================================================================
  % Evidence: MA_peak as the feature and the THR1 series as the threshold, so
  % the beat view can draw the block openings directly.
  evidence = ecgLabQrsEvidence(maPeak, threshold, filtered);
end
%=============================================================================
