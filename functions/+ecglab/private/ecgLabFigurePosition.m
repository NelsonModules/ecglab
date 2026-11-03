%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function position = ecgLabFigurePosition(width, height)
  % Screen position [left bottom width height] for a new ecglab page, cascaded
  % down-right from the pages already open so a larger page cannot hide a smaller.
  step = 40;
  margin = 40;
  open = numel(findobj(0, 'Type', 'figure', 'Name', 'Nelson ecglab'));
  screen = get(0, 'ScreenSize');
  screenWidth = screen(3);
  screenHeight = screen(4);
  if ~(isfinite(screenHeight) && screenHeight > 200)
    screenHeight = 1080;
  end
  if ~(isfinite(screenWidth) && screenWidth > 200)
    screenWidth = 1920;
  end
  left = margin + step * open;
  if left + width > screenWidth
    left = max(0, screenWidth - width);
  end
  % Top edge of this window (screen y from the bottom), stepped down per page.
  top = screenHeight - margin - step * open;
  bottom = top - height;
  position = [left, bottom, width, height];
end
%=============================================================================
