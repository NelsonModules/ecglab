%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% BEATS = ECGLAB.DETECT(X) detects the heart beats in X.
% BEATS = ECGLAB.DETECT(X, 'Name', value, ...) sets the method and its options.
%
%   X is an ecglab.recording (one lead is chosen) or a plain signal vector in
%   millivolts whose 'Rate' in hertz is given. BEATS is the beats struct of the
%   data model: kind 'ecglab.beats', sample (K x 1, 1-based), time (seconds), rr
%   (K x 1 seconds, NaN on the first), method, lead, the settings used, and an
%   evidence struct carrying the series the method thresholded.
%
%   Each method is a private function ecgLabDetect<Name> returning the fiducial
%   samples and evidence from a signal and a rate; adding such a file adds a
%   method. The available methods are discovered at call time.
%
%   Every method's beats are snapped to the extremum of the 5 to 15 Hz
%   band-passed signal near its fiducial, in the chosen polarity, so the RR
%   series is comparable across methods. 'consensus' runs several methods and
%   keeps a beat only where enough of them agree.
%
%   Options (name and value, matched without regard to case):
%     'Method'      detector name (default 'pantompkins'), 'hamilton',
%                   'consensus', or any other private detector that exists.
%     'Lead'        the lead to read, a name or a column index. Default the
%                   first of MLII, II, I, V5, or the first lead.
%     'Rate'        sampling rate in hertz, required when X is a plain vector.
%     'Refractory'  shortest interval between two beats, in seconds
%                   (default 0.2).
%     'Polarity'    'auto' (default: the sign of the skewness of the
%                   band-passed signal), 'positive' or 'negative'.
%     'Snap'        true (default) snaps each beat to the R peak within 60 ms.
%     'Methods'     for consensus, the list of methods (default all available).
%     'Votes'       for consensus, the least number of methods that must agree
%                   (default the majority).
%     'Window'      for consensus, the clustering gap in seconds (default 0.06).
%
%   Example:
%     recording = ecglab.simulate('Seconds', 30, 'Seed', 1);
%     beats = ecglab.detect(recording, 'Method', 'pantompkins');
%     bpm = 60 / median(beats.rr, 'omitnan');
%
%   See also ecglab.simulate, ecglab.validate, ecglab.delineate.
function beats = detect(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Method', 'pantompkins', 'Lead', [], 'Rate', [], ...
  'Refractory', 0.2, 'Polarity', 'auto', 'Snap', true, 'Methods', [], ...
  'Votes', [], 'Window', 0.06);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % The signal, its rate and the name of the lead it came from. A recording
  % carries its own rate and lead names; a plain vector needs its rate given.
  [signal, rate, leadName] = ecgLabDetectSignal(X, options);
  if numel(signal) < round(3 * rate)
    % Three seconds: the two-second threshold learning plus a beat after it.
    error('ecglab:tooShortSignalShorterThanThree', 'The signal is shorter than three seconds.');
  end
  ecgLabDetectCheckRefractory(options.Refractory);
  polarity = ecgLabDetectPolarity(options.Polarity);
  %===========================================================================
  % The 5 to 15 Hz snap filter, computed once for every method so all beats move
  % to the same R peak. Its skewness also decides the auto polarity.
  snapFiltered = ecgLabQrsBandpass(signal, rate, 5, 15, 3);
  polaritySign = ecgLabDetectPolaritySign(polarity, snapFiltered);
  %===========================================================================
  [known, ~] = ecgLabDetectMethods();
  method = lower(char(options.Method));
  if strcmp(method, 'consensus')
    beats = ecgLabDetectConsensus(signal, rate, options, known, ...
    snapFiltered, polaritySign, leadName, polarity);
  elseif any(strcmp(method, known))
    [fiducials, evidence] = feval(['ecgLabDetect', ...
    ecgLabDetectCapitalise(method)], signal, rate, options);
    sample = ecgLabDetectSnap(fiducials, snapFiltered, rate, polaritySign, ...
    options.Snap);
    beats = ecgLabDetectBuild(sample, rate, method, leadName, options, ...
    polarity, evidence);
  else
    error('ecglab:unknownMethod', 'Unknown detection method: %s.', method);
  end
