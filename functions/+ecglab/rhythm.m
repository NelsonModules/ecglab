%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% RHYTHM = ECGLAB.RHYTHM(X) labels the heart rhythm of X and returns its
% atrial fibrillation episodes.
% RHYTHM = ECGLAB.RHYTHM(X, 'Name', value, ...) sets the window and thresholds.
%
%   X is an ecglab.recording (beats found with ecglab.detect unless 'Beats' is
%   given), an ecglab.beats struct, or a signal vector with its 'Rate' in hertz.
%   The rhythm is read from the RR series, and the P-wave absence when a
%   delineation is passed as 'Waves'.
%
%   A moving window of 'Window' beats is called fibrillation when three
%   conditions hold on its RR series: the coefficient of sample entropy (Lake
%   and Moorman 2011) is above its threshold, the normalised RMSSD is above its
%   threshold, and (with a delineation) the P wave is absent on most beats. Each
%   beat takes the majority label of the windows covering it, and episodes are
%   the maximal runs of one label with short runs smoothed away.
%
%   The thresholds are taken from the literature, not fitted to a test
%   database, and kept in RHYTHM.settings.
%
%   Options (name and value, matched without regard to case):
%     'Beats'        the beats to label, an ecglab.beats struct or a vector of
%                    1-based sample indices; by default ecglab.detect finds
%                    them on a recording or a plain signal vector.
%     'Method'       the detection method when the beats are detected (default
%                    'pantompkins', the detector's own default).
%     'Lead'         the lead to detect on, a name or a column index.
%     'Rate'         the sampling rate in hertz, required when X is a vector.
%     'Window'       the moving window in beats ('auto', the default, is 128,
%                    the window the RR-histogram and entropy detectors use);
%                    capped at the number of beats of a short record.
%     'Step'         the step between windows in beats (default 1).
%     'Waves'        an ecglab.delineate output, so the P-wave absence joins
%                    the RR conditions (default none, the RR series alone).
%     'MinEpisode'   the shortest episode in seconds (default 30): a run
%                    shorter than this is smoothed into its neighbours.
%     'Tolerance'    the sample-entropy tolerance as a fraction of the mean RR
%                    (default 0.1, a common sample-entropy tolerance).
%     'Cosen'        the coefficient-of-sample-entropy threshold (default -1).
%     'Irregularity' the normalised RMSSD threshold (default 0.1).
%     'Pabsent'      the least share of a window's beats with an absent P wave
%                    for the P condition to hold (default 0.5, used only with
%                    'Waves').
%
%   RHYTHM is the rhythm struct of the data model: kind 'ecglab.rhythm',
%   'episodes' (a struct of column vectors 'onset' and 'offset' in seconds and
%   'label' a cellstr in 'N', 'AFIB', 'AFL', 'other' that tile the analysed
%   span), 'perBeat' (a label per beat), 'afBurden' (the share of the analysed
%   time in atrial fibrillation) and 'settings' (every parameter used and the
%   analysed span).
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 90, 'Fibrillation', true);
%     rhythm = ecglab.rhythm(recording);
%     fprintf('AF burden %.2f\n', rhythm.afBurden);
%
%   See also ecglab.detect, ecglab.validate, ecglab.delineate.
function rhythm = rhythm(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Beats', [], 'Method', 'pantompkins', 'Lead', [], ...
  'Rate', [], 'Window', 'auto', 'Step', 1, 'Waves', [], 'MinEpisode', 30, ...
  'Tolerance', 0.1, 'Cosen', -1, 'Irregularity', 0.1, 'Pabsent', 0.5);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % The beats and their times. A recording or a signal has its beats detected
  % unless they are given; a beats or classes struct is taken as is.
  [times, rate] = ecgLabRhythmBeats(X, options);
  nBeats = numel(times);
  % Entropy on fewer than a dozen intervals is noise, so too few beats is
  % refused.
  if nBeats < 12
    error('ecglab:tooShortRecordingHasTooFew', 'The recording has too few beats to label a rhythm.');
  end
  %===========================================================================
  window = ecgLabRhythmWindow(options.Window, nBeats);
  step = ecgLabRhythmStep(options.Step);
  % P-wave absence per beat, from a delineation when given and matched to the
  % beats by time. Without one the P condition is silent.
  [pAbsent, usedWaves] = ecgLabRhythmPwave(times, options.Waves, rate);
  %===========================================================================
  % Each window's fibrillation decision, then the per-beat majority of the
  % windows covering it. The cheap irregularity, mean RR and P-absence share are
  % computed for all windows at once from cumulative sums; the costly entropy
  % runs only on windows that cleared the irregularity (and P) threshold, which
  % cannot change the result since a non-irregular window is never AF.
  rr = diff(times);
  [irregularity, meanRR, pFraction] = ecgLabRhythmWindowStats(rr, pAbsent, ...
  window, step);
  starts = (1:step:(nBeats - window + 1))';
  candidate = meanRR > 0 & irregularity > double(options.Irregularity);
  if usedWaves
    candidate = candidate & pFraction >= double(options.Pabsent);
  end
  windowIsAF = false(numel(starts), 1);
  where = find(candidate);
  for w = where(:)'
    s = starts(w);
    cosen = ecgLabRhythmCosen(rr(s:(s + window - 2)), ...
    double(options.Tolerance), 1);
    windowIsAF(w) = cosen > double(options.Cosen);
  end
  isAF = ecgLabRhythmVote(windowIsAF, starts, window, nBeats);
  %===========================================================================
  % Episodes: maximal runs of one label, runs shorter than MinEpisode smoothed
  % away. The burden is the fibrillation share of the analysed time.
  minEpisode = ecgLabRhythmMinEpisode(options.MinEpisode);
  [episodes, perBeat, afBurden] = ecgLabRhythmEpisodes(isAF, times, ...
  minEpisode);
  %===========================================================================
  rhythm = struct();
  rhythm.kind = 'ecglab.rhythm';
  rhythm.episodes = episodes;
  rhythm.perBeat = perBeat;
  rhythm.afBurden = afBurden;
  rhythm.settings = struct('window', window, 'windowOption', options.Window, ...
  'step', step, 'tolerance', double(options.Tolerance), ...
  'cosen', double(options.Cosen), 'irregularity', double(options.Irregularity), ...
  'pabsent', double(options.Pabsent), 'minEpisode', minEpisode, 'm', 1, ...
  'usedWaves', usedWaves, 'rate', rate, 'nBeats', nBeats, ...
  'span', [times(1), times(end)]);
