%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function options = ecgLabOptions(defaults, given)
  % Overlay name-value pairs onto a struct of defaults, matching names
  % case-insensitively. An unknown name is rejected rather than kept.
  options = defaults;
  if mod(numel(given), 2) ~= 0
    error('ecglab:pairExpected', 'Options come in name and value pairs.');
  end
  known = fieldnames(defaults);
  for index = 1:2:numel(given)
    name = given{index};
    if ~ischar(name) && ~isStringScalar(name)
      error('ecglab:optionName', 'An option name must be text.');
    end
    name = char(name);
    match = find(strcmpi(name, known), 1);
    if isempty(match)
      error('ecglab:unknownOption', 'Unknown option: %s.', name);
    end
    options.(known{match}) = given{index + 1};
  end
end
%=============================================================================
