%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = ecgLabStripResolve(X, options)
  % The recording a strip is drawn from, whether the caller passed a recording
  % or a signal vector with its rate.
  %
  % A recording is used as is. A numeric vector is wrapped into a one-lead
  % recording with the 'Rate' option (required) and the 'Lead' option as its
  % name. A recording with no lead is refused here.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    recording = X;
    if size(recording.samples, 2) < 1 || isempty(recording.leads)
      error('ecglab:noLeads', 'The recording carries no lead to draw.');
    end
    return;
  end
  if isnumeric(X) && isvector(X) && ~isempty(X)
    if isempty(options.Rate)
      error('ecglab:rateRequiredSignalVectorNeedsIts', 'A signal vector needs its sampling rate given as ''Rate''.');
    end
    name = 'lead1';
    if ischar(options.Lead) || (isstring(options.Lead) && ...
      isscalar(options.Lead))
      name = char(options.Lead);
    end
    recording = ecgLabRecording(double(X(:)), double(options.Rate), ...
    {name}, {'mV'}, struct('name', '', 'source', '', 'format', 'csv'));
    return;
  end
  error('ecglab:badInputStripDrawnFromRecording', 'A strip is drawn from a recording or a signal vector with a rate.');
end
%=============================================================================
