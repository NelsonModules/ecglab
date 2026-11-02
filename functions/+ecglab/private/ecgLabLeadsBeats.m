%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function beats = ecgLabLeadsBeats(derived, options)
  % The beats every lead is delineated against, so the intervals and axis share
  % one set. Given beats are used as is; otherwise the default detector (or the
  % named method) finds them on the derived recording.
  if ~isempty(options.Beats)
    beats = options.Beats;
    if ~isstruct(beats) || ~isfield(beats, 'sample')
      error('ecglab:badBeatsBeatsBeatsStructFrom', 'Beats must be a beats struct from ecglab.detect.');
    end
    return;
  end
  if isempty(options.Method)
    beats = ecglab.detect(derived);
  else
    beats = ecglab.detect(derived, 'Method', options.Method);
  end
end
%=============================================================================
