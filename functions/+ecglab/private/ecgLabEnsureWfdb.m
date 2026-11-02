%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabEnsureWfdb()
  % Load the wfdb module on demand. It owns the PhysioNet WFDB record format
  % that ecglab.readwfdb and ecglab.writewfdb use. Installed by a package
  % manager it is already loaded; in the development layout it sits next to
  % this module and is loaded here so a fresh session resolves wfdb.read and
  % wfdb.write.
  if ismodule('wfdb')
    return;
  end
  sibling = [modulepath('ecglab'), '/../wfdb/loader.m'];
  if isfile(sibling)
    run(sibling);
  end
  if ~ismodule('wfdb')
    error('ecglab:wfdbDependencyMissing', 'The wfdb module (a dependency of ecglab) is not loaded.');
  end
end
%=============================================================================
