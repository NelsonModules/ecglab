%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function steps = ecgLabAnalyzeDo(given)
  % Which steps of the chain to run, as a struct of logicals, one per analysis.
  % Empty runs every step; a list runs only those named. An unknown name is an
  % error.
  known = {'quality', 'detect', 'delineate', 'classify', 'rhythm', ...
  'hrv', 'leads'};
  steps = struct();
  if isempty(given)
    for index = 1:numel(known)
      steps.(known{index}) = true;
    end
    return;
  end
  if ischar(given) || isStringScalar(given)
    given = {char(given)};
  end
  if ~iscell(given)
    error('ecglab:badDoDoNameListAnalysis', 'Do must be a name or a list of analysis names.');
  end
  for index = 1:numel(known)
    steps.(known{index}) = false;
  end
  for index = 1:numel(given)
    name = given{index};
    if ~(ischar(name) || isStringScalar(name))
      error('ecglab:badDoEachDoEntryAnalysis', 'Each Do entry must be an analysis name.');
    end
    name = lower(char(name));
    if ~any(strcmp(name, known))
      error('ecglab:unknownAnalysis', 'Unknown analysis in Do: %s.', name);
    end
    steps.(name) = true;
  end
end
%=============================================================================
