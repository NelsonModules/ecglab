%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function handle = strip(X, varargin)
  % HANDLE = ECGLAB.STRIP(X) draws the electrocardiogram of X on calibrated grid
  % paper like a clinical electrocardiograph: 25 mm/s and 10 mm/mV, a red grid at
  % 1 mm and 5 mm, and a 1 mV calibration pulse at the start of each row. HANDLE
  % is the figure.
  %
  % HANDLE = ECGLAB.STRIP(X, 'Name', value, ...) sets the layout, the scale
  % and the style. X is an ecglab.recording, or a signal vector whose rate is
  % given as 'Rate'.
  %
  % The page is drawn in millimetres (x is time times speed, y is minus voltage
  % times gain), and the saved vector file's declared size is the page's
  % millimetres, so a ruler reads 25 mm/s and 10 mm/mV on the printed page.
  %
  % Layouts ('Layout'):
  %   '3x4'   the clinical page (default): twelve panels in three rows and
  %           four columns, the rows I aVR V1 V4 / II aVL V2 V5 / III aVF V3
  %           V6, each panel a 'PanelSeconds' window (default 2.5 s) and the
  %           four columns the four consecutive slices of one ten second
  %           acquisition, with a full-width rhythm strip of lead II
  %           ('RhythmLead') below showing 'RhythmSeconds' (default 10 s).
  %   '6x2'   twelve panels in six rows and two columns, the limb leads left
  %           and the precordial leads right, each a 'Seconds' window.
  %   '12x1'  the twelve leads stacked, each one long strip of 'Seconds'.
  %   '1'     a single lead ('Lead'), one long strip of 'Seconds'.
  %
  % Options (name and value, case insensitive):
  %   'Layout'        one of the four above (default '3x4').
  %   'Lead'          the lead of the single-lead layout, a name or a column
  %                   index (default the first of MLII, II, I, V5, or lead 1).
  %   'RhythmLead'    the lead of the 3x4 rhythm strip (default 'II').
  %   'Seconds'       the window in seconds the stacked and single layouts
  %                   draw from the start (default 10 for '12x1' and '1',
  %                   5 for '6x2').
  %   'PanelSeconds'  the window of one 3x4 panel (default 2.5).
  %   'RhythmSeconds' the length of the 3x4 rhythm strip (default 10).
  %   'Speed'         millimetres per second (default 25).
  %   'Gain'          millimetres per millivolt (default 10).
  %   'Style'         'paper' (default, a salmon grid on cream), 'bw' (a grey
  %                   grid) or 'monitor' (a dark screen, a bright trace).
  %   'Rate'          the sampling rate, required when X is a vector.
  %   'Visible'       'on' (default) or 'off'.
  %   'OutputImage'   a file the page is saved to (an .svg keeps the
  %                   millimetre calibration; .png and .pdf are also written).
  %   'Title'         a heading of your own, replacing the recording's name.
  %
  % The figure's UserData carries the plan (page millimetres, panels, scale) for
  % a caller to measure.
  %
  % ecglab is research and teaching software, not a medical device: a strip
  % is a picture of a signal, never a clinical record or a diagnosis.
  %
  % Example:
  %   recording = ecglab.simulate('Seconds', 12, 'Leads', 12, 'Seed', 1);
  %   ecglab.strip(recording, 'OutputImage', 'ecg.svg');
  %
  % See also ecglab.chart, ecglab.beat, ecglab.simulate.
  nargoutchk(0, 1);
  defaults = struct('Layout', '3x4', 'Lead', [], 'RhythmLead', 'II', ...
  'Seconds', [], 'PanelSeconds', 2.5, 'RhythmSeconds', 10, 'Speed', 25, ...
  'Gain', 10, 'Style', 'paper', 'Rate', [], 'Visible', 'on', ...
  'OutputImage', '', 'Title', '');
  options = ecgLabOptions(defaults, varargin);
  ecgLabStripCheck(options);
  recording = ecgLabStripResolve(X, options);
  colour = ecgLabDrawPalette(options.Style);
  plan = ecgLabStripPlan(recording, options);
  %===========================================================================
  % Size the figure to the page's millimetre proportions so the squares stay
  % square on screen; the exported vector file is calibrated regardless.
  pixelsPerMm = 4;
  width = round(plan.Wmm * pixelsPerMm);
  height = round(plan.Hmm * pixelsPerMm);
  % Built on a hidden figure and revealed once at the end.
  handle = figure('Name', 'Nelson ecglab', 'NumberTitle', 'off', ...
  'Color', colour.background, 'Visible', 'off', ...
  'MenuBar', 'none', 'ToolBar', 'none', 'SelectionHighlight', 'off', ...
  'Position', [40 40 width height]);
  ecgLabStripPaper(handle, plan, colour);
  %===========================================================================
  % One transparent axis per panel over the grid, holding that lead's trace in
  % millimetres. The axis exists even when the lead is absent.
  for index = 1:numel(plan.panels)
    ecgLabStripTrace(handle, plan.panels(index), plan, colour);
  end
  set(handle, 'UserData', plan);
  if ~isempty(options.OutputImage)
    ecgLabStripSave(handle, options.OutputImage, plan);
  end
  if strcmpi(options.Visible, 'on')
    set(handle, 'Visible', 'on');
  end
  drawnow();
