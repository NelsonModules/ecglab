%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function uri = ecgLabReportHtmlImage(imagePath)
  % Read a saved page image and return it as a base64 data URI for embedding in
  % the HTML report. The media type follows the extension: SVG or PNG.
  fid = fopen(imagePath, 'rb');
  if fid < 0
    error('ecglab:cannotReadImage', 'Cannot read the page image %s.', imagePath);
  end
  bytes = fread(fid, Inf, 'uint8');
  fclose(fid);
  if ecgLabReportHtmlEndsWith(lower(imagePath), '.svg')
    mediaType = 'image/svg+xml';
  else
    mediaType = 'image/png';
  end
  uri = ['data:', mediaType, ';base64,', ecgLabReportHtmlBase64(bytes)];
end
%=============================================================================
function tf = ecgLabReportHtmlEndsWith(text, suffix)
  n = numel(suffix);
  tf = numel(text) >= n && strcmp(text(end - n + 1:end), suffix);
end
%=============================================================================
