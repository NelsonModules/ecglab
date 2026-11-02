%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = readwfdb(varargin)
  % READWFDB Read an ECG recording stored in the WFDB format.
  %
  %   RECORDING = ECGLAB.READWFDB(NAME) reads the header NAME.hea, the signal
  %   files it names, and (when NAME.atr is on disk) the annotations, and
  %   returns the module's recording struct.
  %
  %   RECORDING = ECGLAB.READWFDB(NAME, NAME, VALUE, ...) takes options:
  %     'Annotations'  'auto' (the default) reads NAME.atr when it exists; an
  %                    extension such as 'qrs' reads NAME.extension; a file
  %                    path reads that file; false reads none.
  %     'Leads'        names or indices of the leads to keep, in the order
  %                    asked; the default keeps every lead.
  %     'Physical'     true (the default) returns physical units, (stored
  %                    minus baseline) over gain; false returns the raw ADC
  %                    integers.
  %
  %   The wfdb toolbox reads the format; this reader maps its struct onto the
  %   ecglab recording, keeping gain and baseline per lead so ECGLAB.WRITEWFDB
  %   can write it back unchanged. A multi-frequency record is returned at the
  %   highest rate, slower leads held across the frame, with info.frameRate the
  %   base rate.
  %
  %   Example:
  %     recording = ecglab.readwfdb('100');
  %     beats = ecglab.detect(recording);
  %
  %   See also ecglab.writewfdb, ecglab.detect, wfdb.read.
  narginchk(1, 7);
  nargoutchk(0, 1);
  name = varargin{1};
  if ~ischar(name) && ~isStringScalar(name)
    error('ecglab:badNameRecordNameText', 'The record name must be text.');
  end
  name = char(name);
  options = ecgLabOptions(struct('Annotations', 'auto', 'Leads', [], ...
  'Physical', true), varargin(2:end));
  ecgLabEnsureWfdb();
  r = ecgLabWfdbReadNeutral(name, options);
  % Lead names follow the module's convention: the signal description trimmed,
  % and leadN for a signal that names none.
  nAll = numel(r.signals);
  leads = cell(1, nAll);
  for k = 1:nAll
    nm = strtrim(r.signals(k).description);
    if isempty(nm)
      nm = sprintf('lead%d', k);
    end
    leads{k} = nm;
  end
  m = wfdb.matrix(r);
  samples = m.samples;
  units = m.units;
  gain = m.gain;
  baseline = m.baseline;
  rate = m.rate;
  % Keep only the leads asked for, in the order asked.
  if ~isempty(options.Leads)
    keep = ecgLabWfdbChooseLeads(options.Leads, leads);
    samples = samples(:, keep);
    leads = leads(keep);
    units = units(keep);
    gain = gain(keep);
    baseline = baseline(keep);
  end
  header = [ecgLabWfdbBase(name), '.hea'];
  info = struct('name', r.name, 'source', header, 'format', 'wfdb', ...
  'startTime', r.startTime, 'startTimeKnown', r.startTimeKnown, ...
  'startDate', r.startDate, 'subject', '', 'comments', {r.comments}, ...
  'multiFrequency', r.multiFrequency, 'frameRate', r.rate);
  recording = ecgLabRecording(samples, rate, leads, units, info);
  recording.gain = gain;
  recording.baseline = baseline;
  a = r.annotations;
  recording.annotations = ecgLabAnnotations(a.sample, a.symbol, a.num, ...
  a.subtype, a.chan, a.aux, rate);
end
%=============================================================================
function r = ecgLabWfdbReadNeutral(name, options)
  % Re-raise a wfdb toolbox error as the module's own error.
  try
    r = wfdb.read(name, 'Physical', options.Physical, ...
    'Annotations', options.Annotations);
  catch e
    if strncmp(e.identifier, 'wfdb:', 5)
      error('ecglab:badWfdbRecord', '%s', e.message);
    end
    rethrow(e);
  end
end
%=============================================================================
function base = ecgLabWfdbBase(name)
  base = name;
  if numel(base) > 4 && strcmpi(base(end - 3:end), '.hea')
    base = base(1:end - 4);
  end
end
%=============================================================================
function keep = ecgLabWfdbChooseLeads(want, leads)
  % Names or indices to column positions in the order asked. An unknown name or
  % an out-of-range index is an error.
  if isnumeric(want)
    keep = round(want(:)');
    if any(keep < 1) || any(keep > numel(leads))
      error('ecglab:badLeadsLeadIndexOutsideRange', 'A lead index is outside the range 1 to %d.', numel(leads));
    end
    return;
  end
  if ischar(want) || isStringScalar(want)
    want = cellstr(want);
  end
  keep = zeros(1, numel(want));
  for index = 1:numel(want)
    match = find(strcmp(char(want{index}), leads), 1);
    if isempty(match)
      error('ecglab:badLeadsNoLeadNamedS', 'No lead is named %s.', char(want{index}));
    end
    keep(index) = match;
  end
end
%=============================================================================
