%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function analysis = ecgLabChartResolve(X, options)
  % The analysis the chart is drawn from. An analysis is used as it stands; a
  % recording is analysed here with the caller's 'Lead' and 'Detector'.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.analysis')
    analysis = X;
    return;
  end
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    args = {'Detector', options.Detector};
    if ~isempty(options.Lead)
      args = [args, {'Lead', options.Lead}];
    end
    analysis = ecglab.analyze(X, args{:});
    return;
  end
  error('ecglab:badInputChartDrawnFromEcglab', 'A chart is drawn from an ecglab.recording or an ecglab.analysis.');
end
%=============================================================================
