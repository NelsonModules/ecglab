%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectPantompkins(signal, rate, options)
  % Pan and Tompkins (1985): four preprocessing stages and an adaptive
  % decision. Input is a column in mV; fiducials come back as 1-based samples
  % on the integrated signal, to be snapped to R by the caller. Evidence
  % carries the thresholded series, the threshold at each sample, and the
  % band-passed trace.
  refractory = max(1, round(double(options.Refractory) * rate));
  N = numel(signal);
  %===========================================================================
  % Stage 1, band-pass 5 to 15 Hz: passes the QRS, stops the P and T waves
  % below and muscle noise above. Zero-phase, so the complex is not delayed.
  filtered = ecgLabQrsBandpass(signal, rate, 5, 15, 3);
  %===========================================================================
  % Stage 2, slope: the paper's five-point derivative, scaled by the rate and
  % centered so it adds no delay.
  kernel = rate * [1, 2, 0, -2, -1] / 8;
  derivative = conv(filtered, kernel, 'same');
  %===========================================================================
  % Stage 3, energy: squaring makes every point positive and lifts the steep
  % QRS slope above the gentle ones. Stage 4, moving-window integration over
  % 150 ms (one QRS width), centered on a cumulative sum, merges the slopes
  % into one hill.
  squared = derivative .^ 2;
  integrated = ecgLabQrsMovingAverage(squared, round(0.150 * rate));
  %===========================================================================
  % Candidate peaks: local maxima of the integrated signal, thinned so two
  % maxima of one hill closer than the refractory period keep only the larger.
  candidates = ecgLabQrsLocalMaxima(integrated, refractory);
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(integrated, ...
    zeros(N, 1), filtered);
    return;
  end
  candidateValue = integrated(candidates);
  %===========================================================================
  % Adaptive thresholds from the first two seconds: SPKI from the largest hill,
  % NPKI from the mean, THRESHOLD1 = NPKI + 0.25 (SPKI - NPKI).
  learn = min(N, round(2 * rate));
  spki = max(integrated(1:learn));
  npki = mean(integrated(1:learn));
  if ~(spki > npki)
    spki = npki + eps;
  end
  threshold1 = npki + 0.25 * (spki - npki);
  %===========================================================================
  % Decision, one pass over the candidate peaks. A slope window on the
  % band-passed signal feeds the T-wave test. The threshold in force is
  % recorded at each candidate so the held series can be rebuilt.
  slopeWindow = max(1, round(0.075 * rate));
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
    if peak > threshold1
      sinceLast = here - lastBeat;
      if sinceLast <= refractory
        % Inside the refractory period: the same complex seen twice; discard
        % it without touching either level.
        isBeat = false;
      elseif beatCount > 0 && sinceLast < round(0.360 * rate)
        % Between the refractory period and 360 ms: slope test for a T wave.
        % If the slope here is under half the last beat's, it is the T wave.
        if slope < 0.5 * beatSlope(beatCount)
          isBeat = false;
        else
          isBeat = true;
        end
      else
        isBeat = true;
      end
      if isBeat
        spki = 0.125 * peak + 0.875 * spki;
      else
        npki = 0.125 * peak + 0.875 * npki;
      end
    else
      npki = 0.125 * peak + 0.875 * npki;
    end
    if isBeat
      beatCount = beatCount + 1;
      beats(beatCount) = here;
      beatSlope(beatCount) = slope;
      if beatCount > 1
        rr(end + 1) = (here - lastBeat) / rate; %#ok<AGROW>
      end
      lastBeat = here;
    end
    threshold1 = npki + 0.25 * (spki - npki);
    thrPos(index) = here;
    thrVal(index) = threshold1;
    %=========================================================================
    % Search back: if no beat within 1.66 times the recent average RR, look
    % again at the peaks since the last beat with the threshold halved and take
    % the largest that clears it. The average uses only the regular beats
    % (within 92 to 116 per cent of the running mean).
    if beatCount >= 2
      rrAverage = ecgLabRegularAverage(rr);
      limit = round(1.66 * rrAverage * rate);
      if here - lastBeat > limit
        threshold2 = 0.5 * threshold1;
        [found, foundValue] = ecgLabSearchBack(candidates, candidateValue, ...
        index, lastBeat + refractory, here, threshold2);
        if found > 0
          beatCount = beatCount + 1;
          beats(beatCount) = found;
          beatSlope(beatCount) = ecgLabQrsLocalSlope(filtered, found, ...
          slopeWindow);
          rr(end + 1) = (found - lastBeat) / rate; %#ok<AGROW>
          lastBeat = found;
          spki = 0.25 * foundValue + 0.75 * spki;
          threshold1 = npki + 0.25 * (spki - npki);
        end
      end
    end
  end
  beats = beats(1:beatCount);
  beats = sort(beats);
  sample = beats(:);
  %===========================================================================
  % Rebuild the threshold as a step function: the initial value before the
  % first candidate, then each candidate's value held until the next.
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:numel(candidates)), ...
  thrVal(1:numel(candidates)), N, npki + 0.25 * (spki - npki));
  evidence = ecgLabQrsEvidence(integrated, thrSeries, filtered);
end
%=============================================================================
function average = ecgLabRegularAverage(rr)
  % Mean of the last eight RR intervals, then the mean of those within 92 to
  % 116 per cent of it (the paper's RR AVERAGE2).
  recent = rr(max(1, numel(rr) - 7):end);
  first = mean(recent);
  regular = recent(recent >= 0.92 * first & recent <= 1.16 * first);
  if isempty(regular)
    average = first;
  else
    average = mean(regular);
  end
end
%=============================================================================
function [found, foundValue] = ecgLabSearchBack(candidates, values, upto, ...
  lo, hi, threshold2)
  % Largest candidate peak strictly inside the missed interval that clears the
  % halved threshold, scanning back over recent candidates only.
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
    if values(index) > threshold2 && values(index) > foundValue
      foundValue = values(index);
      found = position;
    end
  end
end
%=============================================================================
