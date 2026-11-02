%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% WAVES = ECGLAB.DELINEATE(X) finds the onset, peak and end of the P, QRS and
% T waves on the beats of X.
% WAVES = ECGLAB.DELINEATE(X, 'Name', value, ...) sets the lead, the beats and
% the options.
%
%   X is an ecglab.recording (delineated on the lead named by 'Lead', or on
%   every lead and fused when 'Lead' is 'all' or several are named) or a plain
%   signal vector in millivolts whose 'Rate' in hertz is given. WAVES is the
%   waves struct of the data model: kind 'ecglab.waves'; columns
%   {'Pon','Ppeak','Poff','QRSon','Q','R','S','QRSoff','J','Ton','Tpeak',
%   'Toff'}; sample and time (K x 12, 1-based sample indices and seconds, NaN
%   for an absent wave); lead (the lead delineated, or the fused set); intervals
%   (pr, qrs, qt in ms and qtc a struct with bazett, fridericia, framingham,
%   hodges in ms); morphology (the T-wave code per beat: 0 normal, 1 inverted,
%   2 upward monophasic, 3 downward monophasic, 4 biphasic negative-positive,
%   5 biphasic positive-negative); and settings. When several leads are
%   delineated WAVES also carries perLead (a struct per lead with its own sample
%   and time), and the returned sample and time are the fused global marks:
%   earliest onset and latest offset across leads for a boundary, median for a
%   peak.
%
%   The method is the wavelet modulus maxima of Martinez, Almeida, Olmos, Rocha
%   and Laguna (IEEE TBME 51(4):570-581, 2004). A wave shows as a pair of
%   opposite-sign modulus maxima straddling a zero crossing (the wave's peak),
%   with the onset and offset at the outer maxima. The QRS is anchored on the R
%   peak at a fine scale; the T and P are searched after and before it at a
%   coarse scale. A wave whose slope pair does not clear the threshold is NaN.
%
%   Options (name and value, matched without regard to case):
%     'Beats'   a beats struct from ecglab.detect to hang the delineation on;
%               when absent the beats are detected with the default method.
%     'Lead'    the lead to delineate: a name, a column index, several of
%               either, or 'all'. Default the first ECG-like lead. When several
%               leads are delineated the global marks are the fused set.
%     'Rate'    the sampling rate in hertz, required when X is a plain vector.
%     'Clean'   true (default) removes the baseline with ecglab.clean before
%               delineating, because the wavelet P and T search is thrown by
%               baseline wander. false delineates the signal as given.
%     'Method'  the detector used when 'Beats' is absent (default the
%               ecglab.detect default).
%     'Qtc'     which corrected QT formulas to compute: 'all' (default), a
%               formula name, or a list of 'bazett', 'fridericia',
%               'framingham', 'hodges'.
%     'BoundaryFraction' the fraction of the QRS boundary slope maximum at which
%               the onset and offset are read (Martinez et al. 2004). Default
%               the clinical value from ecgLabDelineateScales (foot of the
%               complex); 1 puts the boundary on the steepest slope itself.
%
%   A recording or a signal with no detectable beats returns an empty waves
%   struct, not an error.
%
%   On this build a thirty minute single lead at 500 Hz is delineated in about
%   3 s, dominated by the beat detection and the wavelet transform.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 30, 'Rate', 500, 'Seed', 1);
%     waves = ecglab.delineate(recording);
%     median(waves.intervals.qt, 'omitnan')
%
%   See also ecglab.detect, ecglab.clean, ecglab.simulate, ecglab.validate.
function waves = delineate(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Beats', [], 'Lead', [], 'Rate', [], 'Clean', true, ...
  'Method', [], 'Qtc', 'all', 'BoundaryFraction', []);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % The signal matrix, rate, lead names and the columns to delineate. A plain
  % vector is one unnamed lead with its rate given.
  [samples, rate, leadNames] = ecgLabDelineateInput(X, options);
  columns = ecgLabDelineateColumns(X, options.Lead, leadNames, ...
  isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording'));
  settings = ecgLabDelineateScales(rate);
  % Optional QRS boundary fraction override; the default is the clinical foot
  % of the complex from ecgLabDelineateScales.
  settings.boundaryFraction = ecgLabDelineateBoundaryFraction(options, settings);
  %===========================================================================
  % The shared beats every lead is delineated against, so the per-lead marks
  % line up and can be fused. Given beats are used as is; otherwise detected on
  % the first lead after cleaning.
  primary = ecgLabDelineatePrepare(samples(:, columns(1)), rate, options.Clean);
  [beatSample, rr, beatsLead] = ecgLabDelineateBeats(options, primary, rate, ...
  leadNames{columns(1)});
  if isempty(beatSample)
    waves = ecgLabDelineateEmpty(rate, leadNames, columns, settings, ...
    options, beatsLead);
    return;
  end
  %===========================================================================
  % Delineate each selected lead against the shared beats, cleaning first unless
  % told not to, keeping the per-lead marks for fusion and perLead output.
  L = numel(columns);
  perLeadSample = cell(1, L);
  perLeadMorph = cell(1, L);
  for index = 1:L
    signal = ecgLabDelineatePrepare(samples(:, columns(index)), rate, ...
    options.Clean);
    [s, m] = ecgLabDelineateLead(signal, rate, beatSample, settings);
    perLeadSample{index} = s;
    perLeadMorph{index} = m;
  end
  %===========================================================================
  if L == 1
    sample = perLeadSample{1};
    morphology = perLeadMorph{1};
    leadOut = leadNames{columns(1)};
  else
    sample = ecgLabDelineateFuse(perLeadSample);
    % Global morphology is the most common code across leads on each beat.
    morphology = ecgLabDelineateFuseMorphology(perLeadMorph);
    leadOut = leadNames(columns);
  end
  time = (sample - 1) / rate;
  intervals = ecgLabDelineateIntervals(sample, rate, rr, options.Qtc);
  %===========================================================================
  waves = ecgLabDelineateBuild(sample, time, leadOut, intervals, morphology, ...
  settings, options, beatsLead);
  if L > 1
    waves.perLead = ecgLabDelineatePerLead(perLeadSample, perLeadMorph, ...
    rate, leadNames(columns));
  end
end
%=============================================================================
function [samples, rate, leadNames] = ecgLabDelineateInput(X, options)
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    samples = double(X.samples);
    rate = double(X.rate);
    leadNames = X.leads;
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
    samples = double(X(:));
    leadNames = {''};
    return;
  end
  error('ecglab:notASignalXEcglabRecordingSignal', 'X must be an ecglab.recording or a signal vector with a Rate.');
end
%=============================================================================
function fraction = ecgLabDelineateBoundaryFraction(options, settings)
  % The QRS boundary fraction: the caller's value, else the clinical default.
  % Must be a single number in (0, 1].
  if isempty(options.BoundaryFraction)
    fraction = settings.boundaryFraction;
    return;
  end
  fraction = double(options.BoundaryFraction);
  if ~isscalar(fraction) || ~isfinite(fraction) || fraction <= 0 || fraction > 1
    error('ecglab:badBoundaryFraction', 'BoundaryFraction must be one number greater than 0 and at most 1.');
  end
end
%=============================================================================
function columns = ecgLabDelineateColumns(X, lead, leadNames, isRecording)
  % Which leads to delineate. A plain vector is one lead. A recording defaults
  % to the first ECG-like lead, takes every lead on 'all', or the named/indexed.
  leadCount = numel(leadNames);
  if ~isRecording
    columns = 1;
    return;
  end
  if isempty(lead)
    preferred = {'MLII', 'II', 'I', 'V5'};
    for index = 1:numel(preferred)
      match = find(strcmpi(preferred{index}, leadNames), 1);
      if ~isempty(match)
        columns = match;
        return;
      end
    end
    columns = 1;
    return;
  end
  if (ischar(lead) || isStringScalar(lead)) && strcmpi(char(lead), 'all')
    columns = 1:leadCount;
    return;
  end
  if ischar(lead) || isStringScalar(lead)
    lead = {char(lead)};
  end
  if iscell(lead)
    columns = zeros(1, numel(lead));
    for index = 1:numel(lead)
      match = find(strcmpi(char(lead{index}), leadNames), 1);
      if isempty(match)
        error('ecglab:unknownLeadRecordingHasNoLead', 'The recording has no lead named %s.', char(lead{index}));
      end
      columns(index) = match;
    end
    return;
  end
  if isnumeric(lead)
    columns = round(double(lead(:)'));
    if any(columns < 1) || any(columns > leadCount)
      error('ecglab:unknownLeadLeadIndexOutsideD', 'A lead index is outside the %d leads.', leadCount);
    end
    return;
  end
  error('ecglab:badLeadLeadNameColumnIndex2', 'The lead must be a name, a column index, several of either, or all.');
end
%=============================================================================
function signal = ecgLabDelineatePrepare(signal, rate, doClean)
  % Remove the baseline before delineating: the coarse-scale P and T search is
  % thrown by wander. The zero-phase high pass does not move a boundary.
  signal = double(signal(:));
  if doClean
    signal = ecglab.clean(signal, 'Rate', rate);
  end
end
%=============================================================================
function [beatSample, rr, leadName] = ecgLabDelineateBeats(options, primary, ...
  rate, leadName)
  % The beats to hang the delineation on. Given beats are used untouched; no
  % detection runs.
  if ~isempty(options.Beats)
    beats = options.Beats;
    if ~isstruct(beats) || ~isfield(beats, 'sample')
      error('ecglab:badBeatsBeatsBeatsStructFrom', 'Beats must be a beats struct from ecglab.detect.');
    end
    beatSample = round(double(beats.sample(:)));
    if isfield(beats, 'rr')
      rr = double(beats.rr(:));
    else
      rr = [NaN; diff(beatSample) / rate];
    end
    if isfield(beats, 'lead') && ~isempty(beats.lead)
      leadName = beats.lead;
    end
    return;
  end
  % No beats given: detect on the prepared primary lead, passing Method through.
  if isempty(options.Method)
    beats = ecglab.detect(primary, 'Rate', rate);
  else
    beats = ecglab.detect(primary, 'Rate', rate, 'Method', options.Method);
  end
  beatSample = round(double(beats.sample(:)));
  rr = double(beats.rr(:));
end
%=============================================================================
function morphology = ecgLabDelineateFuseMorphology(perLeadMorph)
  % The majority morphology code across the leads on each beat, NaN only when no
  % lead saw the T.
  L = numel(perLeadMorph);
  K = numel(perLeadMorph{1});
  stack = nan(K, L);
  for index = 1:L
    stack(:, index) = perLeadMorph{index}(:);
  end
  morphology = nan(K, 1);
  for k = 1:K
    row = stack(k, :);
    row = row(isfinite(row));
    if ~isempty(row)
      morphology(k) = mode(row);
    end
  end
end
%=============================================================================
function perLead = ecgLabDelineatePerLead(perLeadSample, perLeadMorph, rate, ...
  names)
  % One struct per lead carrying its own marks, before fusion pooled them.
  L = numel(perLeadSample);
  perLead = struct('lead', cell(1, L), 'sample', cell(1, L), ...
  'time', cell(1, L), 'morphology', cell(1, L));
  for index = 1:L
    perLead(index).lead = names{index};
    perLead(index).sample = perLeadSample{index};
    perLead(index).time = (perLeadSample{index} - 1) / rate;
    perLead(index).morphology = perLeadMorph{index};
  end
end
%=============================================================================
function waves = ecgLabDelineateBuild(sample, time, leadOut, intervals, ...
  morphology, settings, options, beatsLead)
  waves = struct();
  waves.kind = 'ecglab.waves';
  waves.columns = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', ...
  'QRSoff', 'J', 'Ton', 'Tpeak', 'Toff'};
  waves.sample = sample;
  waves.time = time;
  waves.lead = leadOut;
  waves.intervals = intervals;
  waves.morphology = morphology;
  waves.settings = ecgLabDelineateSettings(settings, options, beatsLead);
end
%=============================================================================
function out = ecgLabDelineateSettings(settings, options, beatsLead)
  % Everything that shaped the result (wavelet, scales, thresholds, windows), so
  % a later measurement can reproduce it.
  out = settings;
  out.clean = logical(options.Clean);
  out.beatsLead = beatsLead;
  if isempty(options.Method)
    out.method = 'default';
  else
    out.method = lower(char(options.Method));
  end
end
%=============================================================================
function waves = ecgLabDelineateEmpty(rate, leadNames, columns, settings, ...
  options, beatsLead)
  % No beats: an empty waves struct of the right shape, so a caller tests the
  % row count instead of catching an error.
  if numel(columns) == 1
    leadOut = leadNames{columns(1)};
  else
    leadOut = leadNames(columns);
  end
  sample = zeros(0, 12);
  intervals = ecgLabDelineateIntervals(sample, rate, zeros(0, 1), options.Qtc);
  waves = ecgLabDelineateBuild(sample, zeros(0, 12), leadOut, intervals, ...
  zeros(0, 1), settings, options, beatsLead);
end
%=============================================================================
