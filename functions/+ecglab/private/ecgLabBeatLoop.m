%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabBeatLoop(figureHandle)
  % Keep the interactive view open until its figure is closed. The controls and
  % keys drive the view through their own callbacks, so the loop only pumps the
  % window's events and waits.
  while isgraphics(figureHandle, 'figure')
    drawnow();
    pause(0.02);
  end
end
%=============================================================================
