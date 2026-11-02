%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = writeedf(varargin)
  % ecglab.writeedf(FILE, RECORDING) writes RECORDING to an EDF+C file that any
  % EDF tool can open and ecglab.readedf can read back, bar the quantisation.
  %
  % ecglab.writeedf(FILE, RECORDING, 'RecordSeconds', S) sets the length of a
  % data record; the default is one second.
  %
  % INFO = ecglab.writeedf(...) also returns what was written: the record count,
  % samples per record, each lead's physical range and quantisation, and padding.
  %
  % The edf toolbox writes the binary format; this writer maps the recording
  % onto its struct. Each lead's physical range is its min and max with a small
  % margin over the full 16-bit span, so quantisation is (pmax - pmin) / 65535;
  % a trailing partial record is padded with the physical minimum.
  %
  % Example:
  %   recording = ecglab.readedf('record.edf');
  %   ecglab.writeedf('copy.edf', recording);
  %
  % See also ecglab.readedf, edf.write.
  narginchk(2, inf);
  nargoutchk(0, 1);
  filename = varargin{1};
  if ~ischar(filename) && ~isStringScalar(filename)
    error('ecglab:badNameFileNameText', 'The file name must be text.');
  end
  filename = char(filename);
  recording = varargin{2};
  if ~isstruct(recording) || ~isfield(recording, 'samples') || ...
    ~isfield(recording, 'rate')
    error('ecglab:badRecordingRecordingEcglabRecordingStruct', 'The recording must be an ecglab recording struct.');
  end
  options = ecgLabOptions(struct('RecordSeconds', 1), varargin(3:end));
  recordSeconds = options.RecordSeconds;
  if ~isnumeric(recordSeconds) || ~isscalar(recordSeconds) || ...
    ~(recordSeconds > 0) || ~isfinite(recordSeconds)
    error('ecglab:badOptionRecordsecondsOnePositiveNumber', 'RecordSeconds must be one positive number of seconds.');
  end
  ecgLabEnsureEdf();
  samples = double(recording.samples);
  rate = double(recording.rate);
  total = size(samples, 1);
  leadCount = size(samples, 2);
  spr = round(rate * recordSeconds);
  if spr < 1
    error('ecglab:badRateRateRecordLengthGive', 'The rate and record length give fewer than one sample per record.');
  end
  records = max(1, ceil(total / spr));
  padded = records * spr - total;
  [physicalMin, physicalMax] = edfLeadRanges(samples, leadCount);
  leads = edfLeadNames(recording, leadCount);
  units = edfLeadUnits(recording, leadCount);
  % Build the neutral struct: one signal per lead at the recording's rate with
  % the physical range reported here, and the annotations as onset and text.
  r = struct();
  r.signals = edfNeutralSignals(samples, rate, leads, units, ...
  physicalMin, physicalMax);
  r.annotations = edfNeutralAnnotations(recording, rate);
  [r.patient, r.recording, r.startdate, r.starttime] = edfHeaderFields(recording);
  edf.write(filename, r, 'Format', 'EDF+', 'RecordSeconds', recordSeconds, ...
  'Margin', 0.0015);
  info = struct();
  info.file = filename;
  info.records = records;
  info.samplesPerRecord = spr;
  info.signals = leadCount + 1;
  info.physicalMin = physicalMin;
  info.physicalMax = physicalMax;
  info.quantum = (physicalMax - physicalMin) / 65535;
  info.padded = padded > 0;
  info.padSamples = padded;
end
%=============================================================================
function [physicalMin, physicalMax] = edfLeadRanges(samples, leadCount)
  % Each lead's physical range with a small margin off the digital rails. A flat
  % lead still needs a nonzero span to avoid a divide by zero.
  physicalMin = zeros(1, leadCount);
  physicalMax = zeros(1, leadCount);
  for k = 1:leadCount
    low = min(samples(:, k));
    high = max(samples(:, k));
    if high > low
      margin = (high - low) * 0.0015;
    else
      margin = max(1, abs(high));
    end
    physicalMin(k) = low - margin;
    physicalMax(k) = high + margin;
  end
