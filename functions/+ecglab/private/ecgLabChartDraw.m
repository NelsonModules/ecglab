%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabChartDraw(lanes, plan, colour)
  % Draw every time lane into its axes. Each fill is an image raster and each
  % trace one line, so a record of thousands of beats draws quickly.
  ecgLabChartStripLane(lanes.axes.strip, plan, colour);
  ecgLabChartTachoLane(lanes.axes.tachogram, plan, colour);
  ecgLabChartBeatsLane(lanes.axes.beats, plan, colour);
  ecgLabChartEpisodeLane(lanes.axes.episodes, plan, colour);
  ecgLabChartRateLane(lanes.axes.rate, plan, colour);
  ecgLabChartDividerLane(lanes.axes.divider, plan, colour);
  ecgLabChartEvidenceLane(lanes.axes.evidence, plan, colour);
end
%=============================================================================
function ecgLabChartStripLane(ax, plan, colour)
  % The rhythm strip: one lead over the whole record on the paper grid. The grid
  % is ruled 5-to-1 at the time tick step so it lines up down the page.
  strip = plan.strip;
  set(ax, 'YLim', [strip.ylo strip.yhi], 'YTick', []);
  extent = [0, plan.seconds, strip.ylo, strip.yhi];
  ecgLabDrawGrid(ax, extent, colour, 'Minor', plan.tickStep / 5, 'Major', ...
  plan.tickStep, 'MinorWidth', 0.25, 'MajorWidth', 0.5);
  line('Parent', ax, 'XData', strip.time, 'YData', strip.signal, 'Color', ...
  colour.trace, 'LineWidth', 0.5, 'Tag', 'ecglab.chart.strip.trace');
  text(ax, plan.seconds * 0.004, strip.yhi, [' ', strip.lead], 'Color', ...
  colour.ink, 'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', ...
  'top');
  ecgLabChartLaneTitle(ax, plan, 'rhythm strip', colour);
end
%=============================================================================
function ecgLabChartTachoLane(ax, plan, colour)
  % The RR tachogram: the RR interval in milliseconds against time, a broken
  % line whose pen lifts at the first beat (no interval before it).
  ms = plan.tacho.ms;
  finite = ms(isfinite(ms));
  [lo, hi] = ecgLabChartRange(finite, 600, 1000, 60);
  set(ax, 'YLim', [lo hi], 'YTick', round(linspace(lo, hi, 3)));
  line('Parent', ax, 'XData', plan.tacho.time, 'YData', ms, 'Color', ...
  colour.calibration, 'LineWidth', 1, 'Marker', '.', 'MarkerSize', 4, ...
  'Tag', 'ecglab.chart.tacho.line');
  ecgLabChartLaneTitle(ax, plan, 'RR interval, ms', colour);
end
%=============================================================================
function ecgLabChartBeatsLane(ax, plan, colour)
  % The beats by AAMI class, one row per class N S V F Q from the bottom, each
  % beat a coloured box. The whole lane is painted into one raster and drawn once.
  beats = plan.beats;
  letters = {'N', 'S', 'V', 'F', 'Q'};
  rowsPer = 10;
  nRows = 5 * rowsPer;
  set(ax, 'YLim', [0 5], 'YTick', 0.5:1:4.5, 'YTickLabel', letters);
  raster = ecgLabDrawRaster(ax, nRows, beats.columns, colour.background, ...
  [0 plan.seconds], [0 5]);
  if ~isempty(beats.time)
    time = beats.time(:)';
    x0 = time - beats.halfWidth;
    x1 = time + beats.halfWidth;
    row = beats.row(:)';
    low = (row - 1) * rowsPer + 1;
    high = row * rowsPer;
    if beats.present
      rgb = plan.classColours(row, :);
    else
      rgb = repmat(colour.dim, numel(time), 1);
      low = 2 * rowsPer + 1;
      high = 3 * rowsPer;
    end
    raster = ecgLabDrawRaster(raster, x0, x1, low, high, rgb);
  end
  ecgLabDrawRaster(raster);
  ecgLabChartLaneTitle(ax, plan, 'beats by class', colour);
