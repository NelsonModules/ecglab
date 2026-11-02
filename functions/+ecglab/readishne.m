%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = readishne(varargin)
  % READISHNE Read a recording in the ISHNE Holter format.
  %
  %   RECORDING = ECGLAB.READISHNE(FILE) reads FILE, an ISHNE 1.0 Holter file,
  %   and returns the module's recording struct.
  %
  %   The ishne toolbox reads the binary format; this reader maps its struct
  %   onto the ecglab recording. Samples are returned in millivolts.
  %
  %   Example:
  %     recording = ecglab.readishne('holter.ecg');
  %
  %   See also ecglab.readcsv, ecglab.readwfdb, ecglab.readedf, ishne.read.
  narginchk(1, inf);
  nargoutchk(0, 1);
  file = varargin{1};
  if ~ischar(file) && ~isStringScalar(file)
    error('ecglab:badNameFileNameText', 'The file name must be text.');
  end
  file = char(file);
  if ~isfile(file)
    error('ecglab:noFileFileSNotDisk', 'The file %s is not on disk.', file);
  end
  % Options are parsed for forward compatibility; none is read yet.
  ecgLabOptions(struct(), varargin(2:end));
  ecgLabEnsureIshne();
  r = ecgLabIshneReadNeutral(file);
  units = repmat({'mV'}, 1, r.leadCount);
  info = ecgLabIshneInfo(r, file);
  recording = ecgLabRecording(r.samples, r.samplingRate, r.leadNames, units, ...
  info);
end
%=============================================================================
function r = ecgLabIshneReadNeutral(file)
  % Re-raise an ishne toolbox error as the module's own error. Samples come back
  % in physical millivolts.
  try
    r = ishne.read(file, 'Physical', true);
  catch e
    if strncmp(e.identifier, 'ishne:', 6)
      error('ecglab:badIshneRecord', '%s', e.message);
    end
    rethrow(e);
  end
end
%=============================================================================
function info = ecgLabIshneInfo(r, file)
  % Subject is the two name fields joined; clock and date come from the header's
  % start time and record date. The variable block is free text, kept as comment.
  h = r.header;
  subject = strtrim([h.firstName, ' ', h.lastName]);
  info = struct('name', h.id, 'source', file, 'format', 'ishne', ...
  'subject', subject);
  time = h.startTime;
  info.startTime = sprintf('%02d.%02d.%02d', time(1), time(2), time(3));
  info.startTimeKnown = any(time ~= 0);
  date = h.recordDate;
  if any(date ~= 0)
    info.startDate = sprintf('%02d/%02d/%04d', date(1), date(2), date(3));
  else
    info.startDate = '';
  end
  info.comments = {};
  if ~isempty(r.variableText)
    info.comments = {r.variableText};
  end
  info.recorder = strtrim(h.recorder);
end
%=============================================================================
