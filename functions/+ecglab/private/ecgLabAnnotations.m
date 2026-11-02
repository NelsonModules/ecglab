%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function annotations = ecgLabAnnotations(sample, symbol, num, subtype, ...
  chan, aux, rate)
  % Annotations as a struct of column vectors (not a struct array, which would
  % be slow for the many thousands of marks a record can hold). Every field has
  % the same length; missing ones are filled with a zero or empty text.
  annotations = struct();
  annotations.kind = 'ecglab.annotations';
  if nargin < 1 || isempty(sample)
    annotations.sample = zeros(0, 1);
    annotations.time = zeros(0, 1);
    annotations.symbol = char(zeros(0, 1));
    annotations.num = zeros(0, 1);
    annotations.subtype = zeros(0, 1);
    annotations.chan = zeros(0, 1);
    annotations.aux = cell(0, 1);
    if nargin >= 7 && ~isempty(rate)
      annotations.rate = double(rate);
    else
      annotations.rate = NaN;
    end
    return;
  end
  sample = double(sample(:));
  count = numel(sample);
  if nargin < 7 || isempty(rate)
    rate = NaN;
  end
  if nargin < 2 || isempty(symbol)
    symbol = repmat('N', count, 1);
  end
  if iscell(symbol)
    symbol = char(symbol);
  end
  symbol = reshape(char(symbol), [], 1);
  if numel(symbol) ~= count
    error('ecglab:badAnnotationsOneSymbolPerAnnotation', 'One symbol per annotation is needed (%d samples, %d symbols).', count, numel(symbol));
  end
  annotations.sample = sample;
  annotations.time = (sample - 1) / double(rate);
  annotations.symbol = symbol;
  annotations.num = ecgLabColumn(num, count, 3);
  annotations.subtype = ecgLabColumn(subtype, count, 4);
  annotations.chan = ecgLabColumn(chan, count, 5);
  if nargin < 6 || isempty(aux)
    aux = repmat({''}, count, 1);
  elseif ischar(aux)
    aux = repmat({aux}, count, 1);
  end
  aux = reshape(aux, [], 1);
  if numel(aux) ~= count
    error('ecglab:badAnnotationsOneAuxTextPer', 'One aux text per annotation is needed (%d samples, %d texts).', count, numel(aux));
  end
  annotations.aux = aux;
  annotations.rate = double(rate);
end
%=============================================================================
function column = ecgLabColumn(value, count, position)
  if nargin < 1 || isempty(value)
    column = zeros(count, 1);
    return;
  end
  column = double(value(:));
  if isscalar(column)
    column = column * ones(count, 1);
  end
  if numel(column) ~= count
    error('ecglab:badAnnotationsArgumentDHaveOne', 'Argument %d must have one value per annotation.', position);
  end
end
%=============================================================================
