%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function class = ecgLabAami(symbol, table)
  % Map each PhysioNet symbol to its AAMI EC57 class (N, S, V, F, Q); a space
  % marks a non-beat. Two tables differ on the escape beats: 'bxb' follows the
  % standard comparator, 'dechazal' follows de Chazal 2004.
  if nargin < 2 || isempty(table)
    table = 'bxb';
  end
  symbol = reshape(char(symbol), [], 1);
  class = repmat(' ', numel(symbol), 1);
  switch lower(char(table))
    case 'bxb'
      normal = 'NLRB';
      supra = 'AaJSejn';
      ventricular = 'VrE';
      unknown = '/fQ?';
    case 'dechazal'
      normal = 'NLRBej';
      supra = 'AaJSn';
      ventricular = 'VrE';
      unknown = '/fQ?';
    otherwise
      error('ecglab:unknownTable', 'Unknown class table: %s (bxb or dechazal).', char(table));
  end
  class(ismember(symbol, normal)) = 'N';
  class(ismember(symbol, supra)) = 'S';
  class(ismember(symbol, ventricular)) = 'V';
  class(symbol == 'F') = 'F';
  class(ismember(symbol, unknown)) = 'Q';
end
%=============================================================================
