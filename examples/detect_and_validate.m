%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Detect the beats with two detectors and measure each against the truth.
%
% A simulated recording carries its own beat annotations as ground truth.
% ecglab.detect finds beats from the signal; ecglab.validate compares them to
% the truth per ANSI/AAMI EC57 (150 ms window, sensitivity and positive
% predictivity).
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: detect the beats and validate the detection ===');

% A two-minute record with some ectopy. Its annotations are the ground truth.
recording = ecglab.simulate('Seconds', 120, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.1, 'Leads', 2, 'Seed', 11);
truth = recording.annotations;
fprintf('Simulated %.0f s with %d true beats.\n', recording.seconds, ...
numel(truth.sample));

% Two detectors: Pan-Tompkins and Elgendi. The EC57 learning period is off
% ('Learning', 0) because this demo record is short.
for method = {'pantompkins', 'elgendi'}
  name = method{1};
  beats = ecglab.detect(recording, 'Method', name);
  agreement = ecglab.validate(beats, truth, 'Kind', 'beats', 'Learning', 0);
  fprintf('%-12s %d beats: sensitivity %.1f%%, positive predictivity %.1f%%.\n', ...
  name, numel(beats.sample), 100 * agreement.se, 100 * agreement.ppv);
end
disp('The per-record figures on the open databases are in data/ecglab_beats_mitdb.md.');
disp('=== done ===');
%=============================================================================
