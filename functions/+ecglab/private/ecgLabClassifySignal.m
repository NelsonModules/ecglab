%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [signal, rate, leadName, column] = ecgLabClassifySignal(X, lead, ...
  rateOption)
  % Extract one lead and its rate, using the same lead priority as the
  % detector. A recording carries its rate and lead names; a plain vector must
  % be given its rate.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    rate = double(X.rate);
    column = ecgLabClassifyLead(X.leads, lead);
    signal = double(X.samples(:, column));
    leadName = X.leads{column};
    return;
  end
  if isnumeric(X) && isvector(X) && ~isempty(X)
    if isempty(rateOption)
      error('ecglab:needRateSignalVectorNeedsIts', 'A signal vector needs its sampling rate, given as Rate.');
    end
    rate = double(rateOption);
    if ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
      error('ecglab:badRateSamplingRateOnePositive', 'The sampling rate must be one positive number of hertz.');
    end
    signal = double(X(:));
    leadName = '';
    column = 1;
    return;
  end
  error('ecglab:notASignalXEcglabRecordingSignal', 'X must be an ecglab.recording or a signal vector with a Rate.');
end
%=============================================================================
function column = ecgLabClassifyLead(leads, lead)
  % Resolve the lead column. Default priority: MLII, then limb leads, then a
  % precordial lead, then the first lead. A name or an index is also accepted.
  if isempty(lead)
    preferred = {'MLII', 'II', 'I', 'V5'};
    for index = 1:numel(preferred)
      match = find(strcmpi(preferred{index}, leads), 1);
      if ~isempty(match)
        column = match;
        return;
      end
    end
    column = 1;
    return;
  end
  if ischar(lead) || isStringScalar(lead)
    name = char(lead);
    match = find(strcmpi(name, leads), 1);
    if isempty(match)
      error('ecglab:unknownLeadRecordingHasNoLead', 'The recording has no lead named %s.', name);
    end
    column = match;
    return;
  end
  if isnumeric(lead) && isscalar(lead)
    column = round(double(lead));
    if column < 1 || column > numel(leads)
      error('ecglab:unknownLeadLeadIndexDOutside', 'The lead index %d is outside the %d leads.', column, numel(leads));
    end
    return;
  end
  error('ecglab:badLeadLeadNameColumnIndex', 'The lead must be a name or a column index.');
end
%=============================================================================
