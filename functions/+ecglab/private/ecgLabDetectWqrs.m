%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectWqrs(signal, rate, options)
  % Zong, Moody and Jiang (2003), the curve length transform detector of the
  % WFDB suite. It annotates the QRS onset, not the peak; the dispatcher snaps
  % the returned fiducial to R. The onset and J point of every beat are kept in
  % the evidence for the delineator.
  %
  % Input is a column in mV. The reference's decision constants are expressed
  % in A/D units at the standard gain of 200 units per mV, so the signal is
  % scaled by that gain here to give each constant its published meaning.
  refGain = 200;
  scaled = refGain * signal(:);
  N = numel(scaled);
  %===========================================================================
  % Low-pass: two cascaded moving sums of length LPn (one mains period, capped
  % at 8), giving a notch at the mains frequency and a 16 Hz low-pass. Applied
  % zero-phase by convolving centered with the triangular kernel
  % ones(LPn)*ones(LPn), so the onset is not delayed.
  LPn = min(8, max(1, round(rate / 50)));
  LP2n = 2 * LPn;
  triangular = conv(ones(LPn, 1), ones(LPn, 1));
  lowpassed = conv(scaled, triangular, 'same');
  %===========================================================================
  % Curve length transform. Per-sample length element et = sqrt(lengthScale +
  % dy^2) with dy the low-pass derivative; lengthScale is the reference's
  % amplitude floor, scaled to a twentieth of its value here to restore the
  % baseline-to-QRS separation at the native rate (where resampling is barred).
  % The length signal L is a trailing moving sum of et over one QRS width
  % (130 ms), so L crosses the threshold upward at the complex onset. Computed
  % as the difference of a cumulative sum a window apart.
  lengthScale = 0.050 * (1.25 * refGain * refGain / rate);
  dy = [0; diff(lowpassed)] / LP2n;
  element = sqrt(lengthScale + dy .^ 2);
  ltWindow = max(1, round(0.130 * rate));
  cumulative = [0; cumsum(element)];
  upper = (1:N)';
  lower = max(upper - ltWindow, 0);
  L = cumulative(upper + 1) - cumulative(lower + 1);
  %===========================================================================
  % Filtered trace in mV for the beat view and the fiducial: the low-pass
  % output divided by its DC gain LPn^2 and by the scaling gain.
  filteredMv = lowpassed / (LPn * LPn * refGain);
  %===========================================================================
  % Eye-closing period (250 ms): the hard lock-out floor after a detection. The
  % actual lock-out below is taken as half the recent RR once a rhythm is
  % known, which covers the T wave on a slow rhythm but shrinks on a fast one.
  % Expect period (2.5 s): how long the threshold waits with no detection
  % before it falls. Candidate peaks of L are its local maxima 200 ms apart.
  userRefractory = max(1, round(double(options.Refractory) * rate));
  eyeClosing = max(round(0.250 * rate), userRefractory);
  halfEye = max(1, round(eyeClosing / 2));
  expectPeriod = round(2.5 * rate);
  candidateGap = max(1, round(0.200 * rate));
  candidates = ecgLabQrsLocalMaxima(L, candidateGap);
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(L, zeros(N, 1), filteredMv);
    evidence.onset = zeros(0, 1);
    evidence.jpoint = zeros(0, 1);
    return;
  end
  %===========================================================================
  % Thresholds seeded from the first 8 s: T0 is the mean of L, Ta (running peak
  % estimate) starts at 3 * T0, and the operating threshold is Ta / 3. After
  % each beat Ta is pulled a tenth toward the peak just seen; between beats,
  % past the expect period, Ta decays toward the floor taFloor (100 microvolt).
  learn = min(N, round(8 * rate));
  T0 = mean(L(1:learn));
  taFloor = 0.100 * refGain;
  taBeat = 3 * T0;
  lastBeat = [];
  lastPeak = 0;
  recentRr = zeros(0, 1);
  %===========================================================================
  % One pass over the candidate peaks. Each window operation inside the loop
  % spans at most half an eye-closing period.
  beatOnset = zeros(numel(candidates), 1);
  beatPeak = zeros(numel(candidates), 1);
  beatJpoint = zeros(numel(candidates), 1);
  beatCount = 0;
  thrPos = zeros(numel(candidates), 1);
  thrVal = zeros(numel(candidates), 1);
  evalCount = 0;
  for index = 1:numel(candidates)
    here = candidates(index);
    peak = L(here);
    % Lock-out in two parts. The eye-closing is a hard refractory: no two beats
    % closer than 250 ms. Beyond it, up to a window set by the recent rhythm, a
    % candidate is skipped as the last beat's T wave only when its length is
    % below four fifths of that beat's; a genuine early beat is wide and keeps
    % a length at or above the last beat's.
    if ~isempty(lastBeat)
      gap = here - lastBeat;
      if gap < eyeClosing
        continue;
      end
      if numel(recentRr) >= 2
        tWaveWindow = max(eyeClosing, round(0.6 * ecgLabWqrsMedian(recentRr)));
      else
        tWaveWindow = round(0.500 * rate);
      end
      if gap < tWaveWindow && peak < 0.8 * lastPeak
        continue;
      end
    end
    % Threshold in force: Ta decayed for any silence beyond the expect period,
    % then divided by three.
    taEffective = taBeat;
    if ~isempty(lastBeat)
      gap = here - lastBeat;
      if gap > expectPeriod
        taEffective = max(taFloor, taBeat - (gap - expectPeriod));
      end
    end
    threshold1 = taEffective / 3;
    isBeat = false;
    if peak > threshold1
      % A real QRS rises more than 10 length units above the valley just before
      % the peak, which rejects a flat ripple that merely clears the threshold.
      lo = max(1, here - halfEye);
      valley = min(L(lo:here));
      if peak > valley + 10
        isBeat = true;
      end
    end
    if isBeat
      beatCount = beatCount + 1;
      % Onset: the knee at the foot of the rise, where four consecutive
      % backward differences each fall below peak/100 + 2. The search runs over
      % the rising limb only, up to the threshold crossing, so the flat top of
      % L is not mistaken for the foot. The latest such knee is the onset.
      onsetSlope = peak / 100 + 2;
      lo = max(1, here - eyeClosing);
      window = L(lo:here);
      crossRel = find(window > threshold1, 1, 'first');
      if isempty(crossRel)
        crossRel = numel(window);
      end
      rise = [inf; diff(window)];
      flat = rise < onsetSlope;
      four = flat & [false; flat(1:end - 1)] & ...
      [false; false; flat(1:end - 2)] & [false; false; false; flat(1:end - 3)];
      four(crossRel:end) = false;
      knee = find(four, 1, 'last');
      if isempty(knee)
        onset = max(1, here - 5);
      else
        onset = lo + knee - 1;
      end
      beatOnset(beatCount) = onset;
      % J point: where L falls back below nine tenths of the peak, scanning
      % forward from the peak so it lands after the QRS.
      hiJ = min(N, here + halfEye);
      below = find(L(here:hiJ) < 0.9 * peak, 1, 'first');
      if isempty(below)
        beatJpoint(beatCount) = min(N, here + 5);
      else
        beatJpoint(beatCount) = here + below - 1;
      end
      % Fiducial: the largest absolute deflection of the filtered trace in the
      % first 80 ms after the onset, which the dispatcher snaps to R. The
      % window ends before the S so the larger smoothed S lobe is not picked.
      hiF = min(N, onset + round(0.080 * rate));
      [~, where] = max(abs(filteredMv(onset:hiF)));
      beatPeak(beatCount) = onset + where - 1;
      % Pull Ta a tenth of the way toward this peak.
      taBeat = taEffective + (peak - taEffective) / 10;
      % Keep the last eight RR intervals, which drive the lock-out window.
      if ~isempty(lastBeat)
        recentRr(end + 1) = here - lastBeat; %#ok<AGROW>
        if numel(recentRr) > 8
          recentRr = recentRr(end - 7:end);
        end
      end
      lastBeat = here;
      lastPeak = peak;
    end
    % Record the threshold only at candidates actually evaluated, not those
    % skipped during the lock-out, to keep the positions monotonic for the
    % held-series builder.
    evalCount = evalCount + 1;
    thrPos(evalCount) = here;
    thrVal(evalCount) = taEffective / 3;
  end
  %===========================================================================
  sample = sort(beatPeak(1:beatCount));
  sample = sample(:);
  onsetSeries = sort(beatOnset(1:beatCount));
  jpointSeries = sort(beatJpoint(1:beatCount));
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:evalCount), ...
  thrVal(1:evalCount), N, T0);
  evidence = ecgLabQrsEvidence(L, thrSeries, filteredMv);
  % Onset and J point, one per beat, ordered with the samples so the delineator
  % can pair them beat by beat.
  evidence.onset = onsetSeries(:);
  evidence.jpoint = jpointSeries(:);
end
%=============================================================================
function value = ecgLabWqrsMedian(x)
  % Median of the recent RR intervals, by sorting and reading the middle rather
  % than calling median, which is faster here.
  s = sort(x(:));
  count = numel(s);
  middle = floor((count + 1) / 2);
  if mod(count, 2) == 1
    value = s(middle);
  else
    value = 0.5 * (s(middle) + s(middle + 1));
  end
end
%=============================================================================
