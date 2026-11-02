%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function derived = ecgLabLeadsDerive(samples, rate, names)
  % The standard leads, with missing limb leads filled from I and II. The six
  % limb leads are exact linear combinations of I and II (Einthoven and
  % Goldberger). A lead already present is kept as is; the precordials cannot
  % be derived and are carried only when present.
  lowered = lower(names);
  iCol = ecgLabLeadsFind(lowered, 'i');
  iiCol = ecgLabLeadsFind(lowered, 'ii');
  if isempty(iCol) || isempty(iiCol)
    % Without I and II nothing derives: the limb leads are the basis of every
    % measurement here, so their absence is refused.
    error('ecglab:missingLimbLeads', 'The recording must carry the limb leads I and II.');
  end
  I = samples(:, iCol);
  II = samples(:, iiCol);
  % The twelve standard leads in clinical order, each taken from the recording
  % when present and otherwise derived (the precordials are never derived).
  standard = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
  'V4', 'V5', 'V6'};
  N = size(samples, 1);
  outNames = {};
  outSamples = zeros(N, 0);
  for index = 1:numel(standard)
    name = standard{index};
    present = ecgLabLeadsFind(lowered, lower(name));
    if ~isempty(present)
      column = samples(:, present);
    else
      column = ecgLabLeadsCombine(name, I, II);
      if isempty(column)
        % A precordial absent from the recording cannot be made; leave it out.
        continue;
      end
    end
    outNames{end + 1} = name;
    outSamples = [outSamples, column];
  end
  derived = ecgLabRecording(outSamples, rate, outNames, ...
  repmat({'mV'}, 1, numel(outNames)), ...
  struct('name', 'derived', 'source', 'ecglab.leads', 'format', 'derived'));
end
%=============================================================================
function column = ecgLabLeadsCombine(name, I, II)
  % Textbook combination for a missing limb lead, empty for a precordial. III =
  % II - I closes Einthoven's triangle; the augmented leads are Goldberger's.
  switch lower(name)
    case 'iii'
      column = II - I;
    case 'avr'
      column = -(I + II) / 2;
    case 'avl'
      column = I - II / 2;
    case 'avf'
      column = II - I / 2;
    otherwise
      column = [];
  end
end
%=============================================================================
function column = ecgLabLeadsFind(lowered, target)
  % The column of a lead by its lowercased name, empty when absent. Matching is
  % case insensitive.
  column = find(strcmp(lowered, target), 1);
end
%=============================================================================
