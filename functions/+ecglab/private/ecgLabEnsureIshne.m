%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabEnsureIshne()
  % Load the ishne module on demand. It owns the ISHNE Holter format that
  % ecglab.readishne uses. Installed by a package manager it is already loaded;
  % in the development layout it sits next to this module and is loaded here so
  % a fresh session resolves ishne.read.
  if ismodule('ishne')
    return;
  end
  sibling = [modulepath('ecglab'), '/../ishne/loader.m'];
  if isfile(sibling)
    run(sibling);
  end
  if ~ismodule('ishne')
    error('ecglab:ishneDependencyMissing', 'The ishne module (a dependency of ecglab) is not loaded.');
  end
end
%=============================================================================
