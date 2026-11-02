%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function lines = ecgLabReportWrap(text, width)
  % Greedy word wrap to the column width. Returns a cell of lines, none longer
  % than the width.
  words = ecgLabReportTokens(text);
  lines = {};
  current = '';
  for index = 1:numel(words)
    word = words{index};
    if isempty(current)
      candidate = word;
    else
      candidate = [current, ' ', word];
    end
    if numel(candidate) <= width
      current = candidate;
    else
      % Word does not fit: flush the current line and start a new one with it.
      % A word longer than the width is left whole, not split.
      if ~isempty(current)
        lines{end + 1} = current;
      end
      current = word;
    end
  end
  if ~isempty(current)
    lines{end + 1} = current;
  end
  if isempty(lines)
    lines = {''};
  end
end
%=============================================================================
function words = ecgLabReportTokens(text)
  % Split on runs of blanks, dropping empty tokens.
  text = strrep(char(text), char(9), ' ');
  parts = strsplit(text, ' ');
  words = {};
  for index = 1:numel(parts)
    if ~isempty(parts{index})
      words{end + 1} = parts{index};
    end
  end
end
%=============================================================================
