%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function plan = ecgLabStripPlan(recording, options)
  % The whole page laid out in MILLIMETRES, before any object is drawn, so the
  % paper drawer, the traces and the test share one geometry. The page is
  % 'Speed' mm per second wide and 'Gain' mm per millivolt tall; rewriting the
  % exported file to these millimetres makes 25 mm/s and 10 mm/mV land on a
  % ruler (ecgLabStripSave).
  %
  % PLAN carries: speed, gain, style, layout; Wmm and Hmm (the page in mm);
  % gridExtent [x0 x1 y0 y1] for ecgLabDrawGrid; panels (one per drawn lead,
  % with lead name, presence and column, window [t0 t1], size and baseline in
  % mm, and axes Position); calibrations (the baseline mm of each pulse);
  % labels (title, scale, footer, per-panel label); and rate and samples.
  speed = double(options.Speed);
  gain = double(options.Gain);
  layout = lower(char(options.Layout));
  %===========================================================================
  % The page cells: {lead name, window} entries in R rows by C columns, plus an
  % optional full-width rhythm strip. The millimetre geometry below is shared.
  [cells, R, C, rhythm] = ecgLabStripCells(recording, options, layout, speed);
  %===========================================================================
  % The millimetre frame. Columns are contiguous; the calibration pulse, title
  % and footer sit in margins that carry no grid.
  calW = 9;            % left margin, holds the calibration pulse
  rightMargin = 5;
  topMargin = 7;       % holds the title and the scale
  bottomMargin = 8;    % holds the footer
  gapMid = 6;          % between the lead block and the rhythm strip
  panelH = 26;         % the height of one lead row
  rhythmH = 26;
  panelW = cells(1).t1 - cells(1).t0;
  panelW = panelW * speed;
  gridLeft = calW;
  gridWidth = C * panelW;
  Wmm = gridLeft + gridWidth + rightMargin;
  gridTop = topMargin;
  gridHeight = R * panelH;
  gridBottom = gridTop + gridHeight;
  hasRhythm = ~isempty(rhythm);
  if hasRhythm
    rhythmTop = gridBottom + gapMid;
    contentBottom = rhythmTop + rhythmH;
  else
    rhythmTop = gridBottom;
    contentBottom = gridBottom;
  end
  Hmm = contentBottom + bottomMargin;
  %===========================================================================
  % One panel per cell, its axes Position the millimetre rectangle as a
  % fraction of the page, so a local millimetre equals a page millimetre.
  panels = ecgLabStripPanels(cells, gridLeft, gridTop, panelW, panelH, ...
  Wmm, Hmm, speed);
  if hasRhythm
    rhythmW = (rhythm.t1 - rhythm.t0) * speed;
    panels(end + 1) = ecgLabStripPanel(rhythm.lead, rhythm.present, ...
    rhythm.col, rhythm.t0, rhythm.t1, gridLeft, rhythmTop, rhythmW, ...
    rhythmH, Wmm, Hmm, speed, 'rhythm');
  end
  %===========================================================================
  % A calibration pulse on each row's baseline, so every row carries its own
  % 1 mV = Gain mm reference.
  calibrations = zeros(1, 0);
  for r = 1:R
    calibrations(end + 1) = gridTop + (r - 1) * panelH + panelH / 2;
  end
  if hasRhythm
    calibrations(end + 1) = rhythmTop + rhythmH / 2;
  end
  %===========================================================================
  labels = struct('title', ecgLabStripTitle(recording, options), ...
  'scale', sprintf('%g mm/s   %g mm/mV', speed, gain), ...
  'footer', ecgLabStripFooter(recording, options, rhythm));
  plan = struct('speed', speed, 'gain', gain, 'style', ...
  lower(char(options.Style)), 'layout', layout, 'Wmm', Wmm, 'Hmm', Hmm, ...
  'gridExtent', [0, Wmm, gridTop, contentBottom], 'calLeft', calW, ...
  'panels', panels, 'calibrations', calibrations, 'labels', labels, ...
  'rate', recording.rate, 'samples', {recording.samples});
