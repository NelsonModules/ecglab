%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function plan = ecgLabChartPlan(analysis, options, colour)
  % Work out the whole summary page before any object is drawn: the one place
  % the geometry and series live, read from the analysis and never recomputed.
  summary = analysis.summary;
  recording = analysis.recording;
  plan = struct();
  plan.height = 1100;
  plan.width = 1400;
  plan.rate = recording.rate;
  plan.seconds = recording.seconds;
  %===========================================================================
  % The columns of the page: the lanes on the left share the time axis, the
  % margin on the right carries the counts, the variability and the Poincare.
  plan.lanesLeft = 70 / plan.width;
  plan.lanesWidth = 760 / plan.width;
  plan.marginLeft = 880 / plan.width;
  plan.marginWidth = 470 / plan.width;
  %===========================================================================
  % The lane stack, top to bottom in pixels. Every lane is always present: a
  % lane with no data draws a note saying so, keeping the page's shape.
  names = {'strip', 'tachogram', 'beats', 'episodes', 'rate', 'divider', ...
  'evidence'};
  tops = [250 424 534 610 646 756 778];
  heights = [158 96 64 24 96 16 150];
  plan.laneTable = struct('name', names, 'top', num2cell(tops), ...
  'height', num2cell(heights));
  plan.laneFloor = 936;
  %===========================================================================
  % The shared time ticks, at a step that gives a handful of labels. Labels are
  % a wall clock when the start time is known, elapsed time otherwise.
  [plan.ticks, plan.tickLabels, plan.tickStep] = ecgLabChartTicks(recording);
  %===========================================================================
  % The rhythm strip: one lead of the recording over the whole record, its
  % voltage range padded so the trace does not touch the lane frame.
  plan.strip = ecgLabChartStripSignal(analysis, options);
  %===========================================================================
  % The beat series the lanes draw: the tachogram and heart rate are the RR
  % series two ways; the beats lane is one box per beat, coloured by its class.
  beats = analysis.beats;
  plan.tacho = ecgLabChartTacho(beats);
  plan.classColours = colour.classes;
  plan.beats = ecgLabChartBeatRows(beats, analysis.classes, plan.seconds, ...
  plan.lanesWidth * plan.width);
  plan.episodes = ecgLabChartEpisodeBoxes(analysis.rhythm, colour);
  plan.evidence = ecgLabChartEvidence(beats, plan.rate);
  %===========================================================================
  % The headline numbers, read verbatim from the summary, for the tiles and
  % (through UserData) for a caller checking the page against the analysis.
  plan.counts = summary.counts;
  plan.headline = ecgLabChartHeadline(summary, analysis.leads);
  plan.hrv = ecgLabChartHrv(summary, analysis.hrv);
  plan.poincare = ecgLabChartPoincare(analysis.hrv);
  %===========================================================================
  [plan.headerLine1, plan.headerLine2] = ecgLabChartHeaderLines(analysis, ...
  options);
  plan.footer = ecgLabChartFooterText(analysis);
end
%=============================================================================
function [ticks, labels, step] = ecgLabChartTicks(recording)
  % A tick step for [0, seconds] from a short list of round numbers, so any
  % record length gets a handful of labelled verticals.
  seconds = recording.seconds;
  candidates = [1 2 5 10 15 20 30 60 120 300 600 900 1800 3600];
  step = candidates(end);
  for index = 1:numel(candidates)
    if seconds / candidates(index) <= 9
      step = candidates(index);
      break;
    end
  end
  ticks = 0:step:seconds;
  clock = ecgLabChartStartSeconds(recording);
  labels = cell(1, numel(ticks));
  for index = 1:numel(ticks)
    labels{index} = ecgLabChartTimeLabel(ticks(index), clock);
  end
end
%=============================================================================
function start = ecgLabChartStartSeconds(recording)
  % The start time in seconds past midnight when known, so the ticks read as a
  % wall clock; NaN otherwise, and the ticks count elapsed time.
  start = NaN;
  info = recording.info;
  if ~isfield(info, 'startTimeKnown') || ~info.startTimeKnown
    return;
  end
  parts = sscanf(strrep(char(info.startTime), '.', ':'), '%d:%d:%d');
  if numel(parts) >= 2
    hours = parts(1);
    minutes = parts(2);
    secs = 0;
    if numel(parts) >= 3
      secs = parts(3);
    end
    start = hours * 3600 + minutes * 60 + secs;
  end
