%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [names, gains] = ecgLabSimulateLeads(specification)
  % The twelve standard leads and a fixed relative gain for each, with lead II
  % as the unit (gain 1.0). Negative gains for aVR and V1 flip their deflection.
  % SPECIFICATION is a count (first so many leads) or a list of names; a name
  % not in the table keeps unit gain.
  standard = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
  'V4', 'V5', 'V6'};
  table = [0.6, 1.0, 0.4, -0.8, 0.1, 0.7, -0.5, 0.4, 0.6, 0.8, 1.0, 1.2];
  if isnumeric(specification)
    count = round(specification);
    if ~isscalar(count) || count < 1 || count > 12
      error('ecglab:badLeadsLeadCountBetweenOne', 'A lead count must be between one and twelve.');
    end
    names = standard(1:count);
    gains = table(1:count);
    return;
  end
  if ischar(specification) || isStringScalar(specification)
    names = {char(specification)};
  elseif iscell(specification)
    names = specification;
  else
    error('ecglab:badLeadsLeadsCountListLead', 'Leads is a count or a list of lead names.');
  end
  names = reshape(names, 1, numel(names));
  gains = ones(1, numel(names));
  for index = 1:numel(names)
    names{index} = char(names{index});
    match = find(strcmpi(names{index}, standard), 1);
    if ~isempty(match)
      gains(index) = table(match);
    end
  end
end
%=============================================================================
