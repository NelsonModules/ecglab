%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = readcsv(varargin)
  % READCSV Read a recording from a delimited text file.
  %
  %   RECORDING = ECGLAB.READCSV(FILE) reads FILE, one column per lead, and
  %   returns the same recording struct every reader of the module returns.
  %
  %   The file is read whole in one fileread. The delimiter is learnt from the
  %   first line, a header of names is taken when the first line is not numeric,
  %   and a monotonic first column of times (seconds or milliseconds) gives the
  %   rate as its median step and is taken off the leads.
  %
  %   The numeric body is parsed with one sscanf over the whole text, which is
  %   faster than str2double over a split.
  %
  %   Options (name and value pairs, matched without regard to case):
  %     'Rate'       the sampling rate in hertz, required when there is no
  %                  time column to give it.
  %     'Delimiter'  the column separator, when it must not be detected.
  %     'Leads'      the names to assign to the columns.
  %     'Units'      the unit the file is written in; 'uV' divides by a
  %                  thousand so the recording is in millivolts.
  %     'Scale'      a divisor applied to every value.
  %     'TimeColumn' true to read the first column as a time even when its
  %                  header does not announce it.
  %     'TimeUnit'   'seconds' or 'milliseconds', when the time column's unit
  %                  must not be guessed from the size of its step.
  %     'Skip'       a number of leading lines to drop before the header.
  %     'Decimal'    ',' for a French export, where the separator is then ';'.
  %
  %   Example:
  %     recording = ecglab.readcsv('export.csv', 'Rate', 500);
  %
  %   See also ecglab.readishne, ecglab.readwfdb, ecglab.readedf.
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
  defaults = struct('Rate', [], 'Delimiter', '', 'Leads', {{}}, ...
  'Units', 'mV', 'Scale', [], 'TimeColumn', false, 'TimeUnit', '', ...
  'Skip', 0, 'Decimal', '.');
  options = ecgLabOptions(defaults, varargin(2:end));
  % One read of the whole file, not line by line.
  raw = fileread(file);
  raw = strrep(raw, char(13), '');
  % Line starts from the newline positions, so a line is a slice of the text.
  breaks = [0, strfind(raw, char(10))];
  if isempty(raw) || (numel(raw) == 1 && raw(1) == char(10))
    error('ecglab:emptyFile', 'The file %s has no data.', file);
  end
  skip = max(0, round(ecgLabScalar(options.Skip, 'Skip')));
  headerIndex = skip + 1;
  firstLine = ecgLabCsvLine(raw, breaks, headerIndex);
  % A French decimal comma forces the semicolon separator, else every number
  % would split in half.
  decimal = char(options.Decimal);
  delimiter = ecgLabCsvDelimiter(firstLine, char(options.Delimiter), decimal);
  firstFields = ecgLabCsvSplit(firstLine, delimiter);
  % A header is a first line that is not all numbers; its fields name the leads.
  headerPresent = ~ecgLabCsvAllNumeric(firstFields, decimal);
  if headerPresent
    headerNames = firstFields;
    dataIndex = headerIndex + 1;
  else
    headerNames = {};
    dataIndex = headerIndex;
  end
  dataLine = ecgLabCsvLine(raw, breaks, dataIndex);
  columns = numel(ecgLabCsvSplit(dataLine, delimiter));
  if columns < 1
    error('ecglab:badCsvFileSHasNo', 'The file %s has no columns.', file);
  end
  % The body begins at the first data line; skip any banner or header.
  if dataIndex >= 1 && dataIndex <= numel(breaks)
    bodyStart = breaks(dataIndex) + 1;
  else
    bodyStart = 1;
  end
  body = raw(bodyStart:end);
  values = ecgLabCsvScan(body, delimiter, decimal);
  rows = floor(numel(values) / columns);
  if rows < 1
    error('ecglab:badCsvFileSHasNo2', 'The file %s has no numeric rows after its header.', file);
  end
  matrix = reshape(values(1:rows * columns), columns, rows).';
  % Decide the time column before the leads: it is the first column, sets the
  % rate and must not become a lead.
  [hasTime, rate] = ecgLabCsvTime(matrix, headerNames, headerPresent, ...
  options, file);
  if hasTime
    matrix = matrix(:, 2:end);
    if ~isempty(headerNames)
      headerNames = headerNames(2:end);
    end
    columns = columns - 1;
  end
  if columns < 1
    error('ecglab:badCsvFileSHasTime', 'The file %s has a time column and no signal.', file);
  end
  % Microvolts and an explicit scale both divide the raw numbers; the module
  % works in millivolts.
  [scale, unit] = ecgLabCsvScale(options);
  if scale ~= 1
    matrix = matrix / scale;
  end
  leads = ecgLabCsvLeads(options.Leads, headerNames, columns);
  info = struct('name', ecgLabCsvName(file), 'source', file, ...
  'format', 'csv');
  recording = ecgLabRecording(matrix, rate, leads, unit, info);
end
%=============================================================================
function line = ecgLabCsvLine(raw, breaks, index)
  % The INDEX-th line as a slice of the text; empty past the end.
  if index < 1 || index > numel(breaks)
    line = '';
    return;
  end
  first = breaks(index) + 1;
  if index + 1 <= numel(breaks)
    last = breaks(index + 1) - 1;
  else
    last = numel(raw);
  end
  if last < first
    line = '';
    return;
  end
  line = strtrim(raw(first:last));
