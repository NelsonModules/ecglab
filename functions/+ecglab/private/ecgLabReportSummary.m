%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function summary = ecgLabReportSummary(analysis)
  % Read every headline number out of the analysis into one summary for the text
  % renderer. The only place a value is taken; an empty field becomes a reason.
  sub = ecgLabReportCollect(analysis);
  if isfield(analysis, 'reasons')
    reasons = analysis.reasons;
  else
    reasons = struct();
  end
  summary = struct();
  summary.header = ecgLabReportHeader(sub.recording);
  summary.quality = ecgLabReportQuality(sub.quality, reasons);
  summary.heartRate = ecgLabReportHeartRate(sub.beats, reasons);
  summary.rhythm = ecgLabReportRhythm(sub.rhythm, reasons);
  summary.intervals = ecgLabReportIntervals(sub.leads, reasons);
  summary.axis = ecgLabReportAxis(sub.leads, reasons);
  summary.classes = ecgLabReportClasses(sub.classes, reasons);
  summary.hrv = ecgLabReportHrv(sub.hrv, reasons);
  summary.provenance = ecgLabReportProvenance(sub.beats);
end
%=============================================================================
function sub = ecgLabReportCollect(analysis)
  % Route the analysis fields to the sub-results by their kind, not their name.
  % Fields that are not a recognised sub-result are skipped.
  sub = struct('recording', [], 'quality', [], 'beats', [], 'waves', [], ...
  'classes', [], 'rhythm', [], 'hrv', [], 'leads', []);
  names = fieldnames(analysis);
  for index = 1:numel(names)
    value = analysis.(names{index});
    if ~isstruct(value) || ~isscalar(value) || ~isfield(value, 'kind')
      continue;
    end
    switch value.kind
      case 'ecglab.recording'
        sub.recording = value;
      case 'ecglab.quality'
        sub.quality = value;
      case 'ecglab.beats'
        sub.beats = value;
      case 'ecglab.waves'
        sub.waves = value;
      case 'ecglab.classes'
        sub.classes = value;
      case 'ecglab.rhythm'
        sub.rhythm = value;
      case 'ecglab.hrv'
        sub.hrv = value;
      case 'ecglab.leads'
        sub.leads = value;
    end
  end
end
%=============================================================================
function header = ecgLabReportHeader(recording)
  % The identity of the record. Every field exists, so no field is tested here;
  % an empty string becomes "unknown" at render.
  header = struct('available', false, 'subject', '', 'source', '', ...
  'format', '', 'name', '', 'seconds', NaN, 'rate', NaN, 'leads', {{}}, ...
  'startText', '', 'startKnown', false);
  if isempty(recording)
    return;
  end
  header.available = true;
  info = recording.info;
  header.subject = char(info.subject);
  header.source = char(info.source);
  header.format = char(info.format);
  header.name = char(info.name);
  header.seconds = recording.seconds;
  header.rate = recording.rate;
  header.leads = recording.leads;
  header.startKnown = logical(info.startTimeKnown);
  if header.startKnown
    startText = char(info.startTime);
    if ~isempty(info.startDate)
      startText = [char(info.startDate), ' ', startText];
    end
    header.startText = startText;
  end
end
%=============================================================================
function quality = ecgLabReportQuality(source, reasons)
  quality = struct('available', false, 'reason', '', 'usableFraction', NaN, ...
  'goodSeconds', NaN, 'lead', '', 'refused', false);
  if isempty(source)
    quality.reason = ecgLabReportWhy(reasons, 'quality', ...
    'the signal quality was not assessed.');
    return;
  end
  quality.available = true;
  quality.usableFraction = source.usableFraction;
  quality.goodSeconds = source.good;
  if isfield(source, 'settings') && isfield(source.settings, 'Lead')
    quality.lead = char(source.settings.Lead);
  end
  % No usable window means the lead was refused; flag it on its own line.
  quality.refused = source.usableFraction <= 0;
end
%=============================================================================
function heartRate = ecgLabReportHeartRate(beats, reasons)
  heartRate = struct('available', false, 'reason', '', 'mean', NaN, ...
  'low', NaN, 'high', NaN, 'beats', 0);
  if isempty(beats)
    heartRate.reason = ecgLabReportWhy(reasons, 'beats', ...
    'no beats were detected.');
    return;
  end
  heartRate.beats = numel(beats.sample);
  rr = beats.rr;
  rr = rr(~isnan(rr));
  if isempty(rr)
    heartRate.reason = 'fewer than two beats, so no interval to measure.';
    return;
  end
  % Instantaneous rate per beat (60 / RR); keep its mean and extremes.
  instant = 60 ./ rr;
  heartRate.available = true;
  heartRate.mean = mean(instant);
  heartRate.low = min(instant);
  heartRate.high = max(instant);
end
%=============================================================================
function rhythm = ecgLabReportRhythm(source, reasons)
  rhythm = struct('available', false, 'reason', '', 'dominant', '', ...
  'afBurden', NaN, 'hasAf', false);
  if isempty(source)
    rhythm.reason = ecgLabReportWhy(reasons, 'rhythm', ...
    'the rhythm was not labelled.');
    return;
  end
  rhythm.available = true;
  rhythm.afBurden = source.afBurden;
  rhythm.hasAf = source.afBurden > 0;
  % Dominant label is the one covering the most beats (per beat, not per episode).
  perBeat = source.perBeat;
  if iscell(perBeat) && ~isempty(perBeat)
    labels = unique(perBeat);
    best = 0;
    for index = 1:numel(labels)
      n = sum(strcmp(perBeat, labels{index}));
      if n > best
        best = n;
        rhythm.dominant = labels{index};
      end
    end
  end