end
%=============================================================================
function [signal, rate, leadName] = ecgLabDetectSignal(X, options)
  % A recording gives up one lead; a plain vector is the signal and needs its
  % rate. The default lead is the first of MLII, II, I, V5, else the first lead.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    rate = X.rate;
    column = ecgLabDetectLead(X, options.Lead);
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
function column = ecgLabDetectLead(recording, lead)
  leads = recording.leads;
  if isempty(lead)
    % No lead asked for: the first preferred name present, else the first lead.
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
function ecgLabDetectCheckRefractory(refractory)
  if ~isnumeric(refractory) || ~isscalar(refractory) || ...
    ~(refractory > 0) || ~isfinite(refractory)
    error('ecglab:badRefractory', 'The refractory period must be one positive number of seconds.');
  end
end
%=============================================================================
function polarity = ecgLabDetectPolarity(value)
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badPolarity', 'The polarity must be auto, positive or negative.');
  end
  polarity = lower(char(value));
  if ~any(strcmp(polarity, {'auto', 'positive', 'negative'}))
    error('ecglab:badPolarity', 'The polarity must be auto, positive or negative.');
  end
end
%=============================================================================
function signed = ecgLabDetectPolaritySign(polarity, filtered)
  % Which way a beat points in the band-passed signal. On auto, the sign of its
  % skewness: the brief, sharp R peaks are the one heavy tail, so the third
  % moment leans toward the R whichever lobe is taller. The larger-extremum rule
  % fails on an upright lead, where the band-passed R-to-S downstroke is deeper
  % than the R upstroke. A flat or symmetric trace defaults to positive.
  switch polarity
    case 'positive'
      signed = 1;
    case 'negative'
      signed = -1;
    otherwise
      x = filtered(:);
      deviation = x - mean(x);
      spread = sqrt(mean(deviation .^ 2));
      if spread > 0 && mean(deviation .^ 3) < 0
        signed = -1;
      else
        signed = 1;
      end
  end
end
%=============================================================================
function sample = ecgLabDetectSnap(fiducials, filtered, rate, polaritySign, ...
  doSnap)
  % Move every fiducial to the extremum of the band-passed signal within 60 ms,
  % in the chosen polarity, so all beats land on the same R peak. 60 ms is wider
  % than the transform delay and narrower than the gap to a neighbouring wave.
  fiducials = round(fiducials(:));
  N = numel(filtered);
  fiducials = min(max(fiducials, 1), N);
  if ~doSnap
    sample = fiducials;
    return;
  end
  half = max(1, round(0.060 * rate));
  signed = polaritySign * filtered;
  sample = fiducials;
  for index = 1:numel(fiducials)
    lo = max(1, fiducials(index) - half);
    hi = min(N, fiducials(index) + half);
    [~, where] = max(signed(lo:hi));
    sample(index) = lo + where - 1;
  end
  sample = unique(sample);
end
%=============================================================================
function beats = ecgLabDetectBuild(sample, rate, method, leadName, options, ...
  polarity, evidence)
  % The beats struct. RR is the difference of beat times, NaN on the first.
  % Every parameter that shaped the result is recorded in settings.
  sample = sort(sample(:));
  time = (sample - 1) / rate;
  rr = [NaN; diff(time)];
  beats = struct();
  beats.kind = 'ecglab.beats';
  beats.sample = sample;
  beats.time = time;
  beats.rr = rr;
  beats.method = method;
  beats.lead = leadName;
  beats.settings = struct('Method', method, 'Lead', leadName, 'Rate', rate, ...
  'Refractory', double(options.Refractory), 'Polarity', polarity, ...
  'Snap', logical(options.Snap));
  beats.evidence = evidence;
