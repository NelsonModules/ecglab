%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = ecgLabAnalyzeInput(X, options)
  % Build one recording from whatever the caller passed: an existing recording,
  % a file path, a reference record name, or a signal matrix.
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    recording = X;
    return;
  end
  if isnumeric(X)
    % A signal matrix, one column per lead. It carries no rate, so the caller
    % must give it; a recording is built so the rest of the chain sees one shape.
    if isempty(options.Rate)
      error('ecglab:needRateSignalMatrixNeedsIts', 'A signal matrix needs its sampling rate, given as Rate.');
    end
    recording = ecgLabRecording(double(X), double(options.Rate));
    return;
  end
  if ischar(X) || isStringScalar(X)
    recording = ecgLabAnalyzeRead(char(X), options);
    return;
  end
  error('ecglab:notAnInputXEcglabRecordingFile', 'X must be an ecglab.recording, a file path, or a signal matrix with Rate.');
end
%=============================================================================
function recording = ecgLabAnalyzeRead(path, options)
  % Dispatch a path to the reader its extension names, so the format is chosen
  % from the name rather than guessed from the bytes.
  [~, ~, ext] = fileparts(path);
  ext = lower(ext);
  switch ext
    case {'.hea', '.dat'}
      % WFDB names a record by its base; strip the extension to get the base.
      base = path(1:end - numel(ext));
      recording = ecglab.readwfdb(base);
    case '.edf'
      recording = ecglab.readedf(path);
    case {'.csv', '.txt'}
      rateArg = ecgLabAnalyzeRateArg(options);
      recording = ecglab.readcsv(path, rateArg{:});
    case '.ecg'
      recording = ecglab.readishne(path);
    case ''
      recording = ecgLabAnalyzeNoExt(path);
    otherwise
      error('ecglab:unknownFormatNoReaderKnownFile', 'No reader is known for the file extension %s.', ext);
  end
end
%=============================================================================
function recording = ecgLabAnalyzeNoExt(path)
  % A name with no extension is either a WFDB record base on disk (NAME.hea) or
  % a 'database/record' reference to fetch. A file on disk is preferred.
  if isfile([path, '.hea'])
    recording = ecglab.readwfdb(path);
    return;
  end
  if any(path == '/') || any(path == '\')
    % A 'database/record' name with no file on disk: fetch it from the open
    % databases. This is the one path that may reach the network.
    recording = ecglab.reference(path);
    return;
  end
  error('ecglab:notReadable', 'Cannot read %s: no such WFDB record, and not a reference record name.', path);
end
%=============================================================================
function rateArg = ecgLabAnalyzeRateArg(options)
  % Pass the rate through to the CSV reader only when the caller set it, so a
  % file that carries its own rate is not overridden.
  if isempty(options.Rate)
    rateArg = {};
  else
    rateArg = {'Rate', double(options.Rate)};
  end
end
%=============================================================================