end
%=============================================================================
function signals = edfNeutralSignals(samples, rate, leads, units, physicalMin, physicalMax)
  leadCount = size(samples, 2);
  signals = struct('label', {}, 'unit', {}, 'rate', {}, 'data', {}, ...
  'physicalMin', {}, 'physicalMax', {});
  for k = 1:leadCount
    signals(k) = struct('label', leads{k}, 'unit', units{k}, 'rate', rate, ...
    'data', samples(:, k), 'physicalMin', physicalMin(k), ...
    'physicalMax', physicalMax(k));
  end
end
%=============================================================================
function annotations = edfNeutralAnnotations(recording, rate)
  % Module annotations to the neutral list: onset is (sample - 1) / rate, text
  % is the symbol or the aux text when the symbol is the note symbol.
  annotations = struct('onset', {}, 'duration', {}, 'text', {});
  a = edfAnnotationsOf(recording);
  for k = 1:numel(a.sample)
    if a.symbol(k) == '"'
      text = a.aux{k};
    else
      text = a.symbol(k);
    end
    annotations(end + 1) = struct('onset', (a.sample(k) - 1) / rate, ...
    'duration', 0, 'text', char(text)); %#ok<AGROW>
  end
end
%=============================================================================
function a = edfAnnotationsOf(recording)
  if isfield(recording, 'annotations') && ...
    isfield(recording.annotations, 'sample')
    a = recording.annotations;
    if ~isfield(a, 'symbol') || numel(a.symbol) ~= numel(a.sample)
      a.symbol = repmat('N', numel(a.sample), 1);
    end
    if ~isfield(a, 'aux') || numel(a.aux) ~= numel(a.sample)
      a.aux = repmat({''}, numel(a.sample), 1);
    end
  else
    a = struct('sample', [], 'symbol', '', 'aux', {{}});
  end
end
%=============================================================================
function leads = edfLeadNames(recording, leadCount)
  if isfield(recording, 'leads') && numel(recording.leads) == leadCount
    leads = recording.leads;
  else
    leads = cell(1, leadCount);
    for k = 1:leadCount
      leads{k} = sprintf('lead%d', k);
    end
  end
end
%=============================================================================
function units = edfLeadUnits(recording, leadCount)
  if isfield(recording, 'units') && numel(recording.units) == leadCount
    units = recording.units;
  else
    units = repmat({'mV'}, 1, leadCount);
  end
end
%=============================================================================
function [patient, recid, startdate, starttime] = edfHeaderFields(recording)
  % The header fields from the recording's info: the anonymous patient for an
  % empty subject, the EDF+ recording id, and the date and time fields.
  info = edfInfoOf(recording);
  patient = 'X X X X';
  if isfield(info, 'subject')
    subject = char(info.subject);
    if ~isempty(subject) && ~strcmp(subject, 'anonymous')
      patient = subject;
    end
  end
  startdate = '01.01.85';
  monthYear = 'X';
  if isfield(info, 'startDate') && ~isempty(info.startDate)
    parsed = edfParseDate(char(info.startDate));
    if ~isempty(parsed)
      startdate = parsed.edf;
      monthYear = parsed.recid;
    end
  end
  starttime = '00.00.00';
  if isfield(info, 'startTime') && edfTimeIsValid(char(info.startTime))
    if ~isfield(info, 'startTimeKnown') || info.startTimeKnown
      starttime = char(info.startTime);
    end
  end
  recid = ['Startdate ', monthYear];
end
%=============================================================================
function info = edfInfoOf(recording)
  if isfield(recording, 'info') && isstruct(recording.info)
    info = recording.info;
  else
    info = struct();
  end
end
%=============================================================================
function parsed = edfParseDate(text)
  % DD/MM/YYYY to the EDF dd.mm.yy field and to the dd-MON-yyyy the recording id
  % uses.
  parsed = [];
  pieces = strsplit(text, '/');
  if numel(pieces) ~= 3
    return;
  end
  day = str2double(pieces{1});
  month = str2double(pieces{2});
  year = str2double(pieces{3});
  if ~isfinite(day) || ~isfinite(month) || ~isfinite(year) || ...
    month < 1 || month > 12
    return;
  end
  months = {'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', ...
  'OCT', 'NOV', 'DEC'};
  parsed = struct();
  parsed.edf = sprintf('%02d.%02d.%02d', day, month, mod(year, 100));
  parsed.recid = sprintf('%02d-%s-%04d', day, months{month}, year);
end
%=============================================================================
function tf = edfTimeIsValid(text)
  tf = numel(text) == 8 && text(3) == '.' && text(6) == '.';
end
%=============================================================================
