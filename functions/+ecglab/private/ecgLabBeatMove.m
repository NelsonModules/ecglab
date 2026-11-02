%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function figureHandle = ecgLabBeatMove(figureHandle, command)
  % The one path that changes a beat view. It moves the figure's existing
  % objects (XData, YData, String, Visible, FaceColor) and creates none, so the
  % object count stays the same at every beat. The handle is checked as a live
  % beat view first, since this build recycles graphics handle ids.
  state = ecgLabBeatState(figureHandle);
  state = ecgLabBeatApply(state, command);
  view = ecgLabBeatViewOf(state);
  ecgLabBeatDrawTrace(state, view);
  ecgLabBeatDrawFiducials(state, view);
  ecgLabBeatDrawEvidence(state, view);
  ecgLabBeatDrawCard(state, view);
  ecgLabBeatDrawHeader(state, view);
  state.index = view.index;
  state.centre = view.centre;
  state.window = view.window;
  state.current = view.current;
  set(figureHandle, 'UserData', state);
  drawnow();
end
%=============================================================================
function state = ecgLabBeatState(figureHandle)
  % The view's own state, or an error if this is not a live beat view.
  if ~(isscalar(figureHandle) && isgraphics(figureHandle, 'figure')) || ...
    ~strcmp(get(figureHandle, 'Tag'), 'ecglab.beat')
    error('ecglab:staleBeat', 'This is not a live ecglab.beat figure.');
  end
  state = get(figureHandle, 'UserData');
  if ~isstruct(state) || ~isfield(state, 'kind') || ...
    ~strcmp(state.kind, 'ecglab.beat')
    error('ecglab:staleBeat', 'This is not a live ecglab.beat figure.');
  end
end
%=============================================================================
function state = ecgLabBeatApply(state, command)
  % One command, one change of the shown beat. A beat number or 'next'/'previous'
  % follows the beats; {'at', seconds} centres on a moment and shows the nearest.
  count = numel(state.beats.sample);
  if iscell(command)
    if numel(command) ~= 2 || ~(ischar(command{1}) || ...
      isStringScalar(command{1})) || ~strcmpi(char(command{1}), 'at') || ...
      ~isnumeric(command{2}) || ~isscalar(command{2})
      error('ecglab:unknownCommandCellCommandAtSeconds', 'A cell command is {''at'', seconds}.');
    end
    state.centre = double(command{2});
    state.index = ecgLabBeatNearest(state.beats.time, state.centre);
    return;
  end
  if isnumeric(command)
    if ~isscalar(command) || command < 1 || command ~= round(command) || ...
      command > count
      error('ecglab:noSuchBeat', 'The record holds %d beat%s.', count, ecgLabBeatPlural(count));
    end
    state.index = double(command);
    state.centre = NaN;
    return;
  end
  if ~(ischar(command) || isStringScalar(command))
    error('ecglab:unknownCommandUnknownCommand', 'Unknown command.');
  end
  switch lower(char(command))
    case 'next'
      state.index = min(count, ecgLabBeatIndexNow(state) + 1);
      state.centre = NaN;
    case 'previous'
      state.index = max(1, ecgLabBeatIndexNow(state) - 1);
      state.centre = NaN;
    otherwise
      error('ecglab:unknownCommandUnknownCommandS', 'Unknown command: %s.', char(command));
  end
end
%=============================================================================
function index = ecgLabBeatIndexNow(state)
  % The beat a step moves from: the shown index, or the one nearest the centre
  % when the view was last placed on a moment.
  index = state.index;
  if isfinite(state.centre)
    index = ecgLabBeatNearest(state.beats.time, state.centre);
  end
end
%=============================================================================
function index = ecgLabBeatNearest(times, moment)
  [~, index] = min(abs(times(:) - moment));
  index = double(index);
end
%=============================================================================
function view = ecgLabBeatViewOf(state)
  % What one redraw reads: the shown beat, the window of seconds around it, and
  % the class decision. Creates nothing; only decides what the movers write.
  span = state.span;
  index = state.index;
  if isfinite(state.centre)
    centre = state.centre;
  else
    centre = state.beats.time(index);
  end
  view = struct();
  view.index = index;
  view.centre = state.centre;
  view.window = centre + [-span / 2, span / 2];
  view.current = ecgLabBeatClassOf(state, index);
