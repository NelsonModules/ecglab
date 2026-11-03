%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabFreezeView(figureHandle)
  % Turn off scroll-zoom and drag-pan on every axes so the calibrated page keeps
  % its scale; the page is a fixed picture, not an explorable plot.
  axesList = findobj(figureHandle, 'Type', 'axes');
  for index = 1:numel(axesList)
    disableDefaultInteractivity(axesList(index));
  end
end
%=============================================================================