end
%=============================================================================
function label = ecgLabChartTimeLabel(offset, clock)
  % One tick label: a wall clock HH:MM:SS when a start time is known, else the
  % elapsed minutes and seconds (or bare seconds under a minute).
  if ~isnan(clock)
    total = mod(round(clock + offset), 86400);
    label = sprintf('%02d:%02d:%02d', floor(total / 3600), ...
    mod(floor(total / 60), 60), mod(total, 60));
    return;
  end
  if offset < 60
    label = sprintf('%ds', round(offset));
  else
    label = sprintf('%d:%02d', floor(offset / 60), mod(round(offset), 60));
  end
end
%=============================================================================
function strip = ecgLabChartStripSignal(analysis, options)
  % The lead the rhythm strip draws, with its signal and padded voltage range.
  % Uses the caller's 'Lead', else the detector's lead, else a monitor lead.
  recording = analysis.recording;
  column = ecgLabChartLead(recording, options, analysis.beats);
  signal = double(recording.samples(:, column));
  n = numel(signal);
  time = (0:n - 1)' / recording.rate;
  lo = min(signal);
  hi = max(signal);
  if ~(hi > lo)
    lo = lo - 1;
    hi = hi + 1;
  end
  pad = 0.12 * (hi - lo);
  strip = struct('lead', recording.leads{column}, 'time', time, ...
  'signal', signal, 'ylo', lo - pad, 'yhi', hi + pad);
end
%=============================================================================
function column = ecgLabChartLead(recording, options, beats)
  % The strip lead as a column index. Prefers the caller's name or index, then
  % the beats' lead, then the monitor leads, then the first lead.
  if ~isempty(options.Lead)
    if isnumeric(options.Lead) && isscalar(options.Lead)
      idx = round(options.Lead);
      if idx >= 1 && idx <= numel(recording.leads)
        column = idx;
        return;
      end
    else
      found = ecgLabChartFindLead(recording, char(options.Lead));
      if found > 0
        column = found;
        return;
      end
    end
  end
  if ~isempty(beats) && isfield(beats, 'lead')
    found = ecgLabChartFindLead(recording, beats.lead);
    if found > 0
      column = found;
      return;
    end
  end
  for candidate = {'MLII', 'II', 'I', 'V5'}
    found = ecgLabChartFindLead(recording, candidate{1});
    if found > 0
      column = found;
      return;
    end
  end
  column = 1;
end
%=============================================================================
function column = ecgLabChartFindLead(recording, name)
  % The column of a lead by name, case-insensitive and with common aliases, or
  % 0 when the recording lacks it.
  column = find(strcmpi(name, recording.leads), 1);
  if ~isempty(column)
    return;
  end
  aliases = {};
  switch upper(char(name))
    case {'II', 'MLII'}
      aliases = {'II', 'MLII', 'ML2'};
    case {'I', 'MLI'}
      aliases = {'I', 'MLI', 'ML1'};
    case 'V5'
      aliases = {'V5', 'MV5'};
    case 'V1'
      aliases = {'V1', 'MV1'};
  end
  for index = 1:numel(aliases)
    column = find(strcmpi(aliases{index}, recording.leads), 1);
    if ~isempty(column)
      return;
    end
  end
  column = 0;
end
%=============================================================================
function tacho = ecgLabChartTacho(beats)
  % The RR tachogram and instantaneous heart rate from the RR series. The first
  % RR is NaN, so the line lifts its pen there.
  time = beats.time(:);
  rr = beats.rr(:);
  tacho = struct('time', time, 'ms', rr * 1000, 'bpm', 60 ./ rr);
end
%=============================================================================
function out = ecgLabChartBeatRows(beats, classes, seconds, widthPx)
  % One box per beat for the beats lane, on the row of its AAMI class (N S V F Q,
  % row 1 at the bottom). Each box is a couple of raster columns wide so a single
  % beat survives a long record; the lane is painted into one image.
  time = beats.time(:);
  k = numel(time);
  rows = ones(k, 1);
  present = false;
  if ~isempty(classes) && isfield(classes, 'label') && ...
    numel(classes.label) == k
    present = true;
    letters = 'NSVFQ';
    label = classes.label(:);
    for index = 1:k
      position = find(letters == label(index), 1);
      if isempty(position)
        position = 5;
      end
      rows(index) = position;
    end
  end
  columns = max(60, round(widthPx));
  half = 1.5 * seconds / columns;
  out = struct('time', time, 'row', rows, 'present', present, ...
  'halfWidth', half, 'columns', columns);
