%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabChartHeader(handle, plan, colour)
  % The header: two lines naming the recording and the detector, then the row of
  % summary tiles. The tiles are fixed shapes drawn as patches and lines.
  head = axes('Parent', handle, 'Units', 'normalized', ...
  'Position', [0.035, 1 - 80 / 1100, 0.94, 56 / 1100], 'Tag', ...
  'ecglab.chart.header');
  set(head, 'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off');
  text(head, 0, 0.78, plan.headerLine1, 'Color', colour.ink, ...
  'FontSize', 13, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  text(head, 0, 0.26, plan.headerLine2, 'Color', colour.dim, ...
  'FontSize', 9, 'VerticalAlignment', 'middle');
  %===========================================================================
  % The tiles on one unit-square axis; the axis vector diagram gets a square
  % sub-axis of its own so its circle stays round.
  tilesPos = [0.035, 1 - (92 + 128) / 1100, 0.94, 128 / 1100];
  tiles = axes('Parent', handle, 'Units', 'normalized', 'Position', ...
  tilesPos, 'Tag', 'ecglab.chart.tiles');
  set(tiles, 'XLim', [0 1], 'YLim', [0 1], 'YDir', 'normal', 'Visible', ...
  'off');
  specs = ecgLabChartTileList(plan.headline);
  count = numel(specs);
  gap = 0.012;
  tileW = (1 - (count - 1) * gap) / count;
  for index = 1:count
    x0 = (index - 1) * (tileW + gap);
    ecgLabChartTile(tiles, handle, tilesPos, specs{index}, x0, tileW, colour);
  end
end
%=============================================================================
function specs = ecgLabChartTileList(headline)
  % The tiles, left to right: heart rate, rhythm and burden, PR, QRS, QT with
  % its corrections, the frontal axis when leads ran, and signal quality. Each
  % carries a normal-range chip where one applies.
  specs = {};
  specs{end + 1} = ecgLabChartHrTile(headline);
  specs{end + 1} = ecgLabChartRhythmTile(headline);
  specs{end + 1} = ecgLabChartIntervalTile('PR', headline.pr, ...
  'onset P to QRS', headline.prNormal);
  specs{end + 1} = ecgLabChartIntervalTile('QRS', headline.qrs, ...
  'QRS duration', headline.qrsNormal);
  specs{end + 1} = ecgLabChartQtTile(headline);
  if headline.hasLeads
    specs{end + 1} = ecgLabChartAxisTile(headline);
  end
  specs{end + 1} = ecgLabChartQualityTile(headline);
end
%=============================================================================
function tile = ecgLabChartHrTile(headline)
  hr = headline.heartRate;
  sub = '';
  if ~isnan(headline.heartRateMin) && ~isnan(headline.heartRateMax)
    sub = sprintf('%d-%d bpm', round(headline.heartRateMin), ...
    round(headline.heartRateMax));
  end
  chip = ecgLabChartChip('ok', 'sinus');
  if ~isempty(headline.rhythm) && ~strcmp(headline.rhythm, 'N')
    chip = ecgLabChartChip('warn', lower(headline.rhythm));
  end
  tile = ecgLabChartPlainTile('Heart rate', ecgLabChartNum(hr), 'bpm', ...
  sub, chip);
end
%=============================================================================
function tile = ecgLabChartRhythmTile(headline)
  label = headline.rhythm;
  if isempty(label) || strcmp(label, 'N')
    label = 'NSR';
  end
  burden = headline.afBurden;
  sub = '';
  chip = [];
  if ~isnan(burden)
    sub = sprintf('AF burden %.0f %%', 100 * burden);
    if burden > 0
      chip = ecgLabChartChip('warn', 'AF');
    else
      chip = ecgLabChartChip('ok', 'regular');
    end
  end
  tile = ecgLabChartPlainTile('Rhythm', label, '', sub, chip);
  tile.valueFontSize = 20;
end
%=============================================================================
function tile = ecgLabChartIntervalTile(name, value, sub, inRange)
  chip = ecgLabChartRangeChip(inRange);
  tile = ecgLabChartPlainTile(name, ecgLabChartNum(value), 'ms', sub, chip);
end
%=============================================================================
function tile = ecgLabChartQtTile(headline)
  % The QT tile is a small table: the raw QT and the four corrected values, so
  % the page does not hide which correction a QTc came from.
  tile = struct('kind', 'qt', 'key', 'QT / QTc', 'qt', headline.qt, ...
  'bazett', headline.qtcBazett, 'fridericia', headline.qtcFridericia, ...
  'framingham', headline.qtcFramingham, 'hodges', headline.qtcHodges, ...
  'chip', ecgLabChartRangeChip(headline.qtcNormal));
end
%=============================================================================
function tile = ecgLabChartAxisTile(headline)
  degrees = headline.axisDegrees;
  value = ecgLabChartSignedNum(degrees);
  tile = struct('kind', 'axis', 'key', 'Frontal axis', 'value', value, ...
  'unit', 'deg', 'sub', headline.axisLabel, 'degrees', degrees, ...
  'chip', ecgLabChartRangeChip(headline.axisNormal));
end
%=============================================================================
function tile = ecgLabChartQualityTile(headline)
  quality = headline.quality;
  chip = [];
  if ~isnan(quality)
    if quality >= 0.8
      chip = ecgLabChartChip('ok', 'good');
    elseif quality >= 0.5
      chip = ecgLabChartChip('warn', 'fair');
    else
      chip = ecgLabChartChip('crit', 'poor');
    end
  end
  value = '--';
  if ~isnan(quality)
    value = sprintf('%d', round(100 * quality));
  end
  tile = ecgLabChartPlainTile('Signal quality', value, '%', 'usable', chip);
end
%=============================================================================
function tile = ecgLabChartPlainTile(key, value, unit, sub, chip)
  tile = struct('kind', 'plain', 'key', key, 'value', value, 'unit', unit, ...
  'sub', sub, 'chip', chip, 'valueFontSize', 24);
end
%=============================================================================
function chip = ecgLabChartChip(level, text)
  chip = struct('level', level, 'text', text);
end
%=============================================================================
function chip = ecgLabChartRangeChip(inRange)
  % The chip for a measurement with a normal range: 'normal' inside, 'check'
  % outside. A value outside is flagged, not interpreted.
  if inRange
    chip = ecgLabChartChip('ok', 'normal');
  else
    chip = ecgLabChartChip('warn', 'check');
  end
end
%=============================================================================
function text = ecgLabChartNum(value)
  if isnan(value)
    text = '--';
  else
    text = sprintf('%d', round(value));
  end
end
%=============================================================================
function text = ecgLabChartSignedNum(value)
  if isnan(value)
    text = '--';
  else
    text = sprintf('%+d', round(value));
  end
end
%=============================================================================
function ecgLabChartTile(tiles, handle, tilesPos, spec, x0, tileW, colour)
  % One tile: a white card with its key on top, its value large, a sub line and
  % a chip at the foot. The axis tile adds a small vector diagram.
  face = [1 1 1];
  patch('Parent', tiles, 'XData', [x0, x0 + tileW, x0 + tileW, x0], ...
  'YData', [0.04 0.04 0.98 0.98], 'FaceColor', face, 'EdgeColor', ...
  colour.frame, 'LineWidth', 0.75);
  pad = 0.03 * tileW;
  text(tiles, x0 + pad, 0.9, upper(spec.key), 'Color', colour.dim, ...
  'FontSize', 8.5, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  switch spec.kind
    case 'qt'
      ecgLabChartQtBody(tiles, spec, x0, tileW, colour);
    case 'axis'
      ecgLabChartAxisBody(tiles, handle, tilesPos, spec, x0, tileW, colour);
    otherwise
      ecgLabChartPlainBody(tiles, spec, x0, tileW, colour);
  end
  if ~isempty(spec.chip)
    ecgLabChartDrawChip(tiles, spec.chip, x0 + pad, 0.12, colour);
  end
end
%=============================================================================
function ecgLabChartPlainBody(tiles, spec, x0, tileW, colour)
  pad = 0.03 * tileW;
  value = spec.value;
  unit = spec.unit;
  txt = text(tiles, x0 + pad, 0.52, value, 'Color', colour.ink, ...
  'FontSize', spec.valueFontSize, 'FontWeight', 'bold', ...
  'VerticalAlignment', 'middle');
  extent = get(txt, 'Extent');
  if ~isempty(unit)
    text(tiles, extent(1) + extent(3) + 0.01, 0.44, unit, 'Color', ...
    colour.dim, 'FontSize', 10, 'VerticalAlignment', 'middle');
  end
  if ~isempty(spec.sub)
    text(tiles, x0 + pad, 0.28, spec.sub, 'Color', colour.dim, ...
    'FontSize', 8.5, 'VerticalAlignment', 'middle');
  end
end
%=============================================================================
function ecgLabChartQtBody(tiles, spec, x0, tileW, colour)
  % The QT table: the raw QT then the four corrections, each a label on the
  % left and the number on the right, in two small columns.
  pad = 0.03 * tileW;
  rightX = x0 + tileW - pad;
  rows = {'QT', spec.qt; 'Bazett', spec.bazett; 'Frideri.', ...
  spec.fridericia; 'Framing.', spec.framingham; 'Hodges', spec.hodges};
  y = 0.78;
  dy = 0.125;
  for index = 1:size(rows, 1)
    text(tiles, x0 + pad, y, rows{index, 1}, 'Color', colour.dim, ...
    'FontSize', 8.5, 'VerticalAlignment', 'middle');
    text(tiles, rightX, y, ecgLabChartNum(rows{index, 2}), 'Color', ...
    colour.ink, 'FontSize', 9.5, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    y = y - dy;
  end
end
%=============================================================================
function ecgLabChartAxisBody(tiles, handle, tilesPos, spec, x0, tileW, colour)
  % The axis tile: the degrees on the left and a small hexaxial vector diagram
  % on the right, with the mean QRS vector drawn as a spoke.
  pad = 0.03 * tileW;
  text(tiles, x0 + pad, 0.52, spec.value, 'Color', colour.ink, ...
  'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  text(tiles, x0 + pad, 0.28, spec.sub, 'Color', colour.dim, 'FontSize', ...
  8.5, 'VerticalAlignment', 'middle');
  % The sub-axis position in figure-normalized coordinates, over the right of
  % the tile. Width and height are the same number of pixels so the circle is
  % round; each is computed from its own page dimension.
  sidePx = 66;
  wFig = sidePx / 1400;
  hFig = sidePx / 1100;
  tileRightFig = tilesPos(1) + (x0 + tileW) * tilesPos(3);
  figX = tileRightFig - wFig - 0.006;
  figY = tilesPos(2) + 0.5 * tilesPos(4) - hFig / 2;
  vec = axes('Parent', handle, 'Units', 'normalized', 'Position', ...
  [figX, figY, wFig, hFig], 'Tag', 'ecglab.chart.axisvector');
  set(vec, 'XLim', [-1.2 1.2], 'YLim', [-1.2 1.2], 'Visible', 'off');
  theta = linspace(0, 2 * pi, 64);
  line('Parent', vec, 'XData', cos(theta), 'YData', sin(theta), 'Color', ...
  colour.frame, 'LineWidth', 0.75);
  line('Parent', vec, 'XData', [-1 1], 'YData', [0 0], 'Color', ...
  colour.frame, 'LineWidth', 0.5);
  line('Parent', vec, 'XData', [0 0], 'YData', [-1 1], 'Color', ...
  colour.frame, 'LineWidth', 0.5);
  if ~isnan(spec.degrees)
    % The frontal plane points degrees downward for a positive axis (lead aVF
    % is +90 and points down), so the spoke uses +sin for its y.
    rad = spec.degrees * pi / 180;
    line('Parent', vec, 'XData', [0 cos(rad)], 'YData', [0 sin(rad)], ...
    'Color', colour.calibration, 'LineWidth', 2);
  end
end
%=============================================================================
function ecgLabChartDrawChip(tiles, chip, x, y, colour)
  % A chip: a word in its level colour on a tint of it, showing at a glance
  % whether a measurement sits inside its reference range.
  rgb = ecgLabChartChipColour(chip.level);
  tint = rgb + (colour.background - rgb) * 0.8;
  label = [' ', chip.text, ' '];
  t = text(tiles, x, y, label, 'Color', rgb, 'FontSize', 8.5, ...
  'FontWeight', 'bold', 'VerticalAlignment', 'middle', 'BackgroundColor', ...
  tint, 'Margin', 1);
end
%=============================================================================
function rgb = ecgLabChartChipColour(level)
  % The three chip levels as fixed status colours: green for in range, amber
  % for check, red for out of range.
  switch level
    case 'ok'
      rgb = [0.18 0.49 0.32];
    case 'warn'
      rgb = [0.75 0.48 0.00];
    otherwise
      rgb = [0.75 0.22 0.17];
  end
end
%=============================================================================