end
%=============================================================================
function current = ecgLabBeatClassOf(state, index)
  % The class of the shown beat and its confidence. A softmax over the stored
  % discriminant scores gives posterior probabilities; confidence is the winner's.
  current = struct('label', '?', 'confidence', NaN);
  classes = state.classes;
  if isempty(classes) || ~isfield(classes, 'label') || ...
    index > numel(classes.label)
    return;
  end
  current.label = classes.label(index);
  if isfield(classes, 'score') && size(classes.score, 1) >= index
    row = classes.score(index, :);
    row = row - max(row);
    weights = exp(row);
    total = sum(weights);
    if total > 0
      current.confidence = max(weights) / total;
    end
  end
end
%=============================================================================
function ecgLabBeatDrawTrace(state, view)
  % Draw the trace in the window, in millimetres: x is seconds past the window
  % start times the speed, y the amplitude times the gain, clipped to the grid.
  trace = state.trace;
  signal = state.signal;
  rate = state.rate;
  N = numel(signal);
  t0 = view.window(1);
  first = max(1, floor(view.window(1) * rate) + 1);
  last = min(N, ceil(view.window(2) * rate) + 1);
  if last < first
    last = first;
  end
  idx = first:last;
  x = ((idx - 1) / rate - t0) * trace.speed;
  y = (trace.vhi - signal(idx)) * trace.gain;
  y = max(0.1, min(trace.Hgrid - 0.1, y));
  set(state.handles.trace.signal, 'XData', x, 'YData', y);
end
%=============================================================================
function ecgLabBeatDrawFiducials(state, view)
  % Draw the delineation on the trace: a tick at every fiducial, a dot at each
  % wave peak, and the peak names P, R and T. A view with no delineation clears
  % them all.
  trace = state.trace;
  handles = state.handles.trace;
  ecgLabBeatClearFiducials(handles);
  waves = state.waves;
  if isempty(waves) || ~isfield(waves, 'time') || ...
    view.index > size(waves.time, 1)
    return;
  end
  t0 = view.window(1);
  speed = trace.speed;
  timeRow = waves.time(view.index, :);
  sampleRow = round(waves.sample(view.index, :));
  present = isfinite(timeRow);
  xf = (timeRow - t0) * speed;
  % The ticks: one broken line from just under the top of the grid to just
  % above its foot, at every present fiducial.
  cols = find(present);
  xt = [];
  yt = [];
  for c = cols
    xt = [xt, xf(c), xf(c), NaN]; %#ok<AGROW>
    yt = [yt, 0.6, trace.Hgrid - 0.6, NaN]; %#ok<AGROW>
  end
  if ~isempty(xt)
    set(handles.ticks, 'XData', xt, 'YData', yt);
  end
  % The dots: at the five wave peaks (P, Q, R, S, T) that are present.
  peakCols = [2, 5, 6, 7, 11];
  peakCols = peakCols(present(peakCols));
  if ~isempty(peakCols)
    dotSamples = min(max(sampleRow(peakCols), 1), numel(state.signal));
    dotX = xf(peakCols);
    dotY = (trace.vhi - state.signal(dotSamples)) * trace.gain;
    dotY = max(0.1, min(trace.Hgrid - 0.1, dotY));
    set(handles.dots, 'XData', dotX, 'YData', dotY);
  end
  % The three peak names, each above its tick in the label band over the grid.
  names = {2, 'P'; 6, 'R'; 11, 'T'};
  for k = 1:3
    col = names{k, 1};
    if present(col)
      set(handles.peakLabels(k), 'Position', [xf(col), -0.6, 0], ...
      'String', names{k, 2});
    end
  end
  ecgLabBeatDrawBrackets(state, view, xf, present);
