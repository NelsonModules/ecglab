%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabBeatSave(figureHandle, filename)
  % Save the current view to a file. Every uicontrol is hidden for the save and
  % restored after, so the saved page shows only the axes.
  shown = ecgLabBeatHide(figureHandle);
  saveas(figureHandle, filename);
  for index = 1:numel(shown)
    set(shown(index), 'Visible', 'on');
  end
end
%=============================================================================
function shown = ecgLabBeatHide(figureHandle)
  % Hide every control of the figure and return those that were visible. Hides
  % by type so static text is hidden along with the buttons.
  found = findall(figureHandle, 'Type', 'uicontrol');
  shown = [];
  for index = 1:numel(found)
    if strcmp(get(found(index), 'Visible'), 'on')
      shown = [shown, found(index)]; %#ok<AGROW>
      set(found(index), 'Visible', 'off');
    end
  end
end
%=============================================================================
