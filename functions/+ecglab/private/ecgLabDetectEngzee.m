%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, evidence] = ecgLabDetectEngzee(signal, rate, options)
  % Engelse-Zeelenberg (1979), single-scan form of Lourenco et al. (2012). A
  % complex is found by the shape of the differentiated signal: a swing up
  % through an adaptive threshold followed, within 160 ms, by a swing down
  % through its negative. Input is a column in mV; fiducials come back as
  % 1-based samples near R, to be snapped there by the caller. Evidence carries
  % the low-passed derivative y2 and the threshold in force.
  refractory = max(1, round(double(options.Refractory) * rate));
  ms200 = max(refractory, round(0.200 * rate));
  ms1200 = max(ms200 + 1, round(1.200 * rate));
  ms160 = max(1, round(0.160 * rate));
  minWidth = max(1, round(0.010 * rate));
  N = numel(signal);
  x = signal(:);
  %===========================================================================
  % Differentiator y1(n) = x(n) - x(n - d). The paper's four-sample delay at
  % 250 Hz is 16 ms; d is that 16 ms in samples at this rate.
  delay = max(1, round(rate * 4 / 250));
  y1 = x - [zeros(delay, 1); x(1:N - delay)];
  %===========================================================================
  % Binomial low-pass y2 = y1(n) + 4 y1(n-1) + 6 y1(n-2) + 4 y1(n-3) + y1(n-4).
  % Taps are for 250 Hz, spaced by rate/250 to keep the same 16 ms span.
  % Applied forwards only, not zero-phase, so the up-then-down swing order is
  % preserved.
  spacing = max(1, round(rate / 250));
  kernel = zeros(4 * spacing + 1, 1);
  kernel(1:spacing:end) = [1; 4; 6; 4; 1];
  y2 = filter(kernel, 1, y1);
  %===========================================================================
  % Zero the first 200 ms to drop the filter startup transient, so the
  % threshold is not trained on an edge.
  y2(1:min(N, ms200)) = 0;
  %===========================================================================
  % Candidates are the positive peaks of y2 no closer than the refractory
  % period. The scan walks them, adapting M from the last beats and confirming
  % each by the down swing that must follow.
  candidates = ecgLabQrsLocalMaxima(y2, ms200);
  fiveSeconds = min(N, round(5 * rate));
  % Seed M over the first 5 s at 0.48 of the largest up swing there. The mean
  % of the last five beat peaks (MM) starts from the same seed. The fraction is
  % low because the biphasic confirmation, not the level, rejects the T wave.
  seed = 0.48 * max(y2(1:fiveSeconds));
  if ~(seed > 0)
    seed = eps;
  end
  % The down swing is confirmed against its own adaptive level (a fraction of
  % the recent negative troughs), not against -M, so an asymmetric ectopic
  % complex is not missed. The trough seed is the deepest down swing in the
  % first 5 s.
  negCoefficient = 0.20;
  troughSeed = min(y2(1:fiveSeconds));
  if ~(troughSeed < 0)
    troughSeed = -eps;
  end
  if isempty(candidates)
    sample = zeros(0, 1);
    evidence = ecgLabQrsEvidence(y2, repmat(seed, N, 1), x);
    return;
  end
  %===========================================================================
  mmRing = repmat(seed, 5, 1);
  meanMM = seed;
  lastMM = seed;
  nnRing = repmat(troughSeed, 5, 1);
  lastBeat = -ms200;
  heldM = seed;
  beatCount = 0;
  beats = zeros(numel(candidates), 1);
  ms50 = max(1, round(0.050 * rate));
  ms100 = max(1, round(0.100 * rate));
  thrPos = zeros(numel(candidates), 1);
  thrVal = zeros(numel(candidates), 1);
  for index = 1:numel(candidates)
    here = candidates(index);
    %=========================================================================
    % Threshold M: the seed for the first 5 s, then held 200 ms past a beat,
    % decaying linearly to 0.4 of the recent beat level between 200 and 1200 ms
    % and resting there. The low rest lets a premature ectopic complex be caught.
    if here < fiveSeconds
      M = seed;
    elseif beatCount == 0
      M = meanMM;
    else
      dt = here - lastBeat;
      if dt <= ms200
        M = heldM;
      elseif dt < ms1200
        M = meanMM * (1.0 - 0.6 * (dt - ms200) / (ms1200 - ms200));
      else
        M = 0.4 * meanMM;
      end
    end
    thrPos(index) = here;
    thrVal(index) = M;
    %=========================================================================
    % Up swing: the candidate peak must clear M and be a refractory period past
    % the last beat. It is confirmed when, within 160 ms on either side, y2
    % passes the negative threshold and stays past it for at least 10 ms.
    % Checking both sides (not just ahead) also detects an inverted lead. The
    % run length is found by a cumulative sum over the window.
    negThreshold = negCoefficient * mean(nnRing);
    if y2(here) > M && (beatCount == 0 || (here - lastBeat) > ms200)
      lo2 = max(1, here - ms160);
      stop = min(N, here + ms160);
      section = y2(lo2:stop);
      below = section < negThreshold;
      confirmed = false;
      if numel(below) >= minWidth
        cumulative = [0; cumsum(below)];
        runs = cumulative(minWidth + 1:end) - cumulative(1:end - minWidth);
        confirmed = any(runs >= minWidth);
      end
      if confirmed
        % New beat levels: the largest up swing and deepest down swing around
        % this complex, each limited so one large complex cannot move the level
        % by more than a tenth.
        from = max(1, lastBeat);
        newM5 = 0.48 * max(y2(from:here));
        if newM5 > 1.5 * lastMM
          newM5 = 1.1 * lastMM;
        end
        if ~(newM5 > 0)
          newM5 = lastMM;
        end
        mmRing = [mmRing(2:end); newM5];
        meanMM = mean(mmRing);
        lastMM = newM5;
        nnRing = [nnRing(2:end); min(section)];
        heldM = M;
        lastBeat = here;
        % Fiducial: the largest absolute deflection of the raw signal around
        % the swing (the R peak, any polarity). The window spans from just
        % before the up-swing peak into the down swing.
        lo = max(1, here - ms50);
        hi = min(N, here + ms100);
        [~, offset] = max(abs(x(lo:hi)));
        beatCount = beatCount + 1;
        beats(beatCount) = lo + offset - 1;
      end
    end
  end
  beats = beats(1:beatCount);
  sample = sort(beats(:));
  %===========================================================================
  % Rebuild the threshold as a step function so the beat view can draw the M
  % each up swing was compared against.
  thrSeries = ecgLabQrsHoldSeries(thrPos(1:numel(candidates)), ...
  thrVal(1:numel(candidates)), N, seed);
  evidence = ecgLabQrsEvidence(y2, thrSeries, x);
end
%=============================================================================
