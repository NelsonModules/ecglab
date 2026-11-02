%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [times, classes, hasP, isV, rhythm] = ecgLabSimulatePlan(options, rate)
  % When and what each beat is, before any waveform: the RR series, R peak
  % times, beat class, and whether the beat has a P wave. Reproducible, since
  % every random draw is inside the caller's seeded region.
  rrmean = 60 / double(options.HeartRate);
  % Enough beats to cover the recording with a margin, as a power of two for
  % the inverse FFT of the RR spectrum.
  need = ceil(double(options.Seconds) / rrmean) + 8;
  n = 2 ^ max(8, ceil(log2(2 * need)));
  if options.Fibrillation
    % Atrial fibrillation: irregular RR with a coefficient of variation of
    % about 0.2, the ventricular response to fibrillation.
    rr = rrmean * (1 + 0.2 * randn(n, 1));
    rr = max(rr, 0.25 * rrmean);
  else
    rr = ecgLabSimulateRr(double(options.HeartRate), ...
    double(options.HeartRateStd), n, 1);
  end
  % Place R peaks by the cumulative sum of intervals, keeping those inside the
  % recording. The first beat sits one interval in, leaving room for its P wave.
  times = cumsum(rr);
  times = times(times > 0 & times <= double(options.Seconds));
  beatCount = numel(times);
  if beatCount < 2
    error('ecglab:badSecondsRecordingTooShortHold2', 'The recording is too short to hold two beats.');
  end
  classes = repmat('N', beatCount, 1);
  hasP = true(beatCount, 1);
  isV = false(beatCount, 1);
  if options.Fibrillation
    % Fibrillation conducts normally: narrow sinus complexes, but with no P
    % wave and at irregular intervals.
    rhythm = 'AFIB';
    hasP(:) = false;
    return;
  end
  rhythm = 'N';
  if options.Ectopic > 0
    % Make a fraction of interior beats premature ventricular. Moving the R
    % earlier while the next beat stays on schedule gives the PVC and its
    % compensatory pause.
    wanted = round(options.Ectopic * beatCount);
    candidate = 2:(beatCount - 1);
    wanted = min(wanted, numel(candidate));
    if wanted > 0
      % No two ectopic beats are adjacent: a run of them is ventricular
      % tachycardia, a different rhythm, and would break the early-beat,
      % long-pause pattern.
      order = randperm(numel(candidate));
      taken = false(beatCount, 1);
      chosen = [];
      for pick = 1:numel(order)
        here = candidate(order(pick));
        if ~taken(here - 1) && ~taken(here) && ~taken(here + 1)
          chosen(end + 1) = here;
          taken(here) = true;
        end
        if numel(chosen) >= wanted
          break;
        end
      end
      chosen = sort(chosen);
      isV(chosen) = true;
      classes(chosen) = 'V';
      hasP(chosen) = false;
      for index = 1:numel(chosen)
        here = chosen(index);
        times(here) = times(here) - 0.30 * (times(here) - times(here - 1));
      end
    end
  end
end
%=============================================================================
