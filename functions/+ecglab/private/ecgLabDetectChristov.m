%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectChristov(signal, rate, options)
  % Christov (2004) QRS detection by a combined adaptive threshold. Two moving
  % averages clean the signal, the absolute derivative forms an envelope, and a
  % threshold built from three parts (steep slope M, slow drift F, beat-due R)
  % decides where a QRS is. Input is a column in mV; fiducials come back as
  % 1-based samples on the envelope, to be snapped to R by the caller. Evidence
  % carries the envelope and the combined threshold MFR.
  refractory = max(1, round(double(options.Refractory) * rate));
  ms200 = max(refractory, round(0.200 * rate));
  N = numel(signal);
  %===========================================================================
  % Preprocessing: the paper's two moving averages. 20 ms (one mains period)
  % averages out power line interference; 28 ms smooths EMG noise. Both are
  % centered cumulative-sum windows, so the cleaned signal is not delayed.
  ma1 = ecgLabQrsMovingAverage(signal(:), round(0.020 * rate));
  ma2 = ecgLabQrsMovingAverage(ma1, round(0.028 * rate));
  %===========================================================================
  % Envelope Y: the absolute derivative of the cleaned signal (centered
  % difference), so a complex of either polarity makes a positive hill. A final
  % 40 ms average merges the slopes of one QRS into a single hill.
  derivative = abs(conv(ma2, [1, 0, -1], 'same'));
  feature = ecgLabQrsMovingAverage(derivative, round(0.040 * rate));
  % Zero the startup transient over the total filter length, so the threshold
  % is learned from beats and not from the edge.
  nTaps = round(0.020 * rate) + round(0.028 * rate) + round(0.040 * rate);
  feature(1:min(N, nTaps)) = 0;
  %===========================================================================
  % Integrating threshold F, which follows slow changes in level. Per the
  % paper, F += (max Y over the latest 50 ms - max Y over the 50 ms ending
  % 300 ms ago) / 150. This is a cumulative sum of per-sample increments.
  ms50 = max(1, round(0.050 * rate));
  ms350 = max(ms50 + 1, round(0.350 * rate));
  ms300 = ms350 - ms50;
  windowMax = ecgLabChristovTrailingMax(feature, ms50);
  % The earliest window is the latest shifted back by 300 ms.
  earliest = [repmat(windowMax(1), ms300, 1); windowMax(1:N - ms300)];
  increment = (windowMax - earliest) / 150;
  % Integrate F only once a full 350 ms of history exists; before that the
  % increment is held at zero.
  increment(1:min(N, ms350)) = 0;
  F = cumsum(increment);
  %===========================================================================
  % Candidate peaks of the envelope, no closer than the refractory period. The
  % decision loop walks these, building M and R at each (they depend on the
  % beats already found, so cannot be precomputed like F). The envelope floor
  % is clipped to zero below a hundredth of the largest hill, which drops the
  % numerical ripples of flat stretches without losing any real beat.
  floorLevel = 0.01 * max(feature);
  peakSignal = feature;
  peakSignal(peakSignal < floorLevel) = 0;
  candidates = ecgLabQrsLocalMaxima(peakSignal, ms200);
  fiveSeconds = min(N, round(5 * rate));
  % Seed M over the first 5 s: 0.6 of the largest envelope hill there. The mean
  % of the last five beat maxima (MM) starts from the same seed.
  seed = 0.6 * max(feature(1:fiveSeconds));
  if ~(seed > 0)
    seed = eps;
  end
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(feature, repmat(seed, N, 1), ma2);
    return;
  end
  ms1200 = max(ms200 + 1, round(1.200 * rate));
  %===========================================================================
  mmRing = repmat(seed, 5, 1);
  meanMM = seed;
  lastMM = seed;
  rrRing = zeros(0, 1);
  expectedRR = 0;
  lastBeat = -ms200;
  beatCount = 0;
  beats = zeros(numel(candidates), 1);
  heldM = seed;
  thrPos = zeros(numel(candidates), 1);
  thrVal = zeros(numel(candidates), 1);
  % T-wave test (single lead): a candidate within 360 ms of a beat whose
  % envelope hill is under half the last beat's is that T wave (or a second
  % hump of the same complex), not a new QRS.
  twaveLimit = round(0.360 * rate);
  lastPeak = 0;
  for index = 1:numel(candidates)
    here = candidates(index);
    peak = feature(here);
    %=========================================================================
    % Steep-slope threshold M. In the first 5 s it is the seed. After that it is
    % held for 200 ms past a beat, decays linearly to 0.6 between 200 and
    % 1200 ms, and rests at 0.6 of the recent beat level beyond that.
    if here < fiveSeconds
      M = seed;
    elseif beatCount == 0
      M = meanMM;
    else
      dt = here - lastBeat;
      if dt <= ms200
        M = heldM;
      elseif dt < ms1200
        slope = 1.0 - 0.4 * (dt - ms200) / (ms1200 - ms200);
        M = meanMM * slope;
      else
        M = 0.6 * meanMM;
      end
    end
    %=========================================================================
    % Beat-expectation threshold R. Zero until two thirds of the expected RR
    % (mean of the last five intervals) have passed, then negative as the beat
    % becomes due, so a low-amplitude QRS is not missed.
    if beatCount > 0 && expectedRR > 0 && ...
      (here - lastBeat) >= (2 / 3) * expectedRR
      R = (M - meanMM) / 1.4;
    else
      R = 0;
    end
    mfr = M + F(here) + R;
    thrPos(index) = here;
    thrVal(index) = mfr;
    %=========================================================================
    % A QRS is an envelope hill above the combined threshold, at least a
    % refractory period after the last beat, and not the preceding T wave.
    isTwave = beatCount > 0 && (here - lastBeat) < twaveLimit && ...
    peak < 0.5 * lastPeak;
    if peak > mfr && ~isTwave && (beatCount == 0 || (here - lastBeat) > ms200)
      % New beat level: 0.6 of the largest envelope hill since the last beat,
      % limited so one artefact cannot lift the level by more than a tenth.
      from = max(1, lastBeat);
      newM5 = 0.6 * max(feature(from:here));
      if newM5 > 1.5 * lastMM
        newM5 = 1.1 * lastMM;
      end
      if ~(newM5 > 0)
        newM5 = lastMM;
      end
      mmRing = [mmRing(2:end); newM5];
      meanMM = mean(mmRing);
      lastMM = newM5;
      if beatCount > 0
        rrRing = [rrRing; here - lastBeat];
        if numel(rrRing) > 5
          rrRing = rrRing(end - 4:end);
        end
        expectedRR = mean(rrRing);
      end
      heldM = M;
      lastBeat = here;
      lastPeak = peak;
      beatCount = beatCount + 1;
      beats(beatCount) = here;
    end
  end
  beats = beats(1:beatCount);
  sample = sort(beats(:));
  %===========================================================================
  % Rebuild the threshold as a step function so the beat view can draw the MFR
  % each envelope hill was compared against.
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:numel(candidates)), ...
  thrVal(1:numel(candidates)), N, seed);
  evidence = ecgLabQrsEvidence(feature, thrSeries, ma2);
end
%=============================================================================
function windowMax = ecgLabChristovTrailingMax(x, width)
  % Maximum of x over a trailing window of the given width, at every sample, by
  % the van Herk / Gil-Werman sliding maximum: cut into blocks of the window
  % width, take a prefix and a suffix max per block (two cumulative-max passes),
  % and any window then straddles at most two blocks.
  x = x(:);
  N = numel(x);
  width = max(1, round(width));
  if width == 1
    windowMax = x;
    return;
  end
  blocks = ceil(N / width);
  padded = [x; repmat(-Inf, blocks * width - N, 1)];
  grid = reshape(padded, width, blocks);
  prefix = cummax(grid, 1);
  suffix = flipud(cummax(flipud(grid), 1));
  prefix = prefix(:);
  suffix = suffix(:);
  % The window ending at i is the suffix from its start block joined to the
  % prefix up to i. The first window has no suffix term, just the prefix.
  prefix = prefix(1:N);
  suffixShift = [repmat(-Inf, width - 1, 1); suffix(1:N - width + 1)];
  windowMax = max(prefix, suffixShift);
end
%=============================================================================
