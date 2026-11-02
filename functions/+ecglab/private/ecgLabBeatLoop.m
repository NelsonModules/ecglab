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
  % The control loop: read the flags the controls and keys set, route each
  % command through ecgLabBeatMove, then wait. Returns when the figure closes.
  while isgraphics(figureHandle, 'figure')
    state = get(figureHandle, 'UserData');
    controls = state.handles.controls;
    command = ecgLabBeatPending(controls);
    if ~isempty(command)
      try
        % One command, one repaint: ecgLabBeatMove ends in its own drawnow, so
        % the loop does not add a second full repaint of the same view.
        ecgLabBeatMove(figureHandle, command);
      catch
        % A bad typed beat number is ignored rather than stopping the loop.
      end
    else
      % Idle: pump the window's events (clicks, keys) without repainting the
      % unchanged view, so the loop is not forever in a needless redraw.
      drawnow();
    end
    pause(0.02);
  end
end
%=============================================================================
function command = ecgLabBeatPending(controls)
  % The one command waiting, from a button, the go box or a key, cleared as it
  % is read so it fires once. Buttons are checked before keys.
  command = '';
  for name = {'previous', 'next', 'go'}
    control = controls.(name{1});
    flag = get(control, 'UserData');
    if ~isempty(flag)
      set(control, 'UserData', '');
      if strcmp(flag, 'go')
        command = ecgLabBeatTyped(controls.edit);
      else
        command = flag;
      end
      return;
    end
  end
  event = get(controls.keys, 'UserData');
  if ~isempty(event)
    set(controls.keys, 'UserData', []);
    command = ecgLabBeatKey(event);
  end
end
%=============================================================================
function command = ecgLabBeatTyped(edit)
  % The beat number typed into the go box, as a command the mover understands,
  % or nothing when the box does not hold a number.
  command = '';
  value = str2double(get(edit, 'String'));
  if isfinite(value)
    command = round(value);
  end
end
%=============================================================================
function command = ecgLabBeatKey(event)
  % The arrow keys: left and right step the beat.
  command = '';
  if ~isstruct(event) || ~isfield(event, 'Key')
    return;
  end
  switch lower(event.Key)
    case {'leftarrow', 'left'}
      command = 'previous';
    case {'rightarrow', 'right'}
      command = 'next';
  end
end
%=============================================================================