end
%=============================================================================
function [times, rate] = ecgLabRhythmBeats(X, options)
  % The beat times in seconds and the rate. Given beats are taken as is;
  % otherwise a recording or signal vector is detected on with the default method.
  if ~isempty(options.Beats)
    beats = ecgLabRhythmNormaliseBeats(options.Beats, options.Rate, X);
    times = beats.time;
    rate = beats.rate;
    return;
  end
  if isstruct(X) && isfield(X, 'kind') && ...
    any(strcmp(X.kind, {'ecglab.beats', 'ecglab.classes'}))
    beats = ecgLabRhythmNormaliseBeats(X, options.Rate, X);
    times = beats.time;
    rate = beats.rate;
    return;
  end
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    beats = ecglab.detect(X, 'Method', options.Method, 'Lead', options.Lead);
    times = beats.time;
    rate = double(X.rate);
    return;
  end
  if isnumeric(X) && isvector(X) && ~isempty(X)
    if isempty(options.Rate)
      error('ecglab:needRateSignalVectorNeedsIts', 'A signal vector needs its sampling rate, given as Rate.');
    end
    beats = ecglab.detect(X, 'Rate', options.Rate, 'Method', options.Method);
    times = beats.time;
    rate = double(options.Rate);
    return;
  end
  error('ecglab:notASignalXEcglabRecordingEcglab', 'X must be an ecglab.recording, an ecglab.beats struct or a signal vector.');
end
%=============================================================================
function beats = ecgLabRhythmNormaliseBeats(given, rateOption, X)
  % Turn given beats (a beats struct, a classes result or a vector of sample
  % indices) into a sorted time series and a rate.
  rate = [];
  if isstruct(given) && isfield(given, 'rate') && ~isempty(given.rate)
    rate = double(given.rate);
  end
  if isempty(rate) && isstruct(given) && isfield(given, 'settings') && ...
    isstruct(given.settings) && isfield(given.settings, 'Rate')
    rate = double(given.settings.Rate);
  end
  if isempty(rate) && isstruct(X) && isfield(X, 'kind') && ...
    strcmp(X.kind, 'ecglab.recording')
    rate = double(X.rate);
  end
  if isempty(rate) && ~isempty(rateOption)
    rate = double(rateOption);
  end
  if isstruct(given)
    if ~isfield(given, 'sample')
      error('ecglab:noSampleBeatsStructCarrySample', 'The beats struct must carry a sample field.');
    end
    sample = round(double(given.sample(:)));
    if isfield(given, 'time') && numel(given.time) == numel(sample)
      time = double(given.time(:));
    elseif ~isempty(rate)
      time = (sample - 1) / rate;
    else
      error('ecglab:rateNeededSamplingRateNeededPlace', 'A sampling rate is needed to place the beats, given as Rate.');
    end
  elseif isnumeric(given) && isvector(given)
    if isempty(rate)
      error('ecglab:rateNeededSamplingRateNeededPlace', 'A sampling rate is needed to place the beats, given as Rate.');
    end
    time = (round(double(given(:))) - 1) / rate;
  else
    error('ecglab:badBeatsBeatsEcglabBeatsStruct', 'Beats must be an ecglab.beats struct or a vector of sample indices.');
  end
  time = sort(time);
  if isempty(rate)
    rate = NaN;
  end
  beats = struct('time', time, 'rate', rate);