end
%=============================================================================
function out = ecgLabChartEpisodeBoxes(rhythm, colour)
  % The non-sinus rhythm episodes, each a coloured band: AF and flutter in the
  % ventricular hue, anything else in the supraventricular hue. Sinus draws nothing.
  onset = [];
  offset = [];
  rgb = zeros(0, 3);
  labels = {};
  present = false;
  if ~isempty(rhythm) && isfield(rhythm, 'episodes')
    episodes = rhythm.episodes;
    for index = 1:numel(episodes.onset)
      name = episodes.label{index};
      if strcmp(name, 'N')
        continue;
      end
      present = true;
      onset(end + 1, 1) = episodes.onset(index);
      offset(end + 1, 1) = episodes.offset(index);
      labels{end + 1} = name;
      if any(strcmp(name, {'AFIB', 'AFL'}))
        rgb(end + 1, :) = colour.classV;
      else
        rgb(end + 1, :) = colour.classS;
      end
    end
  end
  out = struct('onset', onset, 'offset', offset, 'colour', rgb, ...
  'label', {labels}, 'present', present);
end
%=============================================================================
function out = ecgLabChartEvidence(beats, rate)
  % The thresholded feature and the threshold in force at each sample, both
  % scaled by the feature's maximum so the feature is seen rising over it.
  present = false;
  time = [];
  feature = [];
  threshold = [];
  if ~isempty(beats) && isfield(beats, 'evidence') && ...
    isfield(beats.evidence, 'feature')
    present = true;
    f = beats.evidence.feature(:);
    t = beats.evidence.threshold(:);
    n = numel(f);
    time = (0:n - 1)' / rate;
    scale = max(f);
    if ~(scale > 0)
      scale = 1;
    end
    feature = f / scale;
    threshold = t / scale;
  end
  out = struct('time', time, 'feature', feature, 'threshold', threshold, ...
  'present', present);
end
%=============================================================================
function headline = ecgLabChartHeadline(summary, leads)
  % The flat set of numbers the tiles show, read verbatim from the summary, with
  % normal-range flags beside each measurement that has a range. The flags come
  % from ecglab.leads when the twelve leads ran, else are applied here.
  headline = struct();
  headline.heartRate = summary.heartRate.mean;
  headline.heartRateMin = summary.heartRate.min;
  headline.heartRateMax = summary.heartRate.max;
  headline.rhythm = summary.rhythm.label;
  headline.afBurden = summary.rhythm.afBurden;
  headline.pr = summary.intervals.pr;
  headline.qrs = summary.intervals.qrs;
  headline.qt = summary.intervals.qt;
  headline.qtcBazett = summary.intervals.qtc.bazett;
  headline.qtcFridericia = summary.intervals.qtc.fridericia;
  headline.qtcFramingham = summary.intervals.qtc.framingham;
  headline.qtcHodges = summary.intervals.qtc.hodges;
  headline.quality = summary.quality.usableFraction;
  headline.hasLeads = ~isempty(leads);
  if isempty(summary.axis)
    headline.axisDegrees = NaN;
    headline.axisLabel = '';
  else
    headline.axisDegrees = summary.axis.degrees;
    headline.axisLabel = summary.axis.label;
  end
  if ~isempty(leads) && isfield(leads, 'normal')
    headline.prNormal = leads.normal.pr.inRange;
    headline.qrsNormal = leads.normal.qrs.inRange;
    headline.qtcNormal = leads.normal.qtc.inRange;
    headline.axisNormal = leads.normal.axis.inRange;
    headline.qtcLimit = leads.normal.qtc.limit;
  else
    headline.prNormal = ecgLabChartInRange(headline.pr, 120, 200);
    headline.qrsNormal = ecgLabChartBelow(headline.qrs, 120);
    headline.qtcNormal = ecgLabChartBelow(headline.qtcBazett, 450);
    headline.axisNormal = strcmp(headline.axisLabel, 'normal');
    headline.qtcLimit = 450;
  end
end
%=============================================================================
function tf = ecgLabChartInRange(value, low, high)
  tf = ~isnan(value) && value >= low && value <= high;
end
%=============================================================================
function tf = ecgLabChartBelow(value, high)
  tf = ~isnan(value) && value < high;
