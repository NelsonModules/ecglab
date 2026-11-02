%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function handles = ecgLabDrawGrid(axesHandle, extent, colour, varargin)
  % Draw calibrated ECG paper into an axis whose data units are millimetres.
  %
  %   handles = ecgLabDrawGrid(axesHandle, extent, colour)
  %   handles = ecgLabDrawGrid(axesHandle, extent, colour, 'Name', value)
  %
  % The caller sets the axis to millimetre units; this only lays the ruling,
  % minor every 1 mm and major every 5 mm as on real ECG paper.
  %
  % EXTENT is [x0 x1 y0 y1] in millimetres, the rectangle to rule. COLOUR is
  % a palette from ecgLabDrawPalette (gridMinor and gridMajor fields).
  % Options (name and value, case insensitive):
  %   'Minor'      the minor spacing in mm (default 1)
  %   'Major'      the major spacing in mm (default 5)
  %   'MinorWidth' the minor line width (default 0.25)
  %   'MajorWidth' the major line width (default 0.6)
  %
  % The ruling is two line objects (minor, then major over it), each a single
  % NaN-broken line for speed. HANDLES has fields 'minor' and 'major'.
  options = ecgLabOptions(struct('Minor', 1, 'Major', 5, ...
  'MinorWidth', 0.25, 'MajorWidth', 0.6), varargin);
  x0 = extent(1); x1 = extent(2); y0 = extent(3); y1 = extent(4);
  % Minor ruling first, then major over it, each its own line object so width
  % and colour are set independently.
  minorHandle = ecgLabDrawRuling(axesHandle, x0, x1, y0, y1, ...
  options.Minor, colour.gridMinor, options.MinorWidth);
  majorHandle = ecgLabDrawRuling(axesHandle, x0, x1, y0, y1, ...
  options.Major, colour.gridMajor, options.MajorWidth);
  handles = struct('minor', minorHandle, 'major', majorHandle);
end
%=============================================================================
function handle = ecgLabDrawRuling(axesHandle, x0, x1, y0, y1, step, ...
  colour, width)
  % One ruling (verticals and horizontals of one spacing) as a single
  % NaN-broken line, the NaN lifting the pen between segments. A tiny epsilon
  % keeps the closing rule when the extent is an exact multiple of the step.
  epsilon = step * 1e-6;
  xs = x0:step:(x1 + epsilon);
  ys = y0:step:(y1 + epsilon);
  nx = numel(xs);
  ny = numel(ys);
  % Verticals: for each x, the pair (x, y0) (x, y1) then a NaN.
  vx = reshape([xs; xs; nan(1, nx)], 1, []);
  vy = reshape([repmat(y0, 1, nx); repmat(y1, 1, nx); nan(1, nx)], 1, []);
  % Horizontals: for each y, the pair (x0, y) (x1, y) then a NaN.
  hx = reshape([repmat(x0, 1, ny); repmat(x1, 1, ny); nan(1, ny)], 1, []);
  hy = reshape([ys; ys; nan(1, ny)], 1, []);
  handle = line('Parent', axesHandle, 'XData', [vx, hx], ...
  'YData', [vy, hy], 'Color', colour, 'LineWidth', width);
end
%=============================================================================
