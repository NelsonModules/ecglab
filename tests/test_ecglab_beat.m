%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% <--ADV-CLI MODE-->
%=============================================================================
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ecglab.beat draws one beat: the raw trace with the delineation fiducials, the
% detector evidence below, and a class card. The second form, beat(FIGURE,
% COMMAND), moves objects in an open view and creates none. Figures are drawn
% headless ('Visible','off', 'Interactive',false), so the suite leaves no window.
tmp = tempdir();
%=============================================================================
% A simulated twenty-second record with a few ectopics, so a class other than
% N can occur.
rec = ecglab.simulate('Seconds', 20, 'Rate', 360, 'Ectopic', 0.1, 'Seed', 1);
%=============================================================================
% The view opens on a beat and returns a figure handle carrying its state.
h = ecglab.beat(rec, 'Visible', 'off', 'Interactive', false);
assert_istrue(isgraphics(h, 'figure'));
state = get(h, 'UserData');
assert_isequal(state.kind, 'ecglab.beat');
fprintf('opened on beat %d of %d\n', state.index, numel(state.beats.sample));
%=============================================================================
% The three axes the view is built of, each found by its tag.
for part = {'trace', 'evidence', 'card'}
  ax = findobj(h, 'Tag', ['ecglab.beat.', part{1}]);
  assert_isequal(numel(ax), 1, ['missing axis ', part{1}]);
end
%=============================================================================
% The raw trace is one line in the trace axis, with data to draw.
trace = findobj(h, 'Tag', 'ecglab.beat.trace.signal');
assert_isequal(numel(trace), 1);
assert_istrue(sum(isfinite(get(trace, 'XData'))) > 1);
%=============================================================================
% The fiducials match the delineation: the R peak is drawn as a dot at the
% millimetre its sample maps to in the window.
waves = state.waves;
index = state.index;
speed = state.speed;
t0 = state.window(1);
rTime = waves.time(index, 6);
assert_istrue(isfinite(rTime), 'the shown beat has a delineated R');
rX = (rTime - t0) * speed;
dots = findobj(h, 'Tag', 'ecglab.beat.trace.dots');
assert_isequal(numel(dots), 1);
dotX = get(dots, 'XData');
[gap, ~] = min(abs(dotX - rX));
fprintf('R dot at %.3f mm, expected %.3f mm, gap %.4f\n', ...
dotX(find(abs(dotX - rX) == gap, 1)), rX, gap);
assert_istrue(gap < 0.2, 'a dot sits at the delineated R');
%=============================================================================
% The evidence lane shows the feature line, the threshold line, and the marked
% peak.
feature = findobj(h, 'Tag', 'ecglab.beat.evidence.feature');
threshold = findobj(h, 'Tag', 'ecglab.beat.evidence.threshold');
peak = findobj(h, 'Tag', 'ecglab.beat.evidence.peak');
assert_isequal(numel(feature), 1);
assert_isequal(numel(threshold), 1);
assert_isequal(numel(peak), 1);
assert_istrue(sum(isfinite(get(feature, 'YData'))) > 1, 'the feature is drawn');
assert_istrue(sum(isfinite(get(threshold, 'YData'))) > 1, ...
'the threshold is drawn');
%=============================================================================
% The class card names one of the five AAMI classes N S V F Q.
label = state.current.label;
fprintf('beat %d classified %s (confidence %.2f)\n', index, label, ...
state.current.confidence);
assert_istrue(numel(label) == 1 && any(label == 'NSVFQ'), ...
'the card names an AAMI class');
badge = findobj(h, 'Tag', 'ecglab.beat.card.badge');
assert_isequal(numel(badge), 1);
assert_isequal(get(badge, 'String'), label);
%=============================================================================
% The second form moves the view to the next beat and creates no new object:
% the object count is the same before and after.
before = numel(findobj(h));
was = state.index;
ecglab.beat(h, 'next');
after = numel(findobj(h));
state = get(h, 'UserData');
fprintf('next: beat %d -> %d, objects %d -> %d\n', was, state.index, ...
before, after);
assert_isequal(after, before, 'next creates no object');
assert_isequal(state.index, was + 1);
%=============================================================================
% 'previous' steps back, and an integer opens that beat directly.
ecglab.beat(h, 'previous');
state = get(h, 'UserData');
assert_isequal(state.index, was);
afterPrev = numel(findobj(h));
assert_isequal(afterPrev, before, 'previous creates no object');
ecglab.beat(h, 3);
state = get(h, 'UserData');
assert_isequal(state.index, 3);
%=============================================================================
% {'at', seconds} centres the window on that moment and shows the nearest beat.
target = state.beats.time(5) + 0.05;
ecglab.beat(h, {'at', target});
state = get(h, 'UserData');
centre = mean(state.window);
fprintf('at %.3f s: window centred on %.3f s\n', target, centre);
assert_istrue(abs(centre - target) < 1e-6, 'the window centres on the moment');
assert_isequal(numel(findobj(h)), before, 'at creates no object');
close(h);
%=============================================================================
% Saving to PNG produces a file with no control on it: a non-interactive view
% creates no uicontrol.
pngFile = [tmp, '/test_ecglab_beat.png'];
if isfile(pngFile)
  delete(pngFile);
