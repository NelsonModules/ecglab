%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function data = ecgLabBeatResolve(X, options)
  % Gather everything one beat view needs, once: the recording and lead, the
  % beats and the detector's evidence, the delineation, the classes, and the
  % fixed drawing scales. X is a recording (the chain is run) or an analysis
  % (its beats, waves and classes are read). A view without beats is refused here.
  analysis = ecgLabBeatAnalysisArg(options);
  if ecgLabBeatIsKind(X, 'ecglab.analysis')
    if ~isempty(analysis)
      error('ecglab:analysisPaired', '''Analysis'' pairs an analysis with a recording, not with an analysis.');
    end
    analysis = X;
  end
  if ~isempty(analysis)
    data = ecgLabBeatFromAnalysis(analysis);
  elseif ecgLabBeatIsKind(X, 'ecglab.recording')
    data = ecgLabBeatFromRecording(X, options);
  else
    error('ecglab:notAnInputBeatViewDrawnFrom', 'A beat view is drawn from an ecglab.recording or an ecglab.analysis.');
  end
  %===========================================================================
  % The lead the beats live on, as a column of the recording. An unknown or
  % empty name falls back to the first lead.
  data.rate = data.recording.rate;
  [data.signal, data.leadName] = ecgLabBeatSignal(data.recording, ...
  data.beats);
  %===========================================================================
  % The fixed scales, computed once over the whole record so stepping between
  % beats never rescales the paper or the bars.
  data.trace = ecgLabBeatTraceScale(data.signal, options.Span);
  data.evidence = ecgLabBeatEvidenceScale(data.evidence);
  data.featureRows = ecgLabBeatFeatureRows(data.classes);
end
%=============================================================================
function analysis = ecgLabBeatAnalysisArg(options)
  % The paired analysis, from 'Analysis' or its alias 'Scoring'; at most one.
  analysis = [];
  hasAnalysis = ~isempty(options.Analysis);
  hasScoring = ~isempty(options.Scoring);
  if hasAnalysis && hasScoring
    error('ecglab:oneAnalysis', '''Analysis'' and ''Scoring'' name the same thing; pass one.');
  end
  if hasAnalysis
    analysis = options.Analysis;
  elseif hasScoring
    analysis = options.Scoring;
  end
  if ~isempty(analysis) && ~ecgLabBeatIsKind(analysis, 'ecglab.analysis')
    error('ecglab:badAnalysis', '''Analysis'' is an ecglab.analysis from ecglab.analyze.');
  end
end
%=============================================================================
function tf = ecgLabBeatIsKind(value, kind)
  tf = isstruct(value) && isfield(value, 'kind') && ...
  ischar(value.kind) && strcmp(value.kind, kind);
end
%=============================================================================
function data = ecgLabBeatFromAnalysis(analysis)
  % Read the chain an analysis already ran. With no beats there is nothing to
  % show, so that is the one failure here.
  data = struct();
  data.recording = analysis.recording;
  data.beats = analysis.beats;
  data.waves = analysis.waves;
  data.classes = analysis.classes;
  if isempty(data.beats) || ~isfield(data.beats, 'sample') || ...
    isempty(data.beats.sample)
    error('ecglab:noBeatsAnalysisCarriesNoBeats', 'The analysis carries no beats to show.');
  end
  data.method = data.beats.method;
  data.evidence = ecgLabBeatEvidenceOf(data.beats);
end
%=============================================================================
function data = ecgLabBeatFromRecording(recording, options)
  % Run the chain on a recording: detect, then delineate and classify on the
  % same beats so fiducials and classes line up with the drawn beats.
  data = struct();
  data.recording = recording;
  beats = ecglab.detect(recording, 'Method', options.Detector);
  if isempty(beats.sample)
    error('ecglab:noBeatsNoBeatsWereDetected', 'No beats were detected to show.');
  end
  data.beats = beats;
  data.method = beats.method;
  data.evidence = ecgLabBeatEvidenceOf(beats);
  % Delineation and classes are optional: a failure in either leaves the view
  % without that part rather than stopping it.
  try
    data.waves = ecglab.delineate(recording, 'Beats', beats);
  catch
    data.waves = [];
  end
  try
    data.classes = ecglab.classify(recording, 'Beats', beats);
  catch
    data.classes = [];
  end
end
%=============================================================================
function evidence = ecgLabBeatEvidenceOf(beats)
  % The evidence a redraw reads. A single-method detector leaves its feature and
  % threshold; consensus leaves neither, so the view falls back to the band-
  % passed trace. Either way the struct carries the same fields.
  evidence = struct('hasFeature', false, 'feature', [], 'threshold', [], ...
  'filtered', []);
  raw = [];
  if isfield(beats, 'evidence') && isstruct(beats.evidence)
    raw = beats.evidence;
  end
  if isempty(raw)
    return;
  end
  if isfield(raw, 'filtered')
    evidence.filtered = raw.filtered(:);
  end
  if isfield(raw, 'feature') && isfield(raw, 'threshold')
    evidence.hasFeature = true;
    evidence.feature = raw.feature(:);
    evidence.threshold = raw.threshold(:);
  elseif ~isempty(evidence.filtered)
    % Consensus or a method with no feature: show the rectified band-passed
    % trace so the lane is never empty.
    evidence.feature = abs(evidence.filtered);
    evidence.threshold = [];
  end
end
%=============================================================================
function [signal, leadName] = ecgLabBeatSignal(recording, beats)
  % The lead the beats were detected on, as a column of the recording. An
  % unknown or missing lead name falls back to the first lead.
  leads = recording.leads;
  leadName = '';
  if isfield(beats, 'lead') && ~isempty(beats.lead)
    leadName = char(beats.lead);
  end
  column = 1;
  if ~isempty(leadName)
    match = find(strcmpi(leadName, leads), 1);
    if ~isempty(match)
      column = match;
    end
  end
  if isempty(leads)
    error('ecglab:noLeads', 'The recording carries no lead to draw.');
  end
  signal = double(recording.samples(:, column));
  leadName = leads{column};
end
%=============================================================================
function trace = ecgLabBeatTraceScale(signal, span)
  % The fixed millimetre geometry of the trace paper: 25 mm/s and 10 mm/mV. The
  % amplitude window is a robust (half-percentile) range of the whole signal,
  % padded, so one tall ectopic does not set the scale for every beat.
  speed = 25;
  gain = 10;
  x = sort(signal(isfinite(signal)));
  if isempty(x)
    vlo = -1;
    vhi = 1;
  else
    n = numel(x);
    vlo = x(max(1, round(0.005 * n)));
    vhi = x(min(n, round(0.995 * n)));
  end
  if ~(vhi > vlo)
    % A flat lead has no range; a nominal 1 mV window keeps the paper drawable.
    mid = (vhi + vlo) / 2;
    vlo = mid - 0.5;
    vhi = mid + 0.5;
  end
  pad = 0.18 * (vhi - vlo);
  vlo = vlo - pad;
  vhi = vhi + pad;
  trace = struct();
  trace.speed = speed;
  trace.gain = gain;
  trace.vlo = vlo;
  trace.vhi = vhi;
  trace.Wmm = span * speed;
  trace.Hgrid = (vhi - vlo) * gain;
  % The band under the grid that the interval brackets are drawn in, and the
  % band above it the peak labels sit in, both in millimetres.
  trace.bracketArea = 11;
  trace.labelArea = 3;
end
%=============================================================================
function evidence = ecgLabBeatEvidenceScale(evidence)
  % The number the evidence lane is drawn against: the largest feature value
  % over the whole series, so the lane never rescales. An all-zero or absent
  % series keeps a scale of one.
  scale = 1;
  if ~isempty(evidence.feature)
    top = max(evidence.feature);
    if isfinite(top) && top > 0
      scale = top;
    end
  end
  evidence.scale = scale;
end
%=============================================================================
function rows = ecgLabBeatFeatureRows(classes)
  % The features the card shows and the range each bar fills. The morphology
  % columns are a shape vector, not a readable number, so the card names the
  % interpretable RR features instead. With no classes there are no rows.
  rows = struct('name', {}, 'label', {}, 'column', {}, 'scale', {}, ...
  'lo', {}, 'hi', {}, 'unit', {});
  if isempty(classes) || ~isfield(classes, 'featureNames')
    return;
  end
  names = classes.featureNames;
  features = classes.features;
  pretty = struct('prevRR', 'RR previous', 'nextRR', 'RR next', ...
  'prevRR_over_avgRR', 'RR ratio', 'avgRR', 'RR average');
  units = struct('prevRR', 'ms', 'nextRR', 'ms', 'prevRR_over_avgRR', '', ...
  'avgRR', 'ms');
  scales = struct('prevRR', 1000, 'nextRR', 1000, 'prevRR_over_avgRR', 1, ...
  'avgRR', 1000);
  for index = 1:numel(names)
    name = names{index};
    if numel(name) >= 5 && strcmp(name(1:5), 'morph')
      continue;
    end
    if ~isfield(pretty, name)
      continue;
    end
    column = features(:, index);
    finite = column(isfinite(column));
    lo = 0;
    hi = 1;
    if ~isempty(finite)
      lo = min(finite);
      hi = max(finite);
    end
    rows(end + 1) = struct('name', name, 'label', pretty.(name), ...
    'column', index, 'scale', scales.(name), 'lo', lo, 'hi', hi, ...
    'unit', units.(name)); %#ok<AGROW>
  end
end
%=============================================================================
