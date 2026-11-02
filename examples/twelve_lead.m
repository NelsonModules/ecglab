%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Measure the twelve leads: the derived leads, the frontal axis, the intervals.
%
% ecglab.leads derives the standard leads a recording lacks, measures the
% frontal QRS axis and the global intervals, and prints each measurement beside
% its normal range.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: the twelve-lead measurements ===');

recording = ecglab.simulate('Seconds', 20, 'Rate', 500, 'HeartRate', 70, ...
'Leads', 12, 'Seed', 4);
result = ecglab.leads(recording);

fprintf('Frontal axis: %.0f degrees (%s).\n', result.axis.degrees, ...
result.axis.label);
fprintf('Global intervals: PR %.0f ms, QRS %.0f ms, QT %.0f ms.\n', ...
result.intervals.pr, result.intervals.qrs, result.intervals.qt);
fprintf('Corrected QT: Bazett %.0f ms, Fridericia %.0f ms, ', ...
result.qtc.bazett, result.qtc.fridericia);
fprintf('Framingham %.0f ms, Hodges %.0f ms.\n', result.qtc.framingham, ...
result.qtc.hodges);
disp('=== done ===');
%=============================================================================
