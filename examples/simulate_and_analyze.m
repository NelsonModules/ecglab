%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Simulate a twelve-lead electrocardiogram and analyse it in one call.
%
% The recording is a model with planted beats and waves, so analysis can be
% measured against a known truth. ecglab.analyze runs the whole chain (clean,
% quality, detect, delineate, classify, rhythm, variability, twelve leads) and
% returns one struct; ecglab.report prints the study.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: simulate a recording and analyse it ===');

% A short twelve-lead recording with a little ventricular ectopy. The seed
% makes the run reproducible.
recording = ecglab.simulate('Seconds', 30, 'Rate', 360, 'HeartRate', 72, ...
'Ectopic', 0.08, 'Leads', 12, 'Seed', 7);
fprintf('Simulated %.0f s at %d Hz on %d leads.\n', recording.seconds, ...
recording.rate, numel(recording.leads));

% One call runs the whole analysis; nothing below recomputes it.
started = tic();
analysis = ecglab.analyze(recording);
fprintf('Analysed in %.2f s: %d beats found.\n', toc(started), ...
numel(analysis.beats.sample));

% The study report. Each interval is printed beside its normal range.
disp('The study report, ecglab.report:');
ecglab.report(analysis);
disp('=== done ===');
%=============================================================================
