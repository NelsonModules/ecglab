%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabReportWrite(path, text)
  % Write the report text to a file. Errors if the path cannot be opened.
  fid = fopen(path, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotOpenFileWriting', 'Cannot open the file for writing: %s.', path);
  end
  % Write the text as is; text mode may add carriage returns per platform.
  fprintf(fid, '%s', text);
  fclose(fid);
end
%=============================================================================
