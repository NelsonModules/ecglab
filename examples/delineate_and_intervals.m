%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Delineate the P, QRS and T waves and read the intervals off them.
%
% ecglab.delineate marks the onset, peak and end of the P, QRS and T waves
% (wavelet method, Martinez et al. 2004) and returns the PR, QRS and QT
% intervals with corrected QT. Accuracy is in data/ecglab_delineation_qtdb.md.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: delineate the waves and measure the intervals ===');

recording = ecglab.simulate('Seconds', 30, 'Rate', 500, 'HeartRate', 68, ...
'Leads', 12, 'Seed', 2);

% Detect once and delineate on those beats, so the waves match the beats
% every other analysis uses.
beats = ecglab.detect(recording);
waves = ecglab.delineate(recording, 'Beats', beats);
fprintf('Delineated %d beats.\n', numel(beats.sample));

% Intervals are per beat; the median is the record's central value. Absent
% P waves give NaN and are left out.
pr = median(waves.intervals.pr, 'omitnan');
qrs = median(waves.intervals.qrs, 'omitnan');
qt = median(waves.intervals.qt, 'omitnan');
qtcBazett = median(waves.intervals.qtc.bazett, 'omitnan');
fprintf('Median intervals: PR %.0f ms, QRS %.0f ms, QT %.0f ms.\n', pr, qrs, qt);
fprintf('Corrected QT (Bazett): %.0f ms.\n', qtcBazett);
disp('These are measurements and their formulas, never a diagnosis.');
disp('=== done ===');
%=============================================================================
