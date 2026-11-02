%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Measure the heart rate variability by the Task Force definitions.
%
% ecglab.hrv measures variability by the 1996 Task Force standard: the time
% domain (SDNN, RMSSD, pNN50), the frequency domain (VLF, LF, HF bands and
% LF/HF ratio) and the non-linear indices (Poincare SD1/SD2, DFA, sample
% entropy).
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: heart rate variability ===');

% A few minutes is enough for the low-frequency band.
recording = ecglab.simulate('Seconds', 300, 'Rate', 360, 'HeartRate', 70, ...
'Leads', 1, 'Seed', 8);
beats = ecglab.detect(recording);
hrv = ecglab.hrv(recording, 'Beats', beats);
fprintf('%d beats, %d normal-to-normal intervals used.\n', ...
numel(beats.sample), numel(hrv.nn));

% The time domain.
fprintf('Time: SDNN %.1f ms, RMSSD %.1f ms, pNN50 %.1f%%.\n', ...
hrv.time.sdnn, hrv.time.rmssd, hrv.time.pnn50);
% The frequency domain (Welch by default).
fprintf('Frequency (%s): LF %.0f ms^2, HF %.0f ms^2, LF/HF %.2f.\n', ...
hrv.settings.method, hrv.frequency.lf, hrv.frequency.hf, hrv.frequency.lfhf);
% Two non-linear indices.
fprintf('Non-linear: Poincare SD1 %.1f ms, SD2 %.1f ms.\n', ...
hrv.nonlinear.sd1, hrv.nonlinear.sd2);
disp('=== done ===');
%=============================================================================
