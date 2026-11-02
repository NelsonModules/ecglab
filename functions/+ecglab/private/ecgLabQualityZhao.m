%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function label = ecgLabQualityZhao(ksqi, psqi, bassqi)
  % Rule-based fusion of Zhao and Zhang (2018): Excellent when all three
  % indices are good, Unacceptable when all three are bad, else Barely acceptable.
  pGood = psqi > 0.5 && psqi < 0.8;
  kGood = ksqi > 5;
  bGood = bassqi > 0.95;
  if pGood && kGood && bGood
    label = 'Excellent';
  elseif ~pGood && ~kGood && ~bGood
    label = 'Unacceptable';
  else
    label = 'Barely acceptable';
  end
end
%=============================================================================