end
%=============================================================================
function [cells, R, C, rhythm] = ecgLabStripCells(recording, options, ...
  layout, speed)
  % The lead-and-window arrangement of each layout as a flat row-major list of
  % cells, with row and column counts and the rhythm strip if any. A cell is a
  % lead name and the window [t0 t1] it shows.
  start = 0;
  if ~isempty(options.Seconds)
    start = 0;
  end
  rhythm = [];
  switch layout
    case '3x4'
      grid = {'I', 'aVR', 'V1', 'V4'; 'II', 'aVL', 'V2', 'V5'; ...
      'III', 'aVF', 'V3', 'V6'};
      R = 3; C = 4;
      panelSeconds = double(options.PanelSeconds);
      cells = ecgLabStripGridCells(recording, grid, R, C, start, panelSeconds);
      rhythmLead = char(options.RhythmLead);
      rhythmSeconds = double(options.RhythmSeconds);
      rhythm = ecgLabStripCell(recording, rhythmLead, start, ...
      start + rhythmSeconds);
    case '6x2'
      grid = {'I', 'V1'; 'II', 'V2'; 'III', 'V3'; 'aVR', 'V4'; ...
      'aVL', 'V5'; 'aVF', 'V6'};
      R = 6; C = 2;
      window = ecgLabStripWindow(options, recording, 5);
      cells = ecgLabStripGridCells(recording, grid, R, C, start, window);
    case '12x1'
      names = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
      'V4', 'V5', 'V6'};
      names = ecgLabStripLeadOrder(recording, names);
      R = numel(names); C = 1;
      window = ecgLabStripWindow(options, recording, 10);
      grid = reshape(names, R, C);
      cells = ecgLabStripGridCells(recording, grid, R, C, start, window);
    case '1'
      name = ecgLabStripSingleLead(recording, options);
      R = 1; C = 1;
      window = ecgLabStripWindow(options, recording, 10);
      grid = {name};
      cells = ecgLabStripGridCells(recording, grid, R, C, start, window);
    otherwise
      error('ecglab:badLayout', 'The layout is ''3x4'', ''6x2'', ''12x1'' or ''1''.');
  end
end
%=============================================================================
function window = ecgLabStripWindow(options, recording, fallback)
  % Window length in seconds for the stacked and single layouts: 'Seconds' if
  % given, else the layout default, capped at the recording length.
  window = fallback;
  if ~isempty(options.Seconds)
    window = double(options.Seconds);
  end
  window = min(window, recording.seconds);
  if ~(window > 0)
    window = fallback;
  end
end
%=============================================================================
function cells = ecgLabStripGridCells(recording, grid, R, C, start, seconds)
  % One cell per grid position, row major; column c shows the c-th consecutive
  % window, so the columns read as one continuous span left to right.
  cells = ecgLabStripCell(recording, grid{1, 1}, start, start + seconds);
  cells = repmat(cells, 1, R * C);
  index = 0;
  for r = 1:R
    for c = 1:C
      index = index + 1;
      t0 = start + (c - 1) * seconds;
      cells(index) = ecgLabStripCell(recording, grid{r, c}, t0, t0 + seconds);
    end
  end
end
%=============================================================================
function cell = ecgLabStripCell(recording, leadName, t0, t1)
  % One cell: the lead name, whether the recording carries it and its column,
  % and the window it shows.
  col = ecgLabStripFind(recording, leadName);
  cell = struct('lead', leadName, 'present', col > 0, 'col', col, ...
  't0', t0, 't1', t1);
end
%=============================================================================
function panels = ecgLabStripPanels(cells, gridLeft, gridTop, panelW, ...
  panelH, Wmm, Hmm, speed)
  % Place the row-major cells into panels on the grid. The column count is how
  % many leading cells share the first cell's time origin.
  C = 1;
  for k = 2:numel(cells)
    if cells(k).t0 == cells(1).t0
      break;
    end
    C = C + 1;
  end
  panels = repmat(ecgLabStripPanel(cells(1).lead, cells(1).present, ...
  cells(1).col, cells(1).t0, cells(1).t1, gridLeft, gridTop, panelW, ...
  panelH, Wmm, Hmm, speed, cells(1).lead), 1, numel(cells));
  for k = 1:numel(cells)
    r = floor((k - 1) / C) + 1;
    c = mod(k - 1, C) + 1;
    x0 = gridLeft + (c - 1) * panelW;
    y0 = gridTop + (r - 1) * panelH;
    panels(k) = ecgLabStripPanel(cells(k).lead, cells(k).present, ...
    cells(k).col, cells(k).t0, cells(k).t1, x0, y0, panelW, panelH, ...
    Wmm, Hmm, speed, cells(k).lead);
  end