end
%=============================================================================
function ecgLabChartEpisodeLane(ax, plan, colour)
  % The rhythm episodes that are not plain sinus, as coloured bands over their
  % span, painted into one raster. When there is none, the lane says so.
  episodes = plan.episodes;
  set(ax, 'YLim', [0 1], 'YTick', []);
  raster = ecgLabDrawRaster(ax, 10, max(60, round(plan.lanesWidth * ...
  plan.width)), colour.background, [0 plan.seconds], [0 1]);
  if episodes.present
    raster = ecgLabDrawRaster(raster, episodes.onset(:)', ...
    episodes.offset(:)', 1, 10, episodes.colour);
    ecgLabDrawRaster(raster);
    for index = 1:numel(episodes.onset)
      centre = (episodes.onset(index) + episodes.offset(index)) / 2;
      text(ax, centre, 0.5, episodes.label{index}, 'Color', colour.ink, ...
      'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', ...
      'center', 'VerticalAlignment', 'middle');
    end
  else
    ecgLabDrawRaster(raster);
    text(ax, plan.seconds * 0.5, 0.5, 'no non-sinus episode', 'Color', ...
    colour.dim, 'FontSize', 7, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle');
  end
  ecgLabChartLaneTitle(ax, plan, 'rhythm', colour);
end
%=============================================================================
function ecgLabChartRateLane(ax, plan, colour)
  % The instantaneous heart rate against time, with reference lines at 60 and
  % 100 bpm.
  bpm = plan.tacho.bpm;
  finite = bpm(isfinite(bpm));
  [lo, hi] = ecgLabChartRange(finite, 50, 110, 8);
  lo = min(lo, 55);
  hi = max(hi, 105);
  set(ax, 'YLim', [lo hi], 'YTick', round(linspace(lo, hi, 3)));
  for reference = [60 100]
    if reference > lo && reference < hi
      line('Parent', ax, 'XData', [0 plan.seconds], 'YData', ...
      [reference reference], 'Color', colour.frame, 'LineWidth', 0.5, ...
      'LineStyle', ':');
    end
  end
  line('Parent', ax, 'XData', plan.tacho.time, 'YData', bpm, 'Color', ...
  colour.ink, 'LineWidth', 1, 'Tag', 'ecglab.chart.rate.line');
  ecgLabChartLaneTitle(ax, plan, 'heart rate, bpm', colour);
end
%=============================================================================
function ecgLabChartDividerLane(ax, plan, colour)
  % The rule between the reading lanes and the evidence, naming what is below
  % so the printed page explains its own evidence panel.
  set(ax, 'YLim', [0 1]);
  line('Parent', ax, 'XData', [0 plan.seconds], 'YData', [0.5 0.5], ...
  'Color', colour.frame, 'LineWidth', 1);
  text(ax, 0, 0.5, ' THE EVIDENCE ', 'Color', colour.dim, 'FontSize', 8, ...
  'FontWeight', 'bold', 'VerticalAlignment', 'middle', 'BackgroundColor', ...
  colour.background);
  text(ax, plan.seconds, 0.5, ['the series the detector thresholded ', ...
  'and the threshold in force '], 'Color', colour.dim, 'FontSize', 7, ...
  'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
  'BackgroundColor', colour.background);
end
%=============================================================================
function ecgLabChartEvidenceLane(ax, plan, colour)
  % The detector's evidence: the feature scaled by its own maximum and the
  % threshold in force, so the feature is seen crossing the threshold at a beat.
  evidence = plan.evidence;
  set(ax, 'YLim', [0 1.08], 'YTick', [0 0.5 1]);
  if evidence.present
    line('Parent', ax, 'XData', evidence.time, 'YData', evidence.feature, ...
    'Color', colour.classV, 'LineWidth', 0.75, 'Tag', ...
    'ecglab.chart.evidence.feature');
    line('Parent', ax, 'XData', evidence.time, 'YData', evidence.threshold, ...
    'Color', colour.classS, 'LineWidth', 1, 'LineStyle', '--', 'Tag', ...
    'ecglab.chart.evidence.threshold');
  else
    text(ax, plan.seconds * 0.5, 0.5, 'the detector kept no evidence', ...
    'Color', colour.dim, 'FontSize', 7, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle');
  end
  ecgLabChartLaneTitle(ax, plan, 'detector evidence', colour);
end
%=============================================================================
function ecgLabChartLaneTitle(ax, plan, title, colour)
  % A lane's name, near its top-left edge over the lane background so it stays
  % legible.
  yl = get(ax, 'YLim');
  y = yl(2) - 0.14 * (yl(2) - yl(1));
  text(ax, plan.seconds * 0.006, y, title, 'Color', colour.dim, ...
  'FontSize', 7.5, 'FontAngle', 'italic', 'VerticalAlignment', 'middle', ...
  'BackgroundColor', colour.background, 'Margin', 1);
end
%=============================================================================
function [lo, hi] = ecgLabChartRange(values, defaultLo, defaultHi, pad)
  % A padded range for a lane's y axis, or a default when the series is empty.
  if isempty(values)
    lo = defaultLo;
    hi = defaultHi;
    return;
  end
  lo = min(values) - pad;
  hi = max(values) + pad;
  if ~(hi > lo)
    lo = lo - pad;
    hi = hi + pad;
  end
end
%=============================================================================
