%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function evidence = ecgLabQrsEvidence(feature, threshold, filtered)
  % The three series a detector leaves behind: the thresholded feature, the
  % per-sample threshold, and the band-passed trace, each a column.
  evidence = struct();
  evidence.feature = feature(:);
  evidence.threshold = threshold(:);
  evidence.filtered = filtered(:);
end
%=============================================================================
