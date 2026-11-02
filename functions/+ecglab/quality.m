%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% QUALITY = ECGLAB.QUALITY(X) judges the signal quality of X per window.
% QUALITY = ECGLAB.QUALITY(X, 'Name', value, ...) sets the windows and rules.
%
%   X is an ecglab.recording (the lead named by 'Lead' is judged, the first
%   ECG-like lead by default) or a plain signal vector in millivolts whose
%   'Rate' in hertz is given. The signal is cut into windows of 'Window' seconds
%   stepped by 'Step' seconds, and each window gets a set of quality indices and
%   a verdict.
%
%   The indices, each named with its source (survey 5.9):
%     bsqi   (Li, Mark and Clifford 2008) the F1 agreement of two QRS detectors,
%            2 M / (n1 + n2) for M beats matched within 'MatchWindow'.
%     ksqi   the kurtosis of the window (a clean ECG is peaky, noise near 3).
%     psqi   the share of spectral power in 5 to 15 Hz over 5 to 40 Hz.
%     bassqi the share of power above 1 Hz over the whole (wander sits below).
%     orphanidou (Orphanidou et al. 2015) a logical: heart rate 40 to 180, no RR
%            over 3 s, longest-over-shortest RR under 2.2, mean beat-to-template
%            correlation over 0.66.
%     zhao   (Zhao and Zhang 2018) the fusion of ksqi, psqi and bassqi into
%            'Excellent', 'Barely acceptable' or 'Unacceptable'.
%
%   Options (name and value, matched without regard to case):
%     'Lead'          the lead to judge, a name or a column index. Default the
%                     first of MLII, II, I, V5, or the first lead.
%     'Rate'          sampling rate in hertz, required when X is a vector.
%     'Window'        window length in seconds (default 10).
%     'Step'          step between windows in seconds (default the window, so
%                     the windows do not overlap; a smaller step overlaps).
%     'MatchWindow'   the bSQI match tolerance in seconds (default 0.15).
%     'Detectors'     the two detectors bSQI compares, of different families
%                     (default {'pantompkins', 'wqrs'}); the first is also the
%                     one the Orphanidou rules read.
%     'BsqiThreshold' the least bSQI an acceptable window must reach on the
%                     bSQI rule (default 0.9).
%     'Rule'          what 'acceptable' means: 'bsqi' (bsqi >= BsqiThreshold),
%                     'orphanidou', 'both' (default) or 'zhao' (not
%                     Unacceptable).
%
%   QUALITY is a struct: kind 'ecglab.quality', window, step, time (the centre
%   of each window in seconds), bsqi, ksqi, psqi, bassqi (a value per window),
%   orphanidou (a logical per window), zhao (a label per window), acceptable
%   (a logical per window), usableFraction (the share of acceptable windows),
%   good (the longest acceptable stretch in seconds), and settings.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 120, 'Noise', 0.05, 'Seed', 1);
%     q = ecglab.quality(recording);
%     fprintf('%.0f%% usable\n', 100 * q.usableFraction);
%
%   See also ecglab.detect, ecglab.simulate, ecglab.validate.
function quality = quality(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Lead', [], 'Rate', [], 'Window', 10, 'Step', [], ...
  'MatchWindow', 0.15, 'Detectors', {{'pantompkins', 'wqrs'}}, ...
  'BsqiThreshold', 0.9, 'Rule', 'both');
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  [signal, rate, leadName] = ecgLabQualitySignal(X, options);
  windowSeconds = ecgLabQualityPositive(options.Window, 'window length');
  stepSeconds = ecgLabQualityStep(options.Step, windowSeconds);
  matchWindow = ecgLabQualityPositive(options.MatchWindow, ...
  'bSQI match tolerance');
  detectors = ecgLabQualityDetectors(options.Detectors);
  rule = ecgLabQualityRule(options.Rule);
  threshold = ecgLabQualityThreshold(options.BsqiThreshold);
  %===========================================================================
  % The window layout: a window is wlen samples, the next begins step samples
  % on. A record shorter than one window is an error, not an empty result.
  wlen = max(1, round(windowSeconds * rate));
  step = max(1, round(stepSeconds * rate));
  N = numel(signal);
  if N < wlen
    error('ecglab:tooShortSignalShorterThanOne', 'The signal is shorter than one window.');
  end
  starts = (1:step:(N - wlen + 1))';
  W = numel(starts);
  % The centre of a window is its first sample's time plus half the window.
  centre = (starts - 1) / rate + windowSeconds / 2;
  %===========================================================================
  % Run each of the two detectors once over the whole signal; their beats are
  % split into windows below. The first detector feeds the Orphanidou rules.
  beats1 = ecglab.detect(signal, 'Rate', rate, 'Method', detectors{1});
  beats2 = ecglab.detect(signal, 'Rate', rate, 'Method', detectors{2});
  sample1 = beats1.sample;
  time1 = beats1.time;
  time2 = beats2.time;
  %===========================================================================
  % One pass over the windows. For each: the bSQI from the two detectors' beats
  % in it, the three spectral indices, the Orphanidou verdict, the Zhao label.
  bsqi = zeros(W, 1);
  ksqi = zeros(W, 1);
  psqi = zeros(W, 1);
  bassqi = zeros(W, 1);
  orphanidou = false(W, 1);
  zhao = cell(W, 1);
  for w = 1:W
    lo = starts(w);
    hi = lo + wlen - 1;
    loTime = (lo - 1) / rate;
    hiTime = (hi - 1) / rate;
    in1 = time1 >= loTime & time1 <= hiTime;
    in2 = time2 >= loTime & time2 <= hiTime;
    bsqi(w) = ecgLabQualityBsqi(time1(in1), time2(in2), matchWindow);
    segment = signal(lo:hi);
    [ksqi(w), psqi(w), bassqi(w)] = ecgLabQualitySpectral(segment, rate);
    orphanidou(w) = ecgLabQualityOrphanidou(sample1(in1), signal, rate);
    zhao{w} = ecgLabQualityZhao(ksqi(w), psqi(w), bassqi(w));
  end
  %===========================================================================
  acceptable = ecgLabQualityAcceptable(rule, bsqi, threshold, orphanidou, zhao);
  usableFraction = mean(double(acceptable));
  good = ecgLabQualityLongest(acceptable, starts, wlen, rate);
  %===========================================================================
  quality = struct();
  quality.kind = 'ecglab.quality';
  quality.window = windowSeconds;
  quality.step = stepSeconds;
  quality.time = centre;
  quality.bsqi = bsqi;
  quality.ksqi = ksqi;
  quality.psqi = psqi;
  quality.bassqi = bassqi;
  quality.orphanidou = orphanidou;
  quality.zhao = zhao;
  quality.acceptable = acceptable;
  quality.usableFraction = usableFraction;
  quality.good = good;
  quality.settings = struct('Window', windowSeconds, 'Step', stepSeconds, ...
  'MatchWindow', matchWindow, 'Detectors', {detectors}, ...
  'BsqiThreshold', threshold, 'Rule', rule, 'Lead', leadName, 'Rate', rate);
