%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function tf = ecgLabAnalyzeHasLimbLeads(recording)
  % True when ecglab.leads can run: the limb leads derive from I and II, so both
  % must be present. Checked here so a single-lead record skips leads() quietly.
  names = lower(recording.leads);
  tf = any(strcmp('i', names)) && any(strcmp('ii', names));
end
%=============================================================================