end
h = ecglab.beat(rec, 'Visible', 'off', 'Interactive', false, ...
'OutputImage', pngFile);
assert_isequal(numel(findall(h, 'Type', 'uicontrol')), 0, ...
'no control on the saved page');
assert_istrue(isfile(pngFile));
close(h);
%=============================================================================
% An analysis can be paired so the beat is not recomputed: the view opens from
% an ecglab.analysis and from its recording.
analysis = ecglab.analyze(rec);
h = ecglab.beat(analysis, 'Visible', 'off', 'Interactive', false);
assert_istrue(isgraphics(h, 'figure'));
st = get(h, 'UserData');
assert_isequal(st.kind, 'ecglab.beat');
close(h);
% The same, paired through the Analysis option on the recording.
h = ecglab.beat(rec, 'Analysis', analysis, 'Visible', 'off', ...
'Interactive', false);
assert_istrue(isgraphics(h, 'figure'));
close(h);
%=============================================================================
% Errors: a stale handle, a bad command, a bad beat number, a bad option name
% and a bad Visible are each refused with their own identifier.
h = ecglab.beat(rec, 'Visible', 'off', 'Interactive', false);
dead = h;
close(h);
assert_istrue(startsWith(localBeatError(@() ecglab.beat(dead, 'next')), 'ecglab:staleBeat'));
h = ecglab.beat(rec, 'Visible', 'off', 'Interactive', false);
assert_istrue(startsWith(localBeatError(@() ecglab.beat(h, 'sideways')), 'ecglab:unknownCommand'));
assert_istrue(startsWith(localBeatError(@() ecglab.beat(h, 99999)), 'ecglab:noSuchBeat'));
close(h);
assert_istrue(startsWith(localBeatError(@() ecglab.beat(rec, 'NoSuchOption', 1)), 'ecglab:unknownOption'));
assert_istrue(startsWith(localBeatError(@() ecglab.beat(rec, 'Visible', 'maybe')), 'ecglab:badVisible'));
%=============================================================================
% The draw time of a first view must stay small.
tic;
h = ecglab.beat(rec, 'Visible', 'off', 'Interactive', false);
elapsed = toc;
close(h);
fprintf('opened a beat view in %.3f s\n', elapsed);
assert_istrue(elapsed < 10);
%=============================================================================
function id = localBeatError(thunk)
  % The identifier of the error a call raises, or empty when it raises none.
  id = '';
  try
    thunk();
  catch e
    id = e.identifier;
  end
end
%=============================================================================