end
%=============================================================================
function [signal, rate, leadName] = ecgLabQualitySignal(X, options)
  % A recording gives up one lead; a plain vector is the signal and needs its
  % rate. The default lead is the first of MLII, II, I, V5, else the first lead.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    rate = X.rate;
    column = ecgLabQualityLead(X, options.Lead);
    signal = double(X.samples(:, column));
    leadName = X.leads{column};
    return;
  end
  if isnumeric(X) && isvector(X) && ~isempty(X)
    if isempty(options.Rate)
      error('ecglab:needRateSignalVectorNeedsIts', 'A signal vector needs its sampling rate, given as Rate.');
    end
    rate = double(options.Rate);
    if ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
      error('ecglab:badRateSamplingRateOnePositive', 'The sampling rate must be one positive number of hertz.');
    end
    signal = double(X(:));
    leadName = '';
    return;
  end
  error('ecglab:notASignalXEcglabRecordingSignal', 'X must be an ecglab.recording or a signal vector with a Rate.');
end
%=============================================================================
function column = ecgLabQualityLead(recording, lead)
  leads = recording.leads;
  if isempty(lead)
    preferred = {'MLII', 'II', 'I', 'V5'};
    for index = 1:numel(preferred)
      match = find(strcmpi(preferred{index}, leads), 1);
      if ~isempty(match)
        column = match;
        return;
      end
    end
    column = 1;
    return;
  end
  if ischar(lead) || isStringScalar(lead)
    name = char(lead);
    match = find(strcmpi(name, leads), 1);
    if isempty(match)
      error('ecglab:unknownLeadRecordingHasNoLead', 'The recording has no lead named %s.', name);
    end
    column = match;
    return;
  end
  if isnumeric(lead) && isscalar(lead)
    column = round(double(lead));
    if column < 1 || column > numel(leads)
      error('ecglab:unknownLeadLeadIndexDOutside', 'The lead index %d is outside the %d leads.', column, numel(leads));
    end
    return;
  end
  error('ecglab:badLeadLeadNameColumnIndex', 'The lead must be a name or a column index.');
