%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Add baseline wander and mains hum to a recording, then clean it and grade it.
%
% ecglab.clean removes baseline wander with a zero-phase high pass and mains
% interference with a zero-phase notch. ecglab.quality then grades the signal
% window by window.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: clean a corrupted recording and grade its quality ===');

recording = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 70, ...
'Leads', 1, 'Seed', 5);
t = (0:size(recording.samples, 1) - 1)' / recording.rate;

% Baseline wander is a slow 0.3 Hz drift (0.5 mV) and mains hum a 50 Hz tone.
baseline = 0.5 * sin(2 * pi * 0.3 * t);
mains = 0.1 * sin(2 * pi * 50 * t);
dirty = recording;
dirty.samples = recording.samples + baseline + mains;
fprintf('Added 0.3 Hz baseline wander (0.5 mV) and 50 Hz mains hum (0.1 mV).\n');

% Clean it. The mains frequency is found from the record when it is not named.
cleaned = ecglab.clean(dirty, 'Mains', 50);
residual = std(cleaned.samples - recording.samples);
fprintf('Cleaned: residual to the original signal %.3f mV RMS.\n', residual);

% Grade both. The usable fraction is the share that can be trusted.
qDirty = ecglab.quality(dirty);
qClean = ecglab.quality(cleaned);
fprintf('Usable fraction: %.0f%% before, %.0f%% after cleaning.\n', ...
100 * qDirty.usableFraction, 100 * qClean.usableFraction);
disp('=== done ===');
%=============================================================================
