%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function pageAxes = ecgLabStripPaper(figureHandle, plan, colour)
  % The page under the traces: grid, a calibration pulse per row, lead labels,
  % title, scale and footer, drawn in one full-bleed axis in page millimetres.
  %
  % The axis fills the figure exactly, so its millimetre extent maps to the
  % exported picture (see ecgLabStripSave). Its y runs downward like a printed
  % page, so a positive deflection is baseline minus voltage.
  pageAxes = axes('Parent', figureHandle, 'Units', 'normalized', ...
  'Position', [0 0 1 1], 'Tag', 'ecglab.strip');
  set(pageAxes, 'XLim', [0 plan.Wmm], 'YLim', [0 plan.Hmm], ...
  'YDir', 'reverse', 'XTick', [], 'YTick', [], 'Color', colour.background, ...
  'Box', 'off');
  % No axis frame: on this build an axis colour of 'none' exports as a stray
  % dark rule, so the decorations are turned off while children stay visible.
  set(pageAxes, 'Visible', 'off');
  % The grid first, so every line and word sits over it.
  ecgLabDrawGrid(pageAxes, plan.gridExtent, colour);
  % A calibration pulse per row: up one millivolt (Gain mm), held two
  % millimetres. Each is its own line so its height can be measured.
  for index = 1:numel(plan.calibrations)
    base = plan.calibrations(index);
    top = base - plan.gain;
    line('Parent', pageAxes, 'XData', [1 3 3 5 5 6.5], ...
    'YData', [base base top top base base], 'Color', colour.calibration, ...
    'LineWidth', 0.9, 'Tag', 'ecglab.strip.calibration');
  end
  % Lead label at the top-left of each panel, dimmed when the recording lacks
  % that lead.
  for index = 1:numel(plan.panels)
    panel = plan.panels(index);
    ink = colour.ink;
    name = panel.lead;
    if ~panel.present
      ink = colour.dim;
      name = [name, ' (absent)'];
    end
    text(pageAxes, panel.pageX0 + 1.2, panel.pageY0 + 3.2, name, ...
    'Color', ink, 'FontSize', 7, 'FontWeight', 'bold', ...
    'VerticalAlignment', 'baseline', 'Tag', 'ecglab.strip.label');
  end
  % The title on the left of the top margin, the scale on the right.
  text(pageAxes, 1.5, 4.6, plan.labels.title, 'Color', colour.ink, ...
  'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', 'baseline');
  text(pageAxes, plan.Wmm - 2, 4.6, plan.labels.scale, 'Color', ...
  colour.dim, 'FontSize', 7, 'HorizontalAlignment', 'right', ...
  'VerticalAlignment', 'baseline');
  % The footer along the bottom margin.
  text(pageAxes, 1.5, plan.Hmm - 2.6, plan.labels.footer, 'Color', ...
  colour.dim, 'FontSize', 5.5, 'VerticalAlignment', 'baseline');
end
%=============================================================================
