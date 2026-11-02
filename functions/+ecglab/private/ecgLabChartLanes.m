%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function lanes = ecgLabChartLanes(figureOrLanes, plan, colour)
  % Build the stack of time lanes, or run the finishing pass that lines their
  % grid up.
  %
  %   lanes = ecgLabChartLanes(figure, plan, colour)   build
  %   ecgLabChartLanes(lanes, plan)                    finish
  %
  % Build makes one axes per lane from the plan's pixel table, each tagged
  % 'ecglab.chart.<name>'. Finish is a separate step, run after every lane's
  % children are in, because adding objects can move the axes limits. It sets
  % the shared XLim, XTick and grid last, with tick labels on the lowest lane.
  if nargin == 2
    ecgLabChartFinish(figureOrLanes, plan);
    lanes = figureOrLanes;
    return;
  end
  figure = figureOrLanes;
  table = plan.laneTable;
  lanes = struct('figure', figure, 'names', {{}}, 'axes', struct());
  for index = 1:numel(table)
    name = table(index).name;
    bottom = 1 - (table(index).top + table(index).height) / plan.height;
    handle = axes('Parent', figure, 'Units', 'normalized', 'Position', ...
    [plan.lanesLeft, bottom, plan.lanesWidth, table(index).height / ...
    plan.height], 'Tag', ['ecglab.chart.', name]);
    set(handle, 'Color', colour.background, 'XColor', colour.dim, ...
    'YColor', colour.dim, 'Box', 'on', 'FontSize', 7, 'XTick', [], ...
    'YTick', []);
    lanes.names{end + 1} = name;
    lanes.axes.(name) = handle;
  end
end
%=============================================================================
function ecgLabChartFinish(lanes, plan)
  % The lowest reading lane carries the tick labels. The divider is not a
  % reading lane, so it takes no frame, grid or ticks.
  colour = ecgLabDrawPalette('paper');
  lowest = ecgLabChartLowest(lanes, plan);
  for index = 1:numel(lanes.names)
    name = lanes.names{index};
    handle = lanes.axes.(name);
    if strcmp(name, 'divider')
      set(handle, 'XLim', [0 plan.seconds], 'XTick', [], 'YTick', [], ...
      'Box', 'off', 'XColor', colour.background, 'YColor', ...
      colour.background);
      continue;
    end
    words = {};
    if strcmp(name, lowest)
      words = plan.tickLabels;
    end
    set(handle, 'Box', 'on', 'Layer', 'top', 'XColor', colour.dim, ...
    'YColor', colour.dim, 'FontSize', 7, 'XGrid', 'on', 'GridColor', ...
    colour.gridMajor, 'XTick', plan.ticks, 'XTickLabel', words);
    set(handle, 'XLim', [0 plan.seconds]);
  end
end
%=============================================================================
function lowest = ecgLabChartLowest(lanes, plan)
  table = plan.laneTable;
  lowest = '';
  deepest = -inf;
  for index = 1:numel(table)
    name = table(index).name;
    if strcmp(name, 'divider')
      continue;
    end
    bottomPx = table(index).top + table(index).height;
    if bottomPx > deepest
      deepest = bottomPx;
      lowest = name;
    end
  end
end
%=============================================================================
