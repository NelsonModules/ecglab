%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectHamilton(signal, rate, options)
  % Hamilton (2002). Like Pan and Tompkins (band, slope, smooth, adaptive
  % threshold) but with a higher band, a rectified rather than squared
  % derivative, and signal and noise levels taken as the median of the last
  % eight peaks of each kind. The threshold sits a fixed fraction of the way
  % from the noise level to the signal level.
  refractory = max(1, round(0.2 * rate));
  userRefractory = max(1, round(double(options.Refractory) * rate));
  refractory = max(refractory, userRefractory);
  N = numel(signal);
  %===========================================================================
  % Band-pass 8 to 16 Hz, which rejects more of the T wave; order one, applied
  % zero-phase so the complex is not delayed.
  filtered = ecgLabQrsBandpass(signal, rate, 8, 16, 1);
  %===========================================================================
  % Feature: the rectified derivative (absolute slope, positive for either
  % polarity) smoothed over 80 ms to merge the QRS slopes into one hill. The
  % average is a centered cumulative sum.
  derivative = abs([0; diff(filtered)]);
  integrated = ecgLabQrsMovingAverage(derivative, round(0.080 * rate));
  %===========================================================================
  % Candidate peaks: local maxima at least 200 ms apart.
  candidates = ecgLabQrsLocalMaxima(integrated, refractory);
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(integrated, zeros(N, 1), filtered);
    return;
  end
  candidateValue = integrated(candidates);
  %===========================================================================
  % Seed the two levels from the first two seconds: signal from the largest
  % hill, noise from the mean. Thereafter each is the median of its last eight
  % peaks.
  learn = min(N, round(2 * rate));
  signalSeed = max(integrated(1:learn));
  noiseSeed = mean(integrated(1:learn));
  qrsPeaks = signalSeed;
  noisePeaks = noiseSeed;
  % 0.3125 is the paper's coefficient (five sixteenths from noise to signal).
  coefficient = 0.3125;
  threshold = noiseSeed + coefficient * (signalSeed - noiseSeed);
  slopeWindow = max(1, round(0.075 * rate));
  twaveLimit = round(0.360 * rate);
  beats = zeros(numel(candidates), 1);
  beatSlope = zeros(numel(candidates), 1);
  beatCount = 0;
  lastBeat = -refractory;
  thrPos = zeros(numel(candidates), 1);
  thrVal = zeros(numel(candidates), 1);
  rr = [];
  for index = 1:numel(candidates)
    here = candidates(index);
    peak = candidateValue(index);
    slope = ecgLabQrsLocalSlope(filtered, here, slopeWindow);
    isBeat = false;
    if peak > threshold && (here - lastBeat) > refractory
      if beatCount > 0 && (here - lastBeat) < twaveLimit && ...
        slope < 0.5 * beatSlope(beatCount)
        % A gently rising peak soon after a beat is its T wave, not a complex.
        isBeat = false;
      else
        isBeat = true;
      end
    end
    if isBeat
      beatCount = beatCount + 1;
      beats(beatCount) = here;
      beatSlope(beatCount) = slope;
      if beatCount > 1
        rr(end + 1) = (here - lastBeat) / rate; %#ok<AGROW>
      end
      lastBeat = here;
      qrsPeaks(end + 1) = peak; %#ok<AGROW>
    else
      noisePeaks(end + 1) = peak; %#ok<AGROW>
    end
    signalLevel = ecgLabHamiltonLevel(qrsPeaks);
    noiseLevel = ecgLabHamiltonLevel(noisePeaks);
    threshold = noiseLevel + coefficient * (signalLevel - noiseLevel);
    thrPos(index) = here;
    thrVal(index) = threshold;
    %=========================================================================
    % Search back for a missed beat when more than 1.5 times the recent average
    % RR has passed with none found; the threshold is halved for this look.
    if beatCount >= 2
      average = ecgLabHamiltonAverage(rr);
      if here - lastBeat > round(1.5 * average * rate)
        [found, foundValue] = ecgLabHamiltonSearchBack(candidates, ...
        candidateValue, index, lastBeat + refractory, here, 0.5 * threshold);
        if found > 0
          beatCount = beatCount + 1;
          beats(beatCount) = found;
          beatSlope(beatCount) = ecgLabQrsLocalSlope(filtered, found, ...
          slopeWindow);
          rr(end + 1) = (found - lastBeat) / rate; %#ok<AGROW>
          lastBeat = found;
          qrsPeaks(end + 1) = foundValue; %#ok<AGROW>
          signalLevel = ecgLabHamiltonLevel(qrsPeaks);
          noiseLevel = ecgLabHamiltonLevel(noisePeaks);
          threshold = noiseLevel + coefficient * (signalLevel - noiseLevel);
        end
      end
    end
  end
  beats = sort(beats(1:beatCount));
  sample = beats(:);
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:numel(candidates)), ...
  thrVal(1:numel(candidates)), N, threshold);
  evidence = ecgLabQrsEvidence(integrated, thrSeries, filtered);
end
%=============================================================================
function level = ecgLabHamiltonLevel(peaks)
  % Median of the last eight peaks of a kind, so one outlier does not move the
  % level. Computed by sorting and averaging the middle pair rather than
  % calling median, which is faster here.
  recent = sort(peaks(max(1, numel(peaks) - 7):end));
  count = numel(recent);
  middle = floor((count + 1) / 2);
  if mod(count, 2) == 1
    level = recent(middle);
  else
    level = 0.5 * (recent(middle) + recent(middle + 1));
  end
end
%=============================================================================
function average = ecgLabHamiltonAverage(rr)
  % Mean of the last eight RR intervals, used for the search-back limit.
  recent = rr(max(1, numel(rr) - 7):end);
  average = mean(recent);
end
%=============================================================================
function [found, foundValue] = ecgLabHamiltonSearchBack(candidates, values, ...
  upto, lo, hi, threshold)
  % Largest candidate inside the missed interval that clears the halved
  % threshold, scanning back over recent candidates only.
  found = 0;
  foundValue = 0;
  for index = upto:-1:1
    position = candidates(index);
    if position < lo
      break;
    end
    if position >= hi
      continue;
    end
    if values(index) > threshold && values(index) > foundValue
      foundValue = values(index);
      found = position;
    end
  end
end
%=============================================================================