end
%=============================================================================
function value = ecgLabQualityPositive(given, what)
  if ~isnumeric(given) || ~isscalar(given) || ~(given > 0) || ~isfinite(given)
    error('ecglab:badOptionSOnePositiveNumber', 'The %s must be one positive number of seconds.', what);
  end
  value = double(given);
end
%=============================================================================
function value = ecgLabQualityStep(given, windowSeconds)
  % No step, or 'Window', tiles the windows without overlap (step = window). A
  % number is the step in seconds.
  if isempty(given)
    value = windowSeconds;
    return;
  end
  if (ischar(given) || isStringScalar(given)) && strcmpi(char(given), 'Window')
    value = windowSeconds;
    return;
  end
  value = ecgLabQualityPositive(given, 'step');
end
%=============================================================================
function detectors = ecgLabQualityDetectors(given)
  % bSQI compares exactly two detectors, checked against those that exist;
  % 'consensus' is refused, being a pooling, not a single detector.
  if ischar(given) || isStringScalar(given)
    given = {char(given)};
  end
  if ~iscell(given) || numel(given) ~= 2
    error('ecglab:badDetectors', 'Detectors must be a list of two detector names.');
  end
  [known, ~] = ecgLabDetectMethods();
  detectors = cell(1, 2);
  for index = 1:2
    name = lower(char(given{index}));
    if strcmp(name, 'consensus') || ~any(strcmp(name, known))
      error('ecglab:unknownMethod', 'Unknown detection method: %s.', name);
    end
    detectors{index} = name;
  end
end
%=============================================================================
function rule = ecgLabQualityRule(given)
  if ~ischar(given) && ~isStringScalar(given)
    error('ecglab:unknownRule', 'The rule must be bsqi, orphanidou, both or zhao.');
  end
  rule = lower(char(given));
  if ~any(strcmp(rule, {'bsqi', 'orphanidou', 'both', 'zhao'}))
    error('ecglab:unknownRule', 'The rule must be bsqi, orphanidou, both or zhao.');
  end
end
%=============================================================================
function value = ecgLabQualityThreshold(given)
  if ~isnumeric(given) || ~isscalar(given) || ~isfinite(given)
    error('ecglab:badThreshold', 'The bSQI threshold must be one number.');
  end
  value = double(given);
end
%=============================================================================
function acceptable = ecgLabQualityAcceptable(rule, bsqi, threshold, ...
  orphanidou, zhao)
  % The verdict per window from the chosen rule. 'both' (default) requires
  % detector agreement and physiology; the single rules use one index alone.
  switch rule
    case 'bsqi'
      acceptable = bsqi >= threshold;
    case 'orphanidou'
      acceptable = orphanidou;
    case 'both'
      acceptable = (bsqi >= threshold) & orphanidou;
    case 'zhao'
      acceptable = ~strcmp(zhao, 'Unacceptable');
      acceptable = acceptable(:);
  end
end
%=============================================================================
function good = ecgLabQualityLongest(acceptable, starts, wlen, rate)
  % The longest run of consecutive acceptable windows, as the time from the
  % start of its first window to the end of its last.
  good = 0;
  runStart = 0;
  inRun = false;
  for w = 1:numel(acceptable)
    if acceptable(w) && ~inRun
      runStart = w;
      inRun = true;
    end
    if inRun && (w == numel(acceptable) || ~acceptable(w + 1))
      spanSamples = (starts(w) + wlen) - starts(runStart);
      good = max(good, spanSamples / rate);
      inRun = false;
    end
  end
end
%=============================================================================
