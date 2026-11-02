%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [samples, rate, names] = ecgLabLeadsInput(X, options)
  % The signal matrix, its rate and the lead names, from an ecglab.recording
  % (which carries all three) or a numeric matrix (which must be given Rate and
  % Leads, since the axis needs to know which column is which lead).
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    samples = double(X.samples);
    rate = double(X.rate);
    names = X.leads;
    return;
  end
  if isnumeric(X) && ~isempty(X) && ismatrix(X)
    if isempty(options.Rate)
      error('ecglab:needRateSignalMatrixNeedsIts', 'A signal matrix needs its sampling rate, given as Rate.');
    end
    rate = double(options.Rate);
    if ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
      error('ecglab:badRateSamplingRateOnePositive', 'The sampling rate must be one positive number of hertz.');
    end
    samples = double(X);
    if isvector(samples)
      samples = samples(:);
    end
    names = ecgLabLeadsNames(options.Leads, size(samples, 2));
    return;
  end
  error('ecglab:notARecording', 'X must be an ecglab.recording or a numeric matrix with Rate and Leads.');
end
%=============================================================================
function names = ecgLabLeadsNames(given, count)
  % The lead names of a matrix input: one per column, since the axis and the
  % Sokolow-Lyon criterion read named leads, not column positions.
  if isempty(given)
    error('ecglab:needLeads', 'A signal matrix needs its lead names, given as Leads.');
  end
  if ischar(given) || isStringScalar(given)
    given = {char(given)};
  end
  if ~iscell(given) || numel(given) ~= count
    error('ecglab:badLeadsLeadsOneNamePer', 'Leads must be one name per column (%d expected).', count);
  end
  names = reshape(given, 1, count);
  for index = 1:count
    names{index} = char(names{index});
  end
end
%=============================================================================
