%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabEnsureEdf()
  % Load the edf module on demand. It owns the EDF/EDF+/BDF/BDF+ format that
  % ecglab.readedf and ecglab.writeedf use. Installed by a package manager it
  % is already loaded; in the development layout it sits next to this module
  % and is loaded here so a fresh session resolves edf.read and edf.write.
  if ismodule('edf')
    return;
  end
  sibling = [modulepath('ecglab'), '/../edf/loader.m'];
  if isfile(sibling)
    run(sibling);
  end
  if ~ismodule('edf')
    error('ecglab:edfDependencyMissing', 'The edf module (a dependency of ecglab) is not loaded.');
  end
end
%=============================================================================
