%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = ecgLabRecording(samples, rate, leads, units, info)
  % The common recording struct every reader returns: one column per lead in
  % physical units, the lead names, units and provenance. Inputs validated here.
  if ~isnumeric(samples) || ~isreal(samples) || ndims(samples) > 2
    error('ecglab:badSamples', 'The samples must be a real matrix with one column per lead.');
  end
  samples = double(samples);
  if isvector(samples)
    % A single lead is a column: a row would be one sample of many leads.
    samples = samples(:);
  end
  count = size(samples, 2);
  if ~isnumeric(rate) || ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
    error('ecglab:badRateSamplingRateOnePositive', 'The sampling rate must be one positive number of hertz.');
  end
  if nargin < 3 || isempty(leads)
    leads = ecgLabDefaultLeads(count);
  end
  leads = ecgLabTextList(leads, count, 'lead names');
  if nargin < 4 || isempty(units)
    units = repmat({'mV'}, 1, count);
  elseif ischar(units) || isStringScalar(units)
    units = repmat({char(units)}, 1, count);
  end
  units = ecgLabTextList(units, count, 'units');
  if nargin < 5 || isempty(info)
    info = struct();
  end
  recording = struct();
  recording.kind = 'ecglab.recording';
  recording.rate = double(rate);
  recording.samples = samples;
  recording.leads = leads;
  recording.units = units;
  recording.seconds = size(samples, 1) / double(rate);
  recording.info = ecgLabInfo(info);
  recording.annotations = ecgLabAnnotations();
  recording.gain = 200 * ones(1, count);
  recording.baseline = zeros(1, count);
end
%=============================================================================
function leads = ecgLabDefaultLeads(count)
  % The twelve standard names for twelve leads, numbered names otherwise.
  standard = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
  'V4', 'V5', 'V6'};
  if count == 12
    leads = standard;
    return;
  end
  leads = cell(1, count);
  for index = 1:count
    leads{index} = sprintf('lead%d', index);
  end
end
%=============================================================================
function list = ecgLabTextList(list, count, what)
  if ischar(list)
    list = cellstr(list);
  elseif isstring(list)
    list = cellstr(list);
  end
  if ~iscell(list) || numel(list) ~= count
    error('ecglab:badLeadsSOneTextPer', 'The %s must be one text per lead (%d expected).', what, count);
  end
  list = reshape(list, 1, count);
  for index = 1:count
    list{index} = char(list{index});
  end
end
%=============================================================================
function info = ecgLabInfo(given)
  % Fill every info field a page may print, so no page has to test for one.
  % startTimeKnown flags whether a clock was recorded.
  info = struct('name', '', 'source', '', 'format', '', ...
  'startTime', '00.00.00', 'startTimeKnown', false, 'startDate', '', ...
  'subject', '', 'comments', {{}});
  names = fieldnames(given);
  for index = 1:numel(names)
    info.(names{index}) = given.(names{index});
  end
end
%=============================================================================