end
%=============================================================================
function ecgLabStripCheck(options)
  % Validate the options a page cannot draw without, before any figure is opened.
  if ~any(strcmpi(options.Layout, {'3x4', '6x2', '12x1', '1'}))
    error('ecglab:badLayout', 'The layout is ''3x4'', ''6x2'', ''12x1'' or ''1''.');
  end
  if ~any(strcmpi(options.Visible, {'on', 'off'}))
    error('ecglab:badVisible', 'The ''Visible'' option is ''on'' or ''off''.');
  end
  ecgLabStripPositive(options.Speed, 'Speed');
  ecgLabStripPositive(options.Gain, 'Gain');
  % The style is validated by the palette, so its message is raised there.
  ecgLabDrawPalette(options.Style);
end
%=============================================================================
function ecgLabStripPositive(value, name)
  if ~isnumeric(value) || ~isscalar(value) || ~(value > 0) || ~isfinite(value)
    error('ecglab:badScaleSOptionOnePositive', 'The ''%s'' option is one positive number.', name);
  end
end
%=============================================================================
function ecgLabStripTrace(figureHandle, panel, plan, colour)
  % One panel's axis and trace. The axis is transparent with no frame and y
  % downward (positive deflection up as baseline minus voltage); the trace is
  % clipped to the panel so a tall beat cannot spill into the row above.
  panelAxes = axes('Parent', figureHandle, 'Units', 'normalized', ...
  'Position', panel.position, 'Tag', panel.tag);
  set(panelAxes, 'XLim', [0 panel.panelW], 'YLim', [0 panel.panelH], ...
  'YDir', 'reverse', 'XTick', [], 'YTick', [], 'Color', 'none', ...
  'Box', 'off', 'Clipping', 'on');
  % No frame: an axis colour of 'none' exports as a stray dark rule on this
  % build, so the axis decorations are off while its trace child stays visible.
  set(panelAxes, 'Visible', 'off');
  if ~panel.present
    % No such lead: an empty line keeps a trace object in every panel.
    line('Parent', panelAxes, 'XData', NaN, 'YData', NaN, 'Color', ...
    colour.trace, 'Tag', 'ecglab.strip.trace');
    return;
  end
  rate = plan.rate;
  n = size(plan.samples, 1);
  first = max(1, floor(panel.t0 * rate) + 1);
  last = min(n, floor(panel.t1 * rate));
  if last < first
    last = first;
  end
  idx = first:last;
  x = ((idx - 1) / rate - panel.t0) * plan.speed;
  v = plan.samples(idx, panel.col);
  y = panel.base - v * plan.gain;
  % Clip the deflection into the panel so a tall beat does not run into its
  % neighbour; amplitude past the clip is off the paper.
  margin = 0.4;
  y = max(margin, min(panel.panelH - margin, y));
  line('Parent', panelAxes, 'XData', x, 'YData', y, 'Color', ...
  colour.trace, 'LineWidth', 0.6, 'Tag', 'ecglab.strip.trace');
end
%=============================================================================
