%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function writewfdb(varargin)
  % WRITEWFDB Write an ECG recording to disk in the WFDB format.
  %
  %   ECGLAB.WRITEWFDB(NAME, RECORDING) writes NAME.hea and NAME.dat (all leads
  %   interleaved in one signal file) and, when present, NAME.atr. ECGLAB.READWFDB
  %   reads it back to the step the chosen format quantises to.
  %
  %   ECGLAB.WRITEWFDB(NAME, RECORDING, NAME, VALUE, ...) takes options:
  %     'Format'       the signal format: 16 (the default), 61, 212, 24, 32,
  %                    80, 160, 310 or 311.
  %     'Gain'         adu per physical unit, a scalar for every lead or one
  %                    per lead; the default is the recording's own gain.
  %     'Baseline'     the stored value a zero physical sample maps to, a
  %                    scalar or one per lead; the default is the recording's.
  %     'Annotations'  'auto' (the default) writes NAME.atr when the recording
  %                    has annotations, an extension writes NAME.extension, and
  %                    false writes none.
  %
  %   The wfdb toolbox writes the format; this writer maps the recording onto
  %   its struct. A stored sample is round(physical * gain + baseline).
  %
  %   Example:
  %     recording = ecglab.readwfdb('100');
  %     ecglab.writewfdb('copy', recording, 'Format', 212);
  %
  %   See also ecglab.readwfdb, wfdb.write.
  narginchk(2, 10);
  name = varargin{1};
  recording = varargin{2};
  if ~ischar(name) && ~isStringScalar(name)
    error('ecglab:badNameRecordNameText', 'The record name must be text.');
  end
  name = char(name);
  if ~isstruct(recording) || ~isfield(recording, 'samples')
    error('ecglab:badRecordingSecondArgumentRecordingStruct', 'The second argument must be a recording struct.');
  end
  options = ecgLabOptions(struct('Format', 16, 'Gain', [], ...
  'Baseline', [], 'Annotations', 'auto'), varargin(3:end));
  ecgLabEnsureWfdb();
  format = round(options.Format);
  count = size(recording.samples, 2);
  gain = ecgLabWfdbPerLead(options.Gain, recording, 'gain', count);
  baseline = ecgLabWfdbPerLead(options.Baseline, recording, 'baseline', count);
  leads = ecgLabWfdbLeadLabels(recording, count);
  units = ecgLabWfdbUnitLabels(recording, count);
  r = struct();
  r.rate = recording.rate;
  r.name = ecgLabWfdbRecordName(recording);
  [r.startTime, r.startTimeKnown, r.startDate, r.comments] = ...
  ecgLabWfdbMetaFields(recording);
  signals = struct('data', {}, 'label', {}, 'unit', {}, 'gain', {}, ...
  'baseline', {}, 'spf', {}, 'format', {});
  for k = 1:count
    signals(k) = struct('data', recording.samples(:, k), 'label', leads{k}, ...
    'unit', units{k}, 'gain', gain(k), 'baseline', baseline(k), 'spf', 1, ...
    'format', format);
  end
  r.signals = signals;
  if isfield(recording, 'annotations')
    r.annotations = recording.annotations;
  end
  try
    wfdb.write(name, r, 'Physical', true, 'Format', format, ...
    'Annotations', options.Annotations);
  catch e
    if strncmp(e.identifier, 'wfdb:', 5)
      error('ecglab:badWriteWfdb', '%s', e.message);
    end
    rethrow(e);
  end
end
%=============================================================================
function value = ecgLabWfdbPerLead(given, recording, field, count)
  % A gain or baseline (the recording's own or the option) made one value per
  % lead. A scalar is spread to every lead; a wrong length is an error.
  if isempty(given)
    if isfield(recording, field) && numel(recording.(field)) == count
      value = recording.(field)(:)';
      return;
    end
    if strcmp(field, 'gain')
      value = 200 * ones(1, count);
    else
      value = zeros(1, count);
    end
    return;
  end
  given = double(given(:)');
  if isscalar(given)
    value = given * ones(1, count);
    return;
  end
  if numel(given) ~= count
    error('ecglab:badOptionSOneValuePer', 'The %s must be one value per lead (%d expected).', field, count);
  end
  value = given;
end
%=============================================================================
function leads = ecgLabWfdbLeadLabels(recording, count)
  leads = cell(1, count);
  for index = 1:count
    leads{index} = sprintf('lead%d', index);
  end
  if isfield(recording, 'leads') && numel(recording.leads) == count
    for index = 1:count
      nm = recording.leads{index};
      if ~isempty(nm)
        leads{index} = char(nm);
      end
    end
  end
end
%=============================================================================
function units = ecgLabWfdbUnitLabels(recording, count)
  units = repmat({'mV'}, 1, count);
  if isfield(recording, 'units') && numel(recording.units) == count
    for index = 1:count
      unit = recording.units{index};
      if isempty(unit)
        unit = 'mV';
      end
      units{index} = char(unit);
    end
  end
end
%=============================================================================
function name = ecgLabWfdbRecordName(recording)
  name = 'record';
  if isfield(recording, 'info') && isfield(recording.info, 'name') && ...
    ~isempty(recording.info.name)
    name = recording.info.name;
  end
end
%=============================================================================
function [startTime, startTimeKnown, startDate, comments] = ...
  ecgLabWfdbMetaFields(recording)
  startTime = '00.00.00';
  startTimeKnown = false;
  startDate = '';
  comments = {};
  if ~isfield(recording, 'info')
    return;
  end
  info = recording.info;
  if isfield(info, 'startTime')
    startTime = info.startTime;
  end
  if isfield(info, 'startTimeKnown')
    startTimeKnown = logical(info.startTimeKnown);
  end
  if isfield(info, 'startDate')
    startDate = info.startDate;
  end
  if isfield(info, 'comments')
    comments = info.comments;
  end
end
%=============================================================================
