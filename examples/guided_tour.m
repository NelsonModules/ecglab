%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% The guided tour: one call runs the whole module and says what it found.
%
% ecglab.demo simulates a twelve-lead recording, runs the full analysis chain,
% narrates each stage, and prints the study report. The fastest way to see the
% module end to end.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: the guided tour ===');

% With no output the tour prints itself. Pass 'Draw', true in a figure session
% to also save the three reading pages.
ecglab.demo();
disp('=== done ===');
%=============================================================================