end
%=============================================================================
function panel = ecgLabStripPanel(leadName, present, col, t0, t1, x0, y0, ...
  panelW, panelH, Wmm, Hmm, speed, suffix)
  % One panel's geometry: axes Position as a fraction of the page, local mm
  % limits, the baseline halfway up, and the tag it is found by.
  position = [x0 / Wmm, 1 - (y0 + panelH) / Hmm, panelW / Wmm, panelH / Hmm];
  panel = struct('lead', leadName, 'present', present, 'col', col, ...
  't0', t0, 't1', t1, 'panelW', panelW, 'panelH', panelH, ...
  'base', panelH / 2, 'pageX0', x0, 'pageY0', y0, 'position', position, ...
  'tag', ['ecglab.strip.', suffix], 'speed', speed);
end
%=============================================================================
function col = ecgLabStripFind(recording, name)
  % The column of a lead by name, case-insensitive, or 0 if absent. Aliases let
  % a record whose lead is written 'MLII' answer to the standard 'II'.
  col = find(strcmpi(name, recording.leads), 1);
  if isempty(col)
    aliases = ecgLabStripAlias(name);
    for a = 1:numel(aliases)
      col = find(strcmpi(aliases{a}, recording.leads), 1);
      if ~isempty(col)
        break;
      end
    end
  end
  if isempty(col)
    col = 0;
  end
end
%=============================================================================
function aliases = ecgLabStripAlias(name)
  % The few lead-name spellings a real database uses for a standard name.
  switch upper(char(name))
    case 'II'
      aliases = {'MLII', 'ML2'};
    case 'I'
      aliases = {'MLI', 'ML1'};
    case 'V5'
      aliases = {'MV5'};
    case 'V1'
      aliases = {'MV1'};
    otherwise
      aliases = {};
  end
end
%=============================================================================
function names = ecgLabStripLeadOrder(recording, standard)
  % For the stacked layout, the twelve standard leads when present, else the
  % recording's own lead names, so a two-lead record shows its two leads.
  present = 0;
  for k = 1:numel(standard)
    if ecgLabStripFind(recording, standard{k}) > 0
      present = present + 1;
    end
  end
  if present >= 2
    names = standard;
  else
    names = recording.leads;
  end
end
%=============================================================================
function name = ecgLabStripSingleLead(recording, options)
  % The lead a single-lead page draws: the caller's 'Lead' (name or index) when
  % present, else a common monitor lead, else the first lead.
  if ~isempty(options.Lead)
    if isnumeric(options.Lead) && isscalar(options.Lead)
      idx = round(options.Lead);
      if idx >= 1 && idx <= numel(recording.leads)
        name = recording.leads{idx};
        return;
      end
    elseif ecgLabStripFind(recording, char(options.Lead)) > 0
      name = char(options.Lead);
      return;
    end
  end
  for candidate = {'MLII', 'II', 'I', 'V5'}
    if ecgLabStripFind(recording, candidate{1}) > 0
      name = candidate{1};
      return;
    end
  end
  name = recording.leads{1};
end
%=============================================================================
function title = ecgLabStripTitle(recording, options)
  % The heading: the caller's 'Title', else the recording's name or source.
  if ~isempty(options.Title)
    title = char(options.Title);
    return;
  end
  title = '';
  if isfield(recording, 'info') && isstruct(recording.info)
    title = ecgLabStripField(recording.info, 'name', '');
    if isempty(title)
      title = ecgLabStripField(recording.info, 'source', '');
    end
  end
  if isempty(title)
    title = 'electrocardiogram';
  end
end
%=============================================================================
function footer = ecgLabStripFooter(recording, options, rhythm)
  % The bottom line: the record source, scale, rhythm lead and length if any,
  % module version, and the not-for-clinical-use statement.
  source = '';
  if isfield(recording, 'info') && isstruct(recording.info)
    source = ecgLabStripField(recording.info, 'source', '');
    if isempty(source)
      source = ecgLabStripField(recording.info, 'name', '');
    end
  end
  if isempty(source)
    source = 'ecglab';
  end
  strip = '';
  if ~isempty(rhythm)
    strip = sprintf('   %s rhythm, %g s', rhythm.lead, rhythm.t1 - rhythm.t0);
  end
  footer = sprintf(['%s   %g mm/s   %g mm/mV%s   ecglab %s   research ' ...
  'software, not a medical device, not for clinical use'], source, ...
  double(options.Speed), double(options.Gain), strip, ecgLabStripVersion());
end
%=============================================================================
function value = ecgLabStripField(s, name, fallback)
  value = fallback;
  if isstruct(s) && isfield(s, name) && ~isempty(s.(name)) && ...
    ischar(s.(name))
    value = s.(name);
  end
end
%=============================================================================
function version = ecgLabStripVersion()
  % The module version for the footer, or empty when it cannot be read.
  version = '';
  try
    version = ecglab_version();
  catch
    version = '';
  end
end
%=============================================================================
