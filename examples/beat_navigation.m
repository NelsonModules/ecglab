%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Walk the beats with the command-driven beat view.
%
% ecglab.beat opens on one beat; ecglab.beat(figure, command) moves the
% existing objects, so paging stays fast on long records. Needs a session
% with a figure (advanced CLI or desktop).
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: walk the beats with the beat view ===');

recording = ecglab.simulate('Seconds', 30, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Leads', 12, 'Seed', 3);
analysis = ecglab.analyze(recording);

% Open on the first beat. 'Interactive' false draws once and returns so a
% script can drive the view.
h = ecglab.beat(analysis, 'Beat', 1, 'Interactive', false);
disp('Opened the beat view on beat 1.');

% Step forward three beats, then jump to a time. Each command reuses the
% existing objects.
ecglab.beat(h, 'next');
ecglab.beat(h, 'next');
ecglab.beat(h, 'next');
disp('Stepped to beat 4 with three ''next'' commands.');
ecglab.beat(h, {'at', 20});
disp('Jumped to the beat nearest 20 s.');

% Saving is a first-form option, so reopen the beat at 20 s and write it.
beatFile = [tempdir(), 'ecglab_example_beat_at20.png'];
ecglab.beat(analysis, 'At', 20, 'Interactive', false, 'OutputImage', beatFile);
fprintf('Saved the beat at 20 s to %s.\n', beatFile);
disp('=== done ===');
%=============================================================================
