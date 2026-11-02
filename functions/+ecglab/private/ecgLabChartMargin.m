%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabChartMargin(handle, plan, colour)
  % The right margin: the class counts, the variability summary and the Poincare
  % plot. The counts bar is a raster and the cloud one line of markers.
  ecgLabChartCountsPanel(handle, plan, colour);
  ecgLabChartHrvPanel(handle, plan, colour);
  ecgLabChartPoincarePanel(handle, plan, colour);
end
%=============================================================================
function ax = ecgLabChartMarginAxes(handle, plan, topPx, heightPx, name)
  % One margin panel as a plain axis in unit coordinates, no frame, tagged so a
  % test can find it.
  ax = axes('Parent', handle, 'Units', 'normalized', 'Position', ...
  [plan.marginLeft, 1 - (topPx + heightPx) / plan.height, ...
  plan.marginWidth, heightPx / plan.height], 'Tag', ...
  ['ecglab.chart.', name]);
  set(ax, 'XLim', [0 1], 'YLim', [0 1], 'YDir', 'normal', 'Visible', 'off');
end
%=============================================================================
function ecgLabChartCountsPanel(handle, plan, colour)
  % The beats by AAMI class: a stacked bar of the class shares and a key with
  % each class and its count. A class with no beats keeps its place in the key.
  ax = ecgLabChartMarginAxes(handle, plan, 250, 150, 'counts');
  text(ax, 0, 0.94, 'BEATS BY CLASS', 'Color', colour.dim, 'FontSize', ...
  8.5, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  counts = plan.counts;
  letters = {'N', 'S', 'V', 'F', 'Q'};
  names = {'Normal', 'Supraventricular', 'Ventricular', 'Fusion', 'Unknown'};
  values = [counts.N, counts.S, counts.V, counts.F, counts.Q];
  if all(isnan(values))
    text(ax, 0, 0.6, 'no classification', 'Color', colour.dim, ...
    'FontSize', 9, 'VerticalAlignment', 'middle');
    return;
  end
  values(isnan(values)) = 0;
  total = sum(values);
  % The stacked bar, painted into one raster: each class a box of its share,
  % in the class hue, so a reader sees the mix without reading the numbers.
  if total > 0
    raster = ecgLabDrawRaster(ax, 12, 360, colour.background, [0 1], ...
    [0.74 0.86]);
    cumulative = 0;
    x0 = zeros(1, 5);
    x1 = zeros(1, 5);
    for index = 1:5
      x0(index) = cumulative / total;
      cumulative = cumulative + values(index);
      x1(index) = cumulative / total;
    end
    keep = values > 0;
    raster = ecgLabDrawRaster(raster, x0(keep), x1(keep), 1, 12, ...
    plan.classColours(keep, :));
    ecgLabDrawRaster(raster);
  end
  y = 0.60;
  for index = 1:5
    patch('Parent', ax, 'XData', [0 0.035 0.035 0], 'YData', ...
    y + [-0.03 -0.03 0.03 0.03], 'FaceColor', plan.classColours(index, :), ...
    'EdgeColor', 'none');
    text(ax, 0.06, y, names{index}, 'Color', colour.ink, 'FontSize', 9, ...
    'VerticalAlignment', 'middle');
    text(ax, 1, y, sprintf('%d', values(index)), 'Color', colour.ink, ...
    'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle');
    y = y - 0.12;
  end
end
%=============================================================================
function ecgLabChartHrvPanel(handle, plan, colour)
  % The variability summary: SDNN, RMSSD, pNN50, the LF/HF ratio and the two
  % Poincare descriptors, each a label and a value, using the Task Force names.
  ax = ecgLabChartMarginAxes(handle, plan, 424, 210, 'hrv');
  text(ax, 0, 0.95, 'VARIABILITY   (Task Force)', 'Color', colour.dim, ...
  'FontSize', 8.5, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  hrv = plan.hrv;
  rows = {'SDNN', hrv.sdnn, 'ms'; 'RMSSD', hrv.rmssd, 'ms'; ...
  'pNN50', hrv.pnn50, '%'; 'LF / HF', hrv.lfhf, ''; ...
  'SD1', hrv.sd1, 'ms'; 'SD2', hrv.sd2, 'ms'};
  y = 0.78;
  dy = 0.135;
  for index = 1:size(rows, 1)
    text(ax, 0, y, rows{index, 1}, 'Color', colour.dim, 'FontSize', 9, ...
    'VerticalAlignment', 'middle');
    text(ax, 0.95, y, ecgLabChartHrvValue(rows{index, 2}), 'Color', ...
    colour.ink, 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    if ~isempty(rows{index, 3})
      text(ax, 0.97, y, [' ', rows{index, 3}], 'Color', colour.dim, ...
      'FontSize', 8, 'VerticalAlignment', 'middle');
    end
    y = y - dy;
  end
end
%=============================================================================
function text = ecgLabChartHrvValue(value)
  if isnan(value)
    text = '--';
  elseif value >= 100
    text = sprintf('%.0f', value);
  else
    text = sprintf('%.1f', value);
  end
end
%=============================================================================
function ecgLabChartPoincarePanel(handle, plan, colour)
  % The Poincare plot: RR(n) against RR(n+1), whose width across the line of
  % identity is SD1 and length along it SD2. The points are one line of markers,
  % the ellipse one line. The axis is square in pixels so the cloud stays round.
  title = ecgLabChartMarginAxes(handle, plan, 660, 20, 'poincaretitle');
  text(title, 0, 0.5, 'POINCARE   RR(n) vs RR(n+1), ms', 'Color', ...
  colour.dim, 'FontSize', 8.5, 'FontWeight', 'bold', ...
  'VerticalAlignment', 'middle');
  side = 260;
  left = 880 + (plan.marginWidth * plan.width - side) / 2;
  ax = axes('Parent', handle, 'Units', 'normalized', 'Position', ...
  [left / plan.width, 1 - (686 + side) / plan.height, side / plan.width, ...
  side / plan.height], 'Tag', 'ecglab.chart.poincare');
  poincare = plan.poincare;
  if ~poincare.present
    set(ax, 'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off');
    text(ax, 0.5, 0.5, 'not enough intervals', 'Color', colour.dim, ...
    'FontSize', 9, 'HorizontalAlignment', 'center');
    return;
  end
  x = poincare.x;
  y = poincare.y;
  lo = min([x; y]);
  hi = max([x; y]);
  pad = 0.08 * (hi - lo) + 10;
  lo = lo - pad;
  hi = hi + pad;
  set(ax, 'XLim', [lo hi], 'YLim', [lo hi], 'Color', colour.background, ...
  'XColor', colour.dim, 'YColor', colour.dim, 'FontSize', 7, 'Box', 'on', ...
  'Layer', 'top');
  % The line of identity, then the SD1/SD2 ellipse about the cloud centre, then
  % the cloud itself.
  line('Parent', ax, 'XData', [lo hi], 'YData', [lo hi], 'Color', ...
  colour.frame, 'LineStyle', ':', 'LineWidth', 0.75);
  ecgLabChartEllipse(ax, x, y, plan.hrv, colour);
  line('Parent', ax, 'XData', x, 'YData', y, 'LineStyle', 'none', ...
  'Marker', '.', 'MarkerSize', 7, 'Color', colour.calibration, 'Tag', ...
  'ecglab.chart.poincare.cloud');
end
%=============================================================================
function ecgLabChartEllipse(ax, x, y, hrv, colour)
  % The Poincare ellipse: centred on the mean pair, half-axis SD2 along the line
  % of identity and SD1 across it. Drawn as one line.
  if isnan(hrv.sd1) || isnan(hrv.sd2)
    return;
  end
  cx = mean(x);
  cy = mean(y);
  along = [1 1] / sqrt(2);
  across = [-1 1] / sqrt(2);
  t = linspace(0, 2 * pi, 80);
  ex = cx + hrv.sd2 * cos(t) * along(1) + hrv.sd1 * sin(t) * across(1);
  ey = cy + hrv.sd2 * cos(t) * along(2) + hrv.sd1 * sin(t) * across(2);
  line('Parent', ax, 'XData', ex, 'YData', ey, 'Color', colour.classV, ...
  'LineWidth', 1);
end
%=============================================================================
