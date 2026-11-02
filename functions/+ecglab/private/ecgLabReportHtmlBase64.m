%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function text = ecgLabReportHtmlBase64(bytes)
  % Standard base64 (RFC 4648) of a byte vector, for embedding an image as a
  % data URI. Bytes are taken three at a time and split into four 6-bit indices.
  alphabet = ['ABCDEFGHIJKLMNOPQRSTUVWXYZ', ...
  'abcdefghijklmnopqrstuvwxyz0123456789+/'];
  data = double(bytes(:)');
  n = numel(data);
  if n == 0
    text = '';
    return;
  end
  %===========================================================================
  % Pad with zeros up to a multiple of three; these become '=' at the end.
  pad = mod(3 - mod(n, 3), 3);
  data = [data, zeros(1, pad)];
  triples = reshape(data, 3, [])';
  value = triples(:, 1) * 65536 + triples(:, 2) * 256 + triples(:, 3);
  %===========================================================================
  % The four 6-bit fields of each 24-bit group, mapped through the alphabet.
  c1 = floor(value / 262144);
  c2 = mod(floor(value / 4096), 64);
  c3 = mod(floor(value / 64), 64);
  c4 = mod(value, 64);
  indices = [c1, c2, c3, c4]';
  chars = alphabet(indices(:) + 1);
  text = reshape(chars, 1, []);
  %===========================================================================
  % The last `pad` characters stand for padding bytes and are written '='.
  if pad > 0
    text(end - pad + 1:end) = '=';
  end
end
%=============================================================================
