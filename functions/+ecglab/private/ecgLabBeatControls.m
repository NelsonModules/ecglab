%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function controls = ecgLabBeatControls(figureHandle, state)
  % The controls of an interactive view: previous, next, a beat number to jump
  % to, and the arrow keys. Each drives the view directly through ecgLabBeatMove,
  % so the buttons work on their own click, with or without ecgLabBeatLoop.
  colour = state.colour;
  controls = struct();
  controls.previous = uicontrol('Parent', figureHandle, 'Style', ...
  'pushbutton', 'String', 'previous', 'Position', [20 8 90 28], ...
  'Callback', @(src, evt) ecgLabBeatMove(figureHandle, 'previous'));
  controls.next = uicontrol('Parent', figureHandle, 'Style', 'pushbutton', ...
  'String', 'next', 'Position', [116 8 90 28], ...
  'Callback', @(src, evt) ecgLabBeatMove(figureHandle, 'next'));
  uicontrol('Parent', figureHandle, 'Style', 'text', 'String', 'beat', ...
  'HorizontalAlignment', 'right', 'Position', [224 10 40 22], ...
  'BackgroundColor', colour.background, 'ForegroundColor', colour.dim);
  controls.edit = uicontrol('Parent', figureHandle, 'Style', 'edit', ...
  'String', '1', 'Position', [268 8 64 28]);
  editControl = controls.edit;
  controls.go = uicontrol('Parent', figureHandle, 'Style', 'pushbutton', ...
  'String', 'go', 'Position', [336 8 44 28], ...
  'Callback', @(src, evt) ecgLabBeatGo(figureHandle, editControl));
  uicontrol('Parent', figureHandle, 'Style', 'text', 'HorizontalAlignment', ...
  'left', 'Position', [396 10 680 22], 'BackgroundColor', ...
  colour.background, 'ForegroundColor', colour.dim, 'String', ['keys: ' ...
  'left and right step previous and next; the view returns when this ' ...
  'figure is closed']);
  set(figureHandle, 'KeyPressFcn', @(src, evt) ecgLabBeatKeyPress(figureHandle, evt));
end
%=============================================================================
function ecgLabBeatGo(figureHandle, editControl)
  % Jump to the beat number typed into the go box, when it holds a number.
  value = str2double(get(editControl, 'String'));
  if isfinite(value)
    try
      ecgLabBeatMove(figureHandle, round(value));
    catch
    end
  end
end
%=============================================================================
function ecgLabBeatKeyPress(figureHandle, event)
  % Left and right arrows step to the previous and next beat.
  if ~isstruct(event) || ~isfield(event, 'Key')
    return;
  end
  switch lower(event.Key)
    case {'leftarrow', 'left'}
      ecgLabBeatMove(figureHandle, 'previous');
    case {'rightarrow', 'right'}
      ecgLabBeatMove(figureHandle, 'next');
  end
end
%=============================================================================