end
%=============================================================================
function window = ecgLabRhythmWindow(value, nBeats)
  % The moving window in beats. 'auto' is 128; a number is taken as given,
  % capped at the beat count so there is always one full window.
  if ischar(value) || isStringScalar(value)
    if ~strcmpi(char(value), 'auto')
      error('ecglab:badWindowWindowAutoNumberBeats2', 'Window is ''auto'' or a number of beats.');
    end
    window = 128;
  elseif isnumeric(value) && isscalar(value) && value >= 4 && isfinite(value)
    window = round(double(value));
  else
    error('ecglab:badWindowWindowAutoNumberBeats', 'Window is ''auto'' or a number of beats of at least four.');
  end
  window = min(window, nBeats);
end
%=============================================================================
function step = ecgLabRhythmStep(value)
  if ~isnumeric(value) || ~isscalar(value) || value < 1 || ~isfinite(value)
    error('ecglab:badStep', 'Step is a whole number of beats of at least one.');
  end
  step = round(double(value));
end
%=============================================================================
function minEpisode = ecgLabRhythmMinEpisode(value)
  if ~isnumeric(value) || ~isscalar(value) || value < 0 || ~isfinite(value)
    error('ecglab:badMinEpisode', 'MinEpisode is a number of seconds of at least zero.');
  end
  minEpisode = double(value);
end
%=============================================================================
function [pAbsent, usedWaves] = ecgLabRhythmPwave(times, waves, rate)
  % Whether each beat lacks a P wave, from a delineation when given. Each beat
  % is matched to the nearest delineated beat within the matching window; one
  % with no P onset or peak there has an absent P.
  nBeats = numel(times);
  pAbsent = false(nBeats, 1);
  usedWaves = false;
  if isempty(waves)
    return;
  end
  if ~isstruct(waves) || ~isfield(waves, 'kind') || ...
    ~strcmp(waves.kind, 'ecglab.waves')
    error('ecglab:badWaves', 'Waves must be an ecglab.delineate output.');
  end
  usedWaves = true;
  if isfield(waves, 'time') && ~isempty(waves.time)
    waveTime = double(waves.time);
  else
    waveTime = (double(waves.sample) - 1) / rate;
  end
  % The R time of each delineated beat is its matching key; the P is present
  % when either its onset or its peak was placed.
  rTime = waveTime(:, 6);
  missing = ~isfinite(rTime);
  rTime(missing) = waveTime(missing, 4);
  pPresentWave = isfinite(waveTime(:, 1)) | isfinite(waveTime(:, 2));
  % Only beats with a usable key can be matched; unique sorts them and drops
  % coincident keys so the nearest-neighbour search is one vectorised interp1.
  usable = isfinite(rTime);
  [rTime, keep] = unique(rTime(usable));
  usableIndex = find(usable);
  pPresentWave = pPresentWave(usableIndex(keep));
  if isempty(rTime)
    return;
  end
  nearest = ecgLabRhythmNearest(rTime, times(:));
  matchWindow = 0.15;
  within = abs(rTime(nearest) - times(:)) <= matchWindow;
  pAbsent(within) = ~pPresentWave(nearest(within));
end
%=============================================================================
function idx = ecgLabRhythmNearest(sorted, query)
  % Index into SORTED (ascending, unique) of the value nearest each QUERY, for
  % all queries at once via interp1 with nearest rounding and extrapolation.
  n = numel(sorted);
  if n == 1
    idx = ones(size(query));
    return;
  end
  idx = interp1(sorted, (1:n)', query, 'nearest', 'extrap');
  idx = max(1, min(n, round(idx)));
end
%=============================================================================
function isAF = ecgLabRhythmVote(windowIsAF, starts, window, nBeats)
  % The per-beat label is the majority of the windows covering it. Each window
  % votes over the span of beats it covers; the votes are pooled with a
  % difference array and one cumulative sum, with no loop over beats.
  if isempty(starts)
    isAF = false(nBeats, 1);
    return;
  end
  ends = starts + window - 1;
  edges = nBeats + 1;
  deltaTotal = accumarray(starts, 1, [edges, 1]) - ...
  accumarray(ends + 1, 1, [edges, 1]);
  deltaAF = accumarray(starts, double(windowIsAF), [edges, 1]) - ...
  accumarray(ends + 1, double(windowIsAF), [edges, 1]);
  totalVotes = cumsum(deltaTotal);
  afVotes = cumsum(deltaAF);
  totalVotes = totalVotes(1:nBeats);
  afVotes = afVotes(1:nBeats);
  % Guard keeps the ratio defined for a beat no window covered (none can here).
  isAF = afVotes > 0 & (2 * afVotes >= totalVotes);
end
%=============================================================================
