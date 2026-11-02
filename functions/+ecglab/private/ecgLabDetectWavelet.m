%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectWavelet(signal, rate, options)
  % Kalidas and Tamil (2017), a QRS detector on the stationary wavelet
  % transform. The detail of a mid level responds to the QRS slopes and not to
  % the P and T waves, and stays aligned with the complex. The detail is
  % squared into an energy, smoothed over one QRS width, and the beats are
  % picked out by the Pan and Tompkins adaptive logic.
  %
  % Input is a column in mV; fiducials come back as 1-based samples, to be
  % snapped to R by the caller.
  refractory = max(1, round(0.2 * rate));
  userRefractory = max(1, round(double(options.Refractory) * rate));
  % 200 ms is the floor between two complexes; a larger user refractory is
  % honoured, a smaller one is not.
  refractory = max(refractory, userRefractory);
  N = numel(signal);
  %===========================================================================
  % Choose the level from the rate so the detail band stays over the QRS: its
  % upper edge lands near 22 Hz, covering roughly the 8 to 22 Hz QRS band,
  % above the P and T waves and below muscle noise.
  wavelet = 'db3';
  level = max(1, round(log2(rate / 22.5)));
  % Run the transform one level past the chosen band so the next lower detail
  % is available too; only those two bands are requested.
  [~, ~, details] = ecgLabSwt(signal, wavelet, level + 1, level);
  %===========================================================================
  % Feature: the squared detail of the chosen band plus 0.35 of the squared
  % detail one octave below, which keeps the detector sensitive to wide
  % ventricular complexes whose energy sits lower. A centered 150 ms moving
  % average merges the detail peaks of one QRS into a single hill.
  lowerBandWeight = 0.35;
  feature = details{level} .^ 2 + lowerBandWeight * details{level + 1} .^ 2;
  integrated = ecgLabQrsMovingAverage(feature, round(0.150 * rate));
  %===========================================================================
  % Candidate peaks: local maxima of the integrated energy at least a
  % refractory period apart.
  candidates = ecgLabQrsLocalMaxima(integrated, refractory);
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(feature, zeros(N, 1), details{level});
    evidence.settings = struct('level', level, 'wavelet', wavelet);
    return;
  end
  candidateValue = integrated(candidates);
  %===========================================================================
  % Adaptive threshold (Pan and Tompkins), seeded from the first two seconds:
  % SPKI from the largest hill, NPKI from the mean. The wavelet band already
  % removes the T wave, so this drops the T-wave slope test and keeps only the
  % refractory test and the search back.
  learn = min(N, round(2 * rate));
  spki = max(integrated(1:learn));
  npki = mean(integrated(1:learn));
  if ~(spki > npki)
    spki = npki + eps;
  end
  % Fraction of the way from the noise level to the signal level. Set to 0.18
  % (below Pan and Tompkins' 0.25) so the wide, low-energy ventricular
  % complexes are not left below the bar.
  coefficient = 0.18;
  threshold1 = npki + coefficient * (spki - npki);
  %===========================================================================
  % One pass over the candidate peaks. The threshold in force is recorded at
  % each candidate so the held series can be rebuilt.
  beats = zeros(numel(candidates), 1);
  beatCount = 0;
  lastBeat = -refractory;
  thrPos = zeros(numel(candidates), 1);
  thrVal = zeros(numel(candidates), 1);
  rr = [];
  for index = 1:numel(candidates)
    here = candidates(index);
    peak = candidateValue(index);
    isBeat = false;
    if peak > threshold1 && (here - lastBeat) > refractory
      isBeat = true;
      spki = 0.125 * peak + 0.875 * spki;
    else
      npki = 0.125 * peak + 0.875 * npki;
    end
    if isBeat
      beatCount = beatCount + 1;
      beats(beatCount) = here;
      if beatCount > 1
        rr(end + 1) = (here - lastBeat) / rate; %#ok<AGROW>
      end
      lastBeat = here;
    end
    threshold1 = npki + coefficient * (spki - npki);
    thrPos(index) = here;
    thrVal(index) = threshold1;
    %=========================================================================
    % Search back: if no beat within 1.66 times the recent average RR, look
    % again over the candidates since the last beat with the threshold halved
    % and take the largest that clears it. The average uses the regular beats
    % only.
    if beatCount >= 2
      rrAverage = ecgLabWaveletRegularAverage(rr);
      limit = round(1.66 * rrAverage * rate);
      if here - lastBeat > limit
        threshold2 = 0.5 * threshold1;
        [found, foundValue] = ecgLabWaveletSearchBack(candidates, ...
        candidateValue, index, lastBeat + refractory, here, threshold2);
        if found > 0
          beatCount = beatCount + 1;
          beats(beatCount) = found;
          rr(end + 1) = (found - lastBeat) / rate; %#ok<AGROW>
          lastBeat = found;
          spki = 0.25 * foundValue + 0.75 * spki;
          threshold1 = npki + coefficient * (spki - npki);
        end
      end
    end
  end
  beats = sort(beats(1:beatCount));
  sample = beats(:);
  %===========================================================================
  % Evidence: the squared detail as the feature, the held threshold as a step
  % function, and the level and wavelet in the settings.
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:numel(candidates)), ...
  thrVal(1:numel(candidates)), N, npki + coefficient * (spki - npki));
  evidence = ecgLabQrsEvidence(feature, thrSeries, details{level});
  evidence.settings = struct('level', level, 'wavelet', wavelet);
end
%=============================================================================
function average = ecgLabWaveletRegularAverage(rr)
  % Mean of the last eight RR intervals, then the mean of those within 92 to
  % 116 per cent of it (Pan and Tompkins RR AVERAGE2).
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
function [found, foundValue] = ecgLabWaveletSearchBack(candidates, values, ...
  upto, lo, hi, threshold2)
  % Largest candidate strictly inside the missed interval that clears the
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
