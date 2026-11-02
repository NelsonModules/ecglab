%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [beats, note] = ecgLabAnalyzeBeats(recording, detector, lead)
  % Detect the beats once for the whole chain, returning a note when there are
  % none. A dead (flat) lead is caught before the detector runs, and any error
  % the detector raises is turned into a note instead of stopping the call.
  beats = [];
  note = '';
  signal = ecgLabAnalyzeLeadSignal(recording, lead);
  if ~ecgLabAnalyzeVaries(signal)
    note = ['The analysis lead carries no electrocardiogram ', ...
    '(it does not vary).'];
    return;
  end
  leadPair = ecgLabAnalyzeLeadPair(lead);
  try
    detected = ecglab.detect(recording, 'Method', detector, leadPair{:});
  catch err
    note = err.message;
    return;
  end
  if isempty(detected.sample)
    note = 'No beats were detected on the analysis lead.';
    return;
  end
  beats = detected;
end
%=============================================================================
function signal = ecgLabAnalyzeLeadSignal(recording, lead)
  % The column the detector will read, so the dead-lead test uses the same
  % signal. The default lead follows the detector's own priority order.
  column = ecgLabAnalyzeLeadColumn(recording, lead);
  signal = double(recording.samples(:, column));
end
%=============================================================================
function column = ecgLabAnalyzeLeadColumn(recording, lead)
  leads = recording.leads;
  if isempty(lead)
    preferred = {'MLII', 'II', 'I', 'V5'};
    for index = 1:numel(preferred)
      match = find(strcmpi(preferred{index}, leads), 1);
      if ~isempty(match)
        column = match;
        return;
      end
    end
    column = 1;
    return;
  end
  if ischar(lead) || isStringScalar(lead)
    match = find(strcmpi(char(lead), leads), 1);
    if isempty(match)
      error('ecglab:unknownLeadRecordingHasNoLead', 'The recording has no lead named %s.', char(lead));
    end
    column = match;
    return;
  end
  column = round(double(lead));
  if column < 1 || column > numel(leads)
    error('ecglab:unknownLeadLeadIndexDOutside', 'The lead index %d is outside the %d leads.', column, numel(leads));
  end
end
%=============================================================================
function tf = ecgLabAnalyzeVaries(signal)
  % True when the lead varies. Tests the peak-to-peak of the finite samples in
  % millivolts; a span below one microvolt is treated as a flat (dead) lead.
  finite = signal(isfinite(signal));
  if numel(finite) < 2
    tf = false;
    return;
  end
  tf = (max(finite) - min(finite)) > 1e-6;
end
%=============================================================================
function pair = ecgLabAnalyzeLeadPair(lead)
  % Build the 'Lead' option for the detector, left out when no lead is given.
  if isempty(lead)
    pair = {};
  else
    pair = {'Lead', lead};
  end
end
%=============================================================================