end
%=============================================================================
function intervals = ecgLabReportIntervals(leads, reasons)
  intervals = struct('available', false, 'reason', '');
  if isempty(leads)
    intervals.reason = ecgLabReportWhy(reasons, 'leads', ...
    'the twelve-lead interval measurements were not made.');
    return;
  end
  intervals.available = true;
  normal = leads.normal;
  % PR and QRS carry their range and in-range flag; bounds stay numeric so the
  % text layer formats them per language. QT is printed raw (QTc has the limit).
  intervals.pr = ecgLabReportBetween(normal.pr.value, normal.pr.low, ...
  normal.pr.high, normal.pr.inRange);
  intervals.qrs = ecgLabReportBelow(normal.qrs.value, normal.qrs.high, ...
  normal.qrs.inRange);
  intervals.qt = leads.intervals.qt;
  % The four rate corrections, each flagged against the one QTc upper limit,
  % with the sex it was chosen for.
  limit = normal.qtc.limit;
  intervals.qtcLimit = limit;
  intervals.qtcSex = normal.qtc.sex;
  intervals.qtc = struct();
  intervals.qtc.bazett = ecgLabReportQtc(leads.qtc.bazett, limit);
  intervals.qtc.fridericia = ecgLabReportQtc(leads.qtc.fridericia, limit);
  intervals.qtc.framingham = ecgLabReportQtc(leads.qtc.framingham, limit);
  intervals.qtc.hodges = ecgLabReportQtc(leads.qtc.hodges, limit);
end
%=============================================================================
function item = ecgLabReportBetween(value, low, high, inRange)
  % An interval normal between a lower and upper bound (PR); bounds kept numeric
  % for the text layer to format.
  item = struct('value', value, 'kind', 'between', 'low', low, 'high', high, ...
  'inRange', logical(inRange));
end
%=============================================================================
function item = ecgLabReportBelow(value, high, inRange)
  % An interval normal below an upper limit only (QRS, QTc), bounds kept numeric.
  item = struct('value', value, 'kind', 'below', 'low', NaN, 'high', high, ...
  'inRange', logical(inRange));
end
%=============================================================================
function item = ecgLabReportQtc(value, limit)
  % Flag the measured value against the published limit.
  inRange = isfinite(value) && value < limit;
  item = ecgLabReportBelow(value, limit, inRange);
end
%=============================================================================
function axis = ecgLabReportAxis(leads, reasons)
  axis = struct('available', false, 'reason', '', 'degrees', NaN, ...
  'label', '', 'inRange', false, 'low', NaN, 'high', NaN);
  if isempty(leads)
    axis.reason = ecgLabReportWhy(reasons, 'leads', ...
    'the frontal axis was not measured.');
    return;
  end
  axis.available = true;
  axis.degrees = leads.axis.degrees;
  axis.label = char(leads.axis.label);
  axis.inRange = logical(leads.normal.axis.inRange);
  % Bounds kept numeric so the text layer names the unit in the report language.
  axis.low = leads.normal.axis.low;
  axis.high = leads.normal.axis.high;
end
%=============================================================================
function classes = ecgLabReportClasses(source, reasons)
  classes = struct('available', false, 'reason', '', 'total', 0, ...
  'order', 'NSVFQ', 'counts', NaN, 'shares', NaN);
  if isempty(source)
    classes.reason = ecgLabReportWhy(reasons, 'classes', ...
    'the beats were not classified.');
    return;
  end
  label = source.label;
  total = numel(label);
  if total == 0
    classes.reason = 'no beats to classify.';
    return;
  end
  classes.available = true;
  classes.total = total;
  order = 'NSVFQ';
  counts = zeros(1, numel(order));
  for index = 1:numel(order)
    counts(index) = sum(label == order(index));
  end
  classes.counts = counts;
  classes.shares = 100 * counts / total;
end
%=============================================================================
function hrv = ecgLabReportHrv(source, reasons)
  hrv = struct('available', false, 'reason', '', 'sdnn', NaN, ...
  'rmssd', NaN, 'pnn50', NaN, 'lfhf', NaN);
  if isempty(source)
    hrv.reason = ecgLabReportWhy(reasons, 'hrv', ...
    'heart rate variability was not measured.');
    return;
  end
  hrv.available = true;
  hrv.sdnn = source.time.sdnn;
  hrv.rmssd = source.time.rmssd;
  hrv.pnn50 = source.time.pnn50;
  hrv.lfhf = source.frequency.lfhf;
end
%=============================================================================
function provenance = ecgLabReportProvenance(beats)
  % The footer provenance: the detector, the Nelson build and the module version.
  provenance = struct('detector', '', 'nelson', '', 'moduleVersion', '');
  if ~isempty(beats) && isfield(beats, 'method')
    provenance.detector = char(beats.method);
  end
  provenance.nelson = version();
  provenance.moduleVersion = ecgLabReportModuleVersion();
end
%=============================================================================
function value = ecgLabReportModuleVersion()
  % The module version read from module.json, the one place it is declared.
  value = 'unknown';
  try
    privateDir = fileparts(nfilename('fullpath'));
    moduleRoot = fileparts(fileparts(fileparts(privateDir)));
    manifest = jsondecode(fileread([moduleRoot, '/module.json']));
    if isfield(manifest, 'version')
      value = char(manifest.version);
    end
  catch
  end
end
%=============================================================================
function text = ecgLabReportWhy(reasons, field, fallback)
  % The reason a section is not available: the analysis's sentence, or a fallback.
  if isfield(reasons, field) && ~isempty(reasons.(field))
    text = char(reasons.(field));
  else
    text = fallback;
  end
end
%=============================================================================
