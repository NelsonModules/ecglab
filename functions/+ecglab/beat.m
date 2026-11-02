%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% HANDLE = ECGLAB.BEAT(X) opens the view of one beat of X: the raw trace on
% calibrated grid paper with the P, QRS and T fiducials, the detector's
% evidence below it, and a class card.
% HANDLE = ECGLAB.BEAT(X, 'Name', value, ...) sets which beat and the options.
% HANDLE = ECGLAB.BEAT(FIGURE, COMMAND) moves an open view to another beat.
%
%   One beat, with why it was detected and classified. The raw trace is drawn
%   on calibrated paper (25 mm/s, 10 mm/mV) with the P, QRS and T fiducials and
%   the PR, QRS and QT interval brackets. Below it, the detector's evidence
%   (thresholded series, adaptive threshold, detected peak) from beats.evidence,
%   and a class card with the AAMI class, its confidence and the key features.
%
%   X is an ecglab.recording (its beats are detected, delineated and classified
%   unless 'Analysis' is paired) or an ecglab.analysis (its beats, waves and
%   classes are read, nothing recomputed). Any of these may be absent from an
%   analysis; the view then draws what it has and says so.
%
%   The second form, ecglab.beat(FIGURE, COMMAND), is the only path that changes
%   an open view: it moves the objects the figure holds and creates none. It is
%   what the buttons, keys and console all call. COMMAND is 'next', 'previous',
%   a positive integer (that beat), or {'at', seconds} (the nearest beat).
%
%   Options (name and value, matched without regard to case):
%     'Beat'         the beat to open on, a 1-based index (default 1).
%     'At'           a moment in seconds to open on instead, the nearest beat.
%                    One of 'Beat' or 'At' at a time.
%     'Span'         the seconds of trace around the beat (default 1.2).
%     'Detector'     the QRS detector when X is a recording and no analysis is
%                    paired (default 'pantompkins'), passed to ecglab.detect.
%     'Analysis'     an ecglab.analysis to pair with the recording X, so the
%                    beats, waves and classes are not recomputed. 'Scoring' is
%                    an accepted alias.
%     'Interactive'  true (the default when 'Visible' is 'on') runs the control
%                    loop, and the function then does not return until the
%                    figure is closed; false draws once and returns, which is
%                    what the tests and a console driving the second form use.
%     'Visible'      'on' (default) or 'off'.
%     'OutputImage'  a file the current view is saved to, with no control in it.
%     'Title'        a heading of your own, replacing the recording's name.
%
%   The figure's UserData carries everything a redraw needs (recording, beats,
%   waves, classes, evidence, current beat), so the second form finds it there.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 30, 'Ectopic', 0.1, 'Seed', 1);
%     handle = ecglab.beat(recording, 'Beat', 5, 'Interactive', false);
%     ecglab.beat(handle, 'next');
%
%   See also ecglab.strip, ecglab.chart, ecglab.detect, ecglab.delineate,
%   ecglab.classify, ecglab.analyze.
function handle = beat(X, varargin)
  nargoutchk(0, 1);
  %===========================================================================
  % Second form: a non-struct X with one trailing argument is a figure handle
  % and a command to move an open view, routed to ecgLabBeatMove.
  if nargin == 2 && ~isstruct(X)
    handle = ecgLabBeatMove(X, varargin{1});
    return;
  end
  %===========================================================================
  defaults = struct('Beat', [], 'At', [], 'Span', 1.2, ...
  'Detector', 'pantompkins', 'Analysis', [], 'Scoring', [], ...
  'Interactive', [], 'Visible', 'on', 'OutputImage', '', 'Title', '');
  options = ecgLabOptions(defaults, varargin);
  ecgLabBeatCheck(options);
  %===========================================================================
  % Beats, delineation, classes and evidence, from a paired analysis or computed
  % from the recording. Gathered once and kept on the figure.
  data = ecgLabBeatResolve(X, options);
  colour = ecgLabDrawPalette('paper');
  %===========================================================================
  % Where the view opens: a beat index, a moment, or the first beat.
  if ~isempty(options.At)
    start = {'at', double(options.At)};
  elseif ~isempty(options.Beat)
    start = round(double(options.Beat));
  else
    start = 1;
  end
  %===========================================================================
  % The state the second form reads. Handles and current view are filled below.
  state = struct();
  state.kind = 'ecglab.beat';
  state.recording = data.recording;
  state.signal = data.signal;
  state.rate = data.rate;
  state.leadName = data.leadName;
  state.beats = data.beats;
  state.waves = data.waves;
  state.classes = data.classes;
  state.evidence = data.evidence;
  state.method = data.method;
  state.trace = data.trace;
  state.speed = data.trace.speed;
  state.featureRows = data.featureRows;
  state.colour = colour;
  state.span = double(options.Span);
  state.title = char(options.Title);
  state.index = 1;
  state.centre = NaN;
  state.window = [0, state.span];
  state.current = struct('label', '?', 'confidence', NaN);
  state.handles = struct();
  %===========================================================================
  width = 1120;
  height = 640;
  % Built on a hidden figure and revealed once.
  handle = figure('Name', 'Nelson ecglab', 'NumberTitle', 'off', ...
  'Color', colour.background, 'Visible', 'off', ...
  'MenuBar', 'none', 'ToolBar', 'none', 'SelectionHighlight', 'off', ...
  'Position', [40 40 width height], 'Tag', 'ecglab.beat');
  state.handles = ecgLabBeatObjects(handle, state);
  set(handle, 'UserData', state);
  %===========================================================================
  % Place the first view through the same mover every later step uses.
  ecgLabBeatMove(handle, start);
  %===========================================================================
  % The interactive loop runs only on a visible figure and only when asked
  % (default when visible). 'Interactive', false draws once and returns.
  interactive = options.Interactive;
  if isempty(interactive)
    interactive = strcmpi(options.Visible, 'on');
  else
    interactive = logical(interactive(1));
  end
  if interactive && strcmpi(options.Visible, 'on')
    controls = ecgLabBeatControls(handle, state);
    state = get(handle, 'UserData');
    state.handles.controls = controls;
    set(handle, 'UserData', state);
    % The control bar owns the bottom strip, so lift the research-only footer
    % just above it rather than letting the buttons sit over its text.
    set(state.handles.foot, 'Position', [0.035, 0.060, 0.930, 0.026]);
  end
  %===========================================================================
  if ~isempty(options.OutputImage)
    ecgLabBeatSave(handle, options.OutputImage);
  end
  %===========================================================================
  % Reveal the finished view once, now every object is in place.
  if strcmpi(options.Visible, 'on')
    set(handle, 'Visible', 'on');
    drawnow();
  end
  if interactive && strcmpi(options.Visible, 'on')
    ecgLabBeatLoop(handle);
  end
end
%=============================================================================
function ecgLabBeatCheck(options)
  % Check the options a view cannot open without, before any figure is opened.
  if ~any(strcmpi(options.Visible, {'on', 'off'}))
    error('ecglab:badVisible', 'The ''Visible'' option is ''on'' or ''off''.');
  end
  if ~isnumeric(options.Span) || ~isscalar(options.Span) || ...
    ~(options.Span > 0) || ~isfinite(options.Span)
    error('ecglab:badSpan', 'The ''Span'' option is one positive number of seconds.');
  end
  if ~isempty(options.Beat) && ~isempty(options.At)
    error('ecglab:oneAnchor', 'One of ''Beat'' or ''At'' at a time.');
  end
  if ~isempty(options.At) && (~isnumeric(options.At) || ~isscalar(options.At))
    error('ecglab:badAt', '''At'' is one moment in seconds.');
  end
end
%=============================================================================