end
%=============================================================================
function hrv = ecgLabChartHrv(summary, hrvStruct)
  % The variability numbers the margin lists: the four the summary leads with,
  % and the two Poincare descriptors from the non-linear analysis.
  hrv = struct('sdnn', summary.hrv.sdnn, 'rmssd', summary.hrv.rmssd, ...
  'pnn50', summary.hrv.pnn50, 'lfhf', summary.hrv.lfhf, 'sd1', NaN, ...
  'sd2', NaN, 'present', ~isempty(hrvStruct));
  if ~isempty(hrvStruct) && isfield(hrvStruct, 'nonlinear')
    hrv.sd1 = hrvStruct.nonlinear.sd1;
    hrv.sd2 = hrvStruct.nonlinear.sd2;
  end
end
%=============================================================================
function out = ecgLabChartPoincare(hrvStruct)
  % The successive-interval pairs the Poincare plot scatters: RR(n) against
  % RR(n+1), in milliseconds, from the NN series the HRV analysis used.
  x = [];
  y = [];
  present = false;
  if ~isempty(hrvStruct) && isfield(hrvStruct, 'nn') && numel(hrvStruct.nn) > 2
    present = true;
    nn = hrvStruct.nn(:) * 1000;
    x = nn(1:end - 1);
    y = nn(2:end);
  end
  out = struct('x', x, 'y', y, 'present', present);
end
%=============================================================================
function [line1, line2] = ecgLabChartHeaderLines(analysis, options)
  % The two header lines: who and where the record is, then the detector and
  % the usable fraction of the record.
  recording = analysis.recording;
  info = recording.info;
  subject = ecgLabChartField(info, 'subject', '');
  name = ecgLabChartField(info, 'name', '');
  source = ecgLabChartField(info, 'source', '');
  who = subject;
  if isempty(who)
    who = name;
  end
  if isempty(who)
    who = 'unnamed recording';
  end
  where = source;
  if isempty(where)
    where = name;
  end
  start = '';
  if isfield(info, 'startTimeKnown') && info.startTimeKnown
    start = strtrim([ecgLabChartField(info, 'startDate', ''), ' ', ...
    ecgLabChartStartClock(info)]);
  end
  pieces = {who};
  if ~isempty(where) && ~strcmp(where, who)
    pieces{end + 1} = where;
  end
  if ~isempty(start)
    pieces{end + 1} = start;
  end
  pieces{end + 1} = ecgLabChartLength(recording.seconds);
  line1 = strjoin(pieces, '   ');
  if ~isempty(options.Title)
    line1 = char(options.Title);
  end
  detector = analysis.summary.provenance.detector;
  quality = analysis.summary.quality.usableFraction;
  if isnan(quality)
    line2 = sprintf('detector %s', detector);
  else
    line2 = sprintf('detector %s   signal usable %.0f %% of the record', ...
    detector, 100 * quality);
  end
end
%=============================================================================
function clock = ecgLabChartStartClock(info)
  parts = sscanf(strrep(char(info.startTime), '.', ':'), '%d:%d:%d');
  clock = '';
  if numel(parts) >= 2
    clock = sprintf('%02d:%02d', parts(1), parts(2));
  end
end
%=============================================================================
function text = ecgLabChartLength(seconds)
  % The record length in the unit a reader expects: seconds under two minutes,
  % minutes under two hours, hours beyond.
  if seconds < 120
    text = sprintf('%.0f s recorded', seconds);
  elseif seconds < 7200
    text = sprintf('%.1f min recorded', seconds / 60);
  else
    text = sprintf('%.1f h recorded', seconds / 3600);
  end
end
%=============================================================================
function footer = ecgLabChartFooterText(analysis)
  % The provenance line and the statement that this is not a clinical record.
  provenance = analysis.summary.provenance;
  source = provenance.source;
  if isempty(source)
    source = provenance.name;
  end
  if isempty(source)
    source = 'ecglab';
  end
  footer = sprintf(['%s   detector %s   Nelson %s   research software, ' ...
  'not a medical device, not for clinical use'], source, ...
  provenance.detector, provenance.nelson);
end
%=============================================================================
function value = ecgLabChartField(s, name, fallback)
  value = fallback;
  if isstruct(s) && isfield(s, name) && ~isempty(s.(name)) && ischar(s.(name))
    value = s.(name);
  end
end
%=============================================================================
