%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function colour = ecgLabDrawPalette(style)
  % Colour table for the reading pages, keyed by style.
  %
  %   colour = ecgLabDrawPalette(style)
  %
  % STYLE is 'paper' (salmon grid on cream, the default), 'bw' (grey grid for
  % a monochrome print) or 'monitor' (bright trace on a near-black screen).
  % An unknown style is an error.
  %
  % The returned struct has the same field names whatever the style:
  %   background   the paper or screen ground (the axes Color)
  %   ink          text and any measured fact drawn as a line
  %   trace        the electrocardiogram trace
  %   gridMinor    the 1 mm grid line
  %   gridMajor    the 5 mm grid line
  %   calibration  the calibration pulse
  %   dim          a muted ink for labels
  %   frame        a panel or divider rule
  %   classes      a 5 x 3 table of the AAMI beat-class hues (N, S, V, F, Q),
  %                indexed by class number
  %   classN classS classV classF classQ   the same five as named fields
  %
  % The class hues stay apart to a deuteranope on paper and screen; the grey
  % style separates them by lightness instead of hue.
  if nargin < 1 || isempty(style)
    style = 'paper';
  end
  switch lower(char(style))
    case 'paper'
      colour = ecgLabDrawPaper();
    case 'bw'
      colour = ecgLabDrawBw();
    case 'monitor'
      colour = ecgLabDrawMonitor();
    otherwise
      error('ecglab:unknownStyle', 'The style is ''paper'', ''bw'' or ''monitor''.');
  end
  % The five hues as a table in AAMI order N S V F Q, for indexing by class
  % number.
  colour.classes = [colour.classN; colour.classS; colour.classV; ...
  colour.classF; colour.classQ];
end
%=============================================================================
function colour = ecgLabDrawPaper()
  % Printed report: cream ground, salmon grid, near-black trace, teal
  % calibration pulse.
  colour = struct();
  colour.background = [1.000 0.973 0.961];
  colour.ink = [0.110 0.102 0.098];
  colour.trace = [0.106 0.078 0.075];
  colour.gridMinor = [0.953 0.824 0.776];
  colour.gridMajor = [0.886 0.596 0.498];
  colour.calibration = [0.055 0.486 0.525];
  colour.dim = [0.431 0.400 0.380];
  colour.frame = [0.780 0.710 0.680];
  colour.classN = [0.055 0.486 0.525];
  colour.classS = [0.753 0.478 0.000];
  colour.classV = [0.710 0.090 0.620];
  colour.classF = [0.439 0.282 0.769];
  colour.classQ = [0.541 0.506 0.478];
end
%=============================================================================
function colour = ecgLabDrawBw()
  % Monochrome: white ground, grey grid, black ink. The five classes are
  % separated by lightness, not hue.
  colour = struct();
  colour.background = [1.000 1.000 1.000];
  colour.ink = [0.000 0.000 0.000];
  colour.trace = [0.067 0.067 0.067];
  colour.gridMinor = [0.851 0.851 0.851];
  colour.gridMajor = [0.604 0.604 0.604];
  colour.calibration = [0.000 0.000 0.000];
  colour.dim = [0.333 0.333 0.333];
  colour.frame = [0.600 0.600 0.600];
  colour.classN = [0.100 0.100 0.100];
  colour.classS = [0.350 0.350 0.350];
  colour.classV = [0.550 0.550 0.550];
  colour.classF = [0.700 0.700 0.700];
  colour.classQ = [0.820 0.820 0.820];
end
%=============================================================================
function colour = ecgLabDrawMonitor()
  % Bedside screen: near-black ground, bright green trace, faint green grid.
  colour = struct();
  colour.background = [0.031 0.051 0.043];
  colour.ink = [0.910 0.929 0.918];
  colour.trace = [0.357 0.878 0.627];
  colour.gridMinor = [0.086 0.153 0.118];
  colour.gridMajor = [0.169 0.341 0.267];
  colour.calibration = [0.941 0.706 0.161];
  colour.dim = [0.565 0.631 0.596];
  colour.frame = [0.223 0.301 0.267];
  colour.classN = [0.357 0.878 0.627];
  colour.classS = [0.941 0.706 0.161];
  colour.classV = [0.941 0.420 0.769];
  colour.classF = [0.655 0.545 0.980];
  colour.classQ = [0.604 0.655 0.627];
end
%=============================================================================
