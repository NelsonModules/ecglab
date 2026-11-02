%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function raster = ecgLabDrawRaster(varargin)
  % Filled lane painted as one image, the fill primitive for coloured boxes
  % and bands. A patch is quadratic in its face count while an image draws in
  % constant time, so every fill is painted into one image's CData.
  %
  %   raster = ecgLabDrawRaster(axes, rows, cols, ground, xlim, ylim)  build
  %   raster = ecgLabDrawRaster(raster, x0, x1, low, high, colour)     paint
  %   raster = ecgLabDrawRaster(raster, x0, x1, low, high, colour, w)   ...
  %   handle = ecgLabDrawRaster(raster)                                 draw
  %
  % Build makes a ROWS by COLS raster filled with GROUND over XLIM and YLIM in
  % data units (default [0 1]); row 1 is the bottom. Paint blends boxes: X0,X1
  % are left and right in data units, LOW,HIGH the bottom and top row indices,
  % COLOUR a 1x3 or one row per box, W the blend weight in [0 1] (default 1).
  % Draw places the image once and returns its handle; calling it again
  % refreshes the image in place.
  %
  % An image's XData and YData name the centres of the first and last pixels,
  % so a raster covering [a b] is placed half a pixel in from each edge
  % (ecgLabDrawCentres).
  if nargin == 1
    % The draw form: place, or refresh, the raster's image.
    raster = ecgLabDrawPlace(varargin{1});
    return;
  end
  if isstruct(varargin{1})
    % The paint form: blend boxes into a raster. X0, X1, LOW, HIGH, COLOUR,
    % and an optional weight (default 1, opaque).
    weight = 1;
    if nargin >= 7
      weight = varargin{7};
    end
    raster = ecgLabDrawPaint(varargin{1}, varargin{2}, varargin{3}, ...
    varargin{4}, varargin{5}, varargin{6}, weight);
    return;
  end
  % The build form: a fresh raster on an axis.
  axesHandle = varargin{1};
  rows = varargin{2};
  cols = varargin{3};
  ground = varargin{4};
  xlim = [0 1];
  ylim = [0 1];
  if nargin >= 5 && ~isempty(varargin{5})
    xlim = varargin{5};
  end
  if nargin >= 6 && ~isempty(varargin{6})
    ylim = varargin{6};
  end
  rows = max(1, round(rows));
  cols = max(1, round(cols));
  ground = reshape(double(ground), 1, 3);
  planes = {repmat(ground(1), rows, cols), repmat(ground(2), rows, cols), ...
  repmat(ground(3), rows, cols)};
  raster = struct('axes', axesHandle, 'rows', rows, 'cols', cols, ...
  'ground', ground, 'xlim', reshape(xlim, 1, 2), ...
  'ylim', reshape(ylim, 1, 2), 'planes', {planes}, 'image', []);
end
%=============================================================================
function raster = ecgLabDrawPaint(raster, x0, x1, low, high, colour, weight)
  % Blend boxes into the raster's colour planes, touching only painted pixels.
  % A box wholly outside the raster's columns is dropped.
  count = numel(x0);
  if count == 0
    return;
  end
  x0 = reshape(x0, 1, []);
  x1 = reshape(x1, 1, []);
  low = reshape(low, 1, []);
  high = reshape(high, 1, []);
  if numel(low) == 1
    low = repmat(low, 1, count);
  end
  if numel(high) == 1
    high = repmat(high, 1, count);
  end
  if size(colour, 1) == 1
    colour = repmat(colour, count, 1);
  end
  if numel(weight) == 1
    weight = repmat(weight, 1, count);
  end
  unit = (raster.xlim(2) - raster.xlim(1)) / raster.cols;
  first = floor((x0 - raster.xlim(1)) / unit) + 1;
  last = ceil((x1 - raster.xlim(1)) / unit);
  keep = x1 >= raster.xlim(1) & x0 <= raster.xlim(2) & weight > 0;
  first = max(1, min(raster.cols, first(keep)));
  last = max(1, min(raster.cols, last(keep)));
  low = max(1, min(raster.rows, round(low(keep))));
  high = max(1, min(raster.rows, round(high(keep))));
  colour = colour(keep, :);
  weight = weight(keep);
  % One box at a time over its own pixels.
  n = numel(first);
  if n == 0
    return;
  end
  red = raster.planes{1};
  green = raster.planes{2};
  blue = raster.planes{3};
  raster.planes = {};
  for index = 1:n
    rowsSpan = low(index):high(index);
    colsSpan = first(index):last(index);
    w = weight(index);
    block = red(rowsSpan, colsSpan);
    red(rowsSpan, colsSpan) = block + (colour(index, 1) - block) * w;
    block = green(rowsSpan, colsSpan);
    green(rowsSpan, colsSpan) = block + (colour(index, 2) - block) * w;
    block = blue(rowsSpan, colsSpan);
    blue(rowsSpan, colsSpan) = block + (colour(index, 3) - block) * w;
  end
  raster.planes = {red, green, blue};
end
%=============================================================================
function raster = ecgLabDrawPlace(raster)
  cdata = cat(3, raster.planes{1}, raster.planes{2}, raster.planes{3});
  xdata = ecgLabDrawCentres(raster.xlim, raster.cols);
  ydata = ecgLabDrawCentres(raster.ylim, raster.rows);
  if ~isempty(raster.image) && isgraphics(raster.image)
    set(raster.image, 'CData', cdata, 'XData', xdata, 'YData', ydata);
    return;
  end
  raster.image = image('Parent', raster.axes, 'CData', cdata, ...
  'XData', xdata, 'YData', ydata);
end
%=============================================================================
function data = ecgLabDrawCentres(limits, count)
  % The XData or YData that makes COUNT pixels cover exactly LIMITS: the
  % centres of the first and last pixels, half a pixel in from each edge. A
  % single pixel has no second centre, so it is left at the limits.
  data = limits;
  if count > 1
    half = (limits(2) - limits(1)) / (2 * count);
    data = [limits(1) + half, limits(2) - half];
  end
end
%=============================================================================