end
%=============================================================================
function beats = ecgLabDetectConsensus(signal, rate, options, known, ...
  snapFiltered, polaritySign, leadName, polarity)
  % Consensus pools several methods' beats and keeps one only where enough agree,
  % removing each method's false detections. Methods default to all detectors;
  % the vote defaults to a strict majority.
  methodsList = ecgLabDetectMethodList(options.Methods, known);
  votes = ecgLabDetectVotes(options.Votes, numel(methodsList));
  window = max(1, round(double(options.Window) * rate));
  %===========================================================================
  % Run each method and snap its beats the common way, so pooled samples share
  % the same R peak. Remember which method each sample came from.
  perMethod = struct();
  pooled = zeros(0, 1);
  owner = zeros(0, 1);
  for index = 1:numel(methodsList)
    name = methodsList{index};
    [fiducials, ~] = feval(['ecgLabDetect', ecgLabDetectCapitalise(name)], ...
    signal, rate, options);
    sample = ecgLabDetectSnap(fiducials, snapFiltered, rate, polaritySign, ...
    options.Snap);
    perMethod.(name) = sample;
    pooled = [pooled; sample]; %#ok<AGROW>
    owner = [owner; index * ones(numel(sample), 1)]; %#ok<AGROW>
  end
  %===========================================================================
  % Cluster the pooled samples: sort, then cut where the gap exceeds the window;
  % each sample's cluster is the cumsum of the cuts. Each cluster is one beat.
  [sorted, order] = sort(pooled);
  sortedOwner = owner(order);
  if isempty(sorted)
    cluster = zeros(0, 1);
  else
    cut = [true; diff(sorted) > window];
    cluster = cumsum(cut);
  end
  clusterCount = max([cluster; 0]);
  %===========================================================================
  % Keep a cluster when the number of distinct methods in it reaches the vote,
  % placing its beat at the median sample.
  keepSample = zeros(clusterCount, 1);
  keepVotes = zeros(clusterCount, 1);
  kept = false(clusterCount, 1);
  for c = 1:clusterCount
    here = cluster == c;
    distinct = unique(sortedOwner(here));
    if numel(distinct) >= votes
      kept(c) = true;
      keepVotes(c) = numel(distinct);
      keepSample(c) = round(median(sorted(here)));
    end
  end
  sample = keepSample(kept);
  votesPerBeat = keepVotes(kept);
  [sample, order] = sort(sample);
  votesPerBeat = votesPerBeat(order);
  %===========================================================================
  evidence = struct();
  evidence.votes = votesPerBeat(:);
  evidence.filtered = snapFiltered(:);
  evidence.methods = methodsList;
  for index = 1:numel(methodsList)
    evidence.(methodsList{index}) = perMethod.(methodsList{index});
  end
  beats = ecgLabDetectBuild(sample, rate, 'consensus', leadName, options, ...
  polarity, evidence);
  beats.settings.Methods = methodsList;
  beats.settings.Votes = votes;
  beats.settings.Window = double(options.Window);
end
%=============================================================================
function methodsList = ecgLabDetectMethodList(given, known)
  if isempty(given)
    methodsList = known;
  else
    if ischar(given) || isStringScalar(given)
      given = {char(given)};
    end
    if ~iscell(given)
      error('ecglab:badMethods', 'Methods must be a list of detector names.');
    end
    methodsList = cell(1, numel(given));
    for index = 1:numel(given)
      name = lower(char(given{index}));
      if ~any(strcmp(name, known))
        error('ecglab:unknownMethod', 'Unknown detection method: %s.', name);
      end
      methodsList{index} = name;
    end
  end
  if numel(methodsList) < 2
    error('ecglab:tooFewMethods', 'Consensus needs at least two methods.');
  end
end
%=============================================================================
function votes = ecgLabDetectVotes(given, count)
  if isempty(given)
    % A strict majority: more than half the methods must agree.
    votes = floor(count / 2) + 1;
    return;
  end
  if ~isnumeric(given) || ~isscalar(given) || given < 1 || given > count
    error('ecglab:badVotes', 'Votes must be between one and the number of methods.');
  end
  votes = round(double(given));
end
%=============================================================================
function name = ecgLabDetectCapitalise(method)
  % The method's function name has the first letter upper case:
  % ecgLabDetectPantompkins for 'pantompkins'.
  name = method;
  name(1) = upper(name(1));
end
%=============================================================================