end
%=============================================================================
function ecgLabBeatDrawBrackets(state, view, xf, present)
  % Draw the three interval brackets under the trace, each on its own row: QRS,
  % PR and QT, labelled in milliseconds. A bracket not fully delineated is omitted.
  trace = state.trace;
  handles = state.handles.trace;
  intervals = [];
  if isfield(state.waves, 'intervals')
    intervals = state.waves.intervals;
  end
  base = trace.Hgrid;
  rows = {8, 4, base + 2.4, 'qrs', 'QRS'; ... % endCol startCol y field name
  4, 1, base + 5.2, 'pr', 'PR'; ...
  12, 4, base + 8.0, 'qt', 'QT'};
  for k = 1:3
    endCol = rows{k, 1};
    startCol = rows{k, 2};
    yr = rows{k, 3};
    field = rows{k, 4};
    name = rows{k, 5};
    ms = NaN;
    if ~isempty(intervals) && isfield(intervals, field)
      ms = intervals.(field)(view.index);
    end
    if present(startCol) && present(endCol) && isfinite(ms)
      xa = xf(startCol);
      xb = xf(endCol);
      set(handles.brackets(k), 'XData', [xa, xa, xb, xb], ...
      'YData', [yr + 0.9, yr, yr, yr + 0.9]);
      set(handles.bracketLabels(k), 'Position', [(xa + xb) / 2, yr + 1.9, 0], ...
      'String', sprintf('%s %d ms', name, round(ms)));
    end
  end
end
%=============================================================================
function ecgLabBeatClearFiducials(handles)
  set(handles.ticks, 'XData', NaN, 'YData', NaN);
  set(handles.dots, 'XData', NaN, 'YData', NaN);
  for k = 1:3
    set(handles.peakLabels(k), 'String', '', 'Position', [NaN, NaN, 0]);
    set(handles.brackets(k), 'XData', NaN, 'YData', NaN);
    set(handles.bracketLabels(k), 'String', '', 'Position', [NaN, NaN, 0]);
  end
end
%=============================================================================
function ecgLabBeatDrawEvidence(state, view)
  % Draw the detector's evidence over the same window: the thresholded feature
  % and the threshold in force, scaled by the series maximum, with the detected
  % beats marked. Axis x is seconds, aligning with the trace above.
  handles = state.handles.evidence;
  evidence = state.evidence;
  rate = state.rate;
  window = view.window;
  set(handles.axes, 'XLim', window);
  set(handles.feature, 'XData', NaN, 'YData', NaN);
  set(handles.threshold, 'XData', NaN, 'YData', NaN);
  set(handles.peak, 'XData', NaN, 'YData', NaN);
  note = sprintf('Detector evidence  -  %s', state.method);
  if evidence.hasFeature
    note = [note, '   (integrated feature and adaptive threshold)'];
  elseif ~isempty(evidence.feature)
    note = [note, '   (band-passed magnitude)'];
  end
  set(handles.label, 'String', note);
  if isempty(evidence.feature)
    return;
  end
  N = numel(evidence.feature);
  first = max(1, floor(window(1) * rate) + 1);
  last = min(N, ceil(window(2) * rate) + 1);
  if last < first
    return;
  end
  idx = first:last;
  scale = evidence.scale;
  xs = (idx - 1) / rate;
  fy = min(1.05, max(0, evidence.feature(idx) / scale));
  set(handles.feature, 'XData', xs, 'YData', fy);
  if ~isempty(evidence.threshold)
    ty = min(1.05, max(0, evidence.threshold(idx) / scale));
    set(handles.threshold, 'XData', xs, 'YData', ty);
  end
  % The detected beats in the window, marked on the feature at their sample.
  inWindow = state.beats.time >= window(1) & state.beats.time <= window(2);
  peakSamples = round(state.beats.sample(inWindow));
  peakSamples = min(max(peakSamples, 1), N);
  if ~isempty(peakSamples)
    px = (peakSamples - 1) / rate;
    py = min(1.05, max(0, evidence.feature(peakSamples) / scale));
    set(handles.peak, 'XData', px, 'YData', py);
  end
end
%=============================================================================
function ecgLabBeatDrawCard(state, view)
  % Draw the class card and intervals card: the AAMI class as a coloured badge
  % with confidence, the feature bars, and the clinical intervals of the beat.
  colour = state.colour;
  card = state.handles.card;
  current = view.current;
  label = current.label;
  [faceColour, fullName] = ecgLabBeatClassLook(colour, label);
  set(card.badge, 'FaceColor', faceColour);
  set(card.badgeText, 'String', label);
  set(card.name, 'String', fullName);
  if isfinite(current.confidence)
    set(card.conf, 'String', sprintf('AAMI class %s   confidence %.2f', ...
    label, current.confidence));
  elseif ~isempty(state.classes)
    set(card.conf, 'String', sprintf('AAMI class %s', label));
  else
    set(card.conf, 'String', 'no classification available');
  end
  ecgLabBeatDrawFeatures(state, view, card);
  ecgLabBeatDrawIntervals(state, view, card);