end
%=============================================================================
function delimiter = ecgLabCsvDelimiter(line, given, decimal)
  % Given wins; then a French decimal forces the semicolon; then the first of
  % comma, semicolon or tab on the line; otherwise runs of spaces.
  if ~isempty(given)
    delimiter = given;
    return;
  end
  if strcmp(decimal, ',')
    delimiter = ';';
    return;
  end
  if any(line == ',')
    delimiter = ',';
  elseif any(line == ';')
    delimiter = ';';
  elseif any(line == char(9))
    delimiter = char(9);
  else
    delimiter = ' ';
  end
end
%=============================================================================
function fields = ecgLabCsvSplit(line, delimiter)
  % A space delimiter means one or more spaces or tabs, so runs collapse to one
  % separator.
  if isempty(line)
    fields = {};
    return;
  end
  if strcmp(delimiter, ' ')
    line = strrep(line, char(9), ' ');
    pieces = strsplit(line, ' ');
    fields = {};
    for index = 1:numel(pieces)
      if ~isempty(pieces{index})
        fields{end + 1} = pieces{index};
      end
    end
    return;
  end
  fields = strsplit(line, delimiter);
  for index = 1:numel(fields)
    fields{index} = strtrim(fields{index});
  end
end
%=============================================================================
function tf = ecgLabCsvAllNumeric(fields, decimal)
  % A field is numeric once its decimal comma is made a dot; a lead name is not.
  tf = ~isempty(fields);
  for index = 1:numel(fields)
    text = fields{index};
    if strcmp(decimal, ',')
      text = strrep(text, ',', '.');
    end
    if isnan(str2double(text))
      tf = false;
      return;
    end
  end
end
%=============================================================================
function values = ecgLabCsvScan(body, delimiter, decimal)
  % Turn every separator into a space and every decimal comma into a dot, then
  % read the whole body with one sscanf. A tab or space is already a separator,
  % so only a printable delimiter is replaced.
  text = body;
  if strcmp(decimal, ',')
    if ~strcmp(delimiter, ' ') && ~strcmp(delimiter, char(9)) && ...
      ~strcmp(delimiter, ',')
      text = strrep(text, delimiter, ' ');
    end
    text = strrep(text, ',', '.');
  elseif ~strcmp(delimiter, ' ') && ~strcmp(delimiter, char(9))
    text = strrep(text, delimiter, ' ');
  end
  values = sscanf(text, '%f');
end
%=============================================================================
function [hasTime, rate] = ecgLabCsvTime(matrix, names, headerPresent, ...
  options, file)
  % A first column of times gives the rate as the median step (robust to a
  % dropped sample). The unit is from the header, forced by TimeUnit, else
  % guessed from the step: larger than one means milliseconds.
  hasTime = false;
  wanted = logical(ecgLabCsvFlag(options.TimeColumn));
  named = false;
  headerName = '';
  if headerPresent && ~isempty(names)
    headerName = lower(strtrim(names{1}));
    named = any(strcmp(headerName, {'time', 't', 'seconds', 'ms'}));
  end
  if wanted || named
    hasTime = true;
  end
  if ~hasTime
    if isempty(options.Rate)
      error('ecglab:rateRequiredSamplingRateUnknownGive', 'The sampling rate is unknown; give it with the Rate option.');
    end
    rate = ecgLabScalar(options.Rate, 'Rate');
    return;
  end
  time = matrix(:, 1);
  if numel(time) < 2
    error('ecglab:badTimeTimeColumnSToo', 'The time column of %s is too short to give a rate.', file);
  end
  step = median(diff(time));
  if step <= 0
    error('ecglab:badTimeTimeColumnSDoes', 'The time column of %s does not increase.', file);
  end
  unit = lower(char(options.TimeUnit));
  if strcmp(headerName, 'ms')
    milliseconds = true;
  elseif strcmp(unit, 'seconds') || strcmp(unit, 's')
    milliseconds = false;
  elseif strcmp(unit, 'milliseconds') || strcmp(unit, 'ms')
    milliseconds = true;
  else
    milliseconds = step > 1;
  end
  if milliseconds
    step = step / 1000;
  end
  rate = 1 / step;
end
%=============================================================================
function [scale, unit] = ecgLabCsvScale(options)
  scale = 1;
  unit = 'mV';
  if ~isempty(options.Units)
    given = char(options.Units);
    if strcmpi(given, 'uV')
      scale = 1000;
      unit = 'mV';
    else
      unit = given;
    end
  end
  if ~isempty(options.Scale)
    scale = ecgLabScalar(options.Scale, 'Scale');
  end
  if ~(scale ~= 0) || ~isfinite(scale)
    error('ecglab:badScaleScaleOneNonZero', 'The scale must be one non-zero number.');
  end
end
%=============================================================================
function leads = ecgLabCsvLeads(given, names, count)
  % The Leads option wins, then the header names, then the ecgLabRecording
  % defaults. An empty list lets the recording name the leads itself.
  if ~isempty(given)
    leads = given;
    return;
  end
  if ~isempty(names) && numel(names) == count
    leads = names;
    return;
  end
  leads = {};
end
%=============================================================================
function value = ecgLabScalar(given, what)
  if ~isnumeric(given) || ~isscalar(given) || ~isreal(given)
    error('ecglab:badOptionValue', 'The %s option must be one number.', what);
  end
  value = double(given);
end
%=============================================================================
function tf = ecgLabCsvFlag(given)
  if islogical(given) || isnumeric(given)
    tf = any(given(:) ~= 0);
    return;
  end
  tf = any(strcmpi(char(given), {'true', 'yes', 'on', '1'}));
end
%=============================================================================
function name = ecgLabCsvName(file)
  % The bare file name without folder or extension.
  [~, stem] = fileparts(file);
  name = stem;
end
%=============================================================================