end
%=============================================================================
function ecgLabBeatDrawFeatures(state, view, card)
  % The feature rows: the label, a bar filled by the beat's place in that
  % feature's range over the record, and the value in its unit.
  rows = state.featureRows;
  classes = state.classes;
  for k = 1:numel(rows)
    row = rows(k);
    value = classes.features(view.index, row.column);
    frac = 0;
    if row.hi > row.lo
      frac = (value - row.lo) / (row.hi - row.lo);
    end
    set(card.featLabel(k), 'String', row.label);
    ecgLabBeatFillBar(card.featFill(k), card.featTrack(k), frac);
    if isfinite(value)
      shown = value * row.scale;
      if isempty(row.unit)
        set(card.featValue(k), 'String', sprintf('%.2f', shown));
      else
        set(card.featValue(k), 'String', sprintf('%.0f %s', shown, row.unit));
      end
    else
      set(card.featValue(k), 'String', '-');
    end
  end
end
%=============================================================================
function ecgLabBeatDrawIntervals(state, view, card)
  % The clinical intervals of the beat, each a bar against a nominal full scale,
  % in milliseconds. An interval the delineation did not close shows as a dash.
  index = view.index;
  values = nan(1, 5);
  if ~isempty(state.waves) && isfield(state.waves, 'intervals')
    iv = state.waves.intervals;
    values(1) = iv.pr(index);
    values(2) = iv.qrs(index);
    values(3) = iv.qt(index);
    if isfield(iv, 'qtc') && isfield(iv.qtc, 'bazett')
      values(4) = iv.qtc.bazett(index);
    end
  end
  values(5) = state.beats.rr(index) * 1000;
  fullScale = [320, 200, 520, 520, 1400];
  for k = 1:5
    frac = 0;
    if isfinite(values(k)) && fullScale(k) > 0
      frac = min(1, max(0, values(k) / fullScale(k)));
    end
    ecgLabBeatFillBar(card.ivFill(k), card.ivTrack(k), frac);
    if isfinite(values(k))
      set(card.ivValue(k), 'String', sprintf('%d ms', round(values(k))));
    else
      set(card.ivValue(k), 'String', '-');
    end
  end
end
%=============================================================================
function ecgLabBeatFillBar(fill, track, frac)
  % Resize a bar's fill to a fraction of its track, reading the track's extent
  % so the fill sits exactly in it whatever the row's position.
  frac = min(1, max(0, frac));
  xt = get(track, 'XData');
  left = min(xt);
  right = max(xt);
  edge = left + frac * (right - left);
  yt = get(track, 'YData');
  set(fill, 'XData', [left, edge, edge, left], 'YData', yt);
end
%=============================================================================
function [faceColour, fullName] = ecgLabBeatClassLook(colour, label)
  % The hue and the long name of an AAMI class, by its letter.
  letters = 'NSVFQ';
  names = {'Normal', 'Supraventricular', 'Ventricular', 'Fusion', ...
  'Unclassifiable'};
  row = find(letters == label, 1);
  if isempty(row)
    faceColour = colour.dim;
    fullName = 'unclassified';
    return;
  end
  faceColour = colour.classes(row, :);
  fullName = names{row};
end
%=============================================================================
function ecgLabBeatDrawHeader(state, view)
  % The header: the record on the left, the beat's place in it on the right.
  handles = state.handles;
  name = state.title;
  if isempty(name)
    name = '';
    if isfield(state.recording, 'info') && isfield(state.recording.info, ...
      'name')
      name = state.recording.info.name;
    end
    if isempty(name)
      name = 'recording';
    end
  end
  set(handles.title, 'String', name);
  count = numel(state.beats.sample);
  lead = state.leadName;
  if isempty(lead)
    lead = 'lead 1';
  end
  set(handles.position, 'String', sprintf(['beat %d of %d    %s    ' ...
  'R at %.3f s'], view.index, count, lead, state.beats.time(view.index)));
end
%=============================================================================
function word = ecgLabBeatPlural(count)
  if count == 1
    word = '';
  else
    word = 's';
  end
end
%=============================================================================
