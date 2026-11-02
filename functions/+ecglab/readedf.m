%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = readedf(varargin)
  % RECORDING = ecglab.readedf(FILE) reads an EDF or EDF+ file and returns the
  % module's recording struct.
  %
  % RECORDING = ecglab.readedf(FILE, 'Leads', WHICH) selects the leads by label
  % (a char or a cellstr) or by index. By default every signal whose label names
  % an ECG lead is taken, or all signals when none does.
  %
  % RECORDING = ecglab.readedf(FILE, 'Annotations', false) skips the annotation
  % signal, which is otherwise read as the recording's annotations.
  %
  % The edf toolbox reads the binary format; this reader maps its struct onto
  % the ecglab recording. Signals are returned at the highest rate among the
  % selected leads, slower ones held sample by sample; info.rates keeps each
  % native rate and an EDF+D file is read as continuous with info.discontinuous.
  %
  % Example:
  %   recording = ecglab.readedf('record.edf');
  %   beats = ecglab.detect(recording);
  %
  % See also ecglab.writeedf, edf.read.
  narginchk(1, inf);
  nargoutchk(0, 1);
  filename = varargin{1};
  if ~ischar(filename) && ~isStringScalar(filename)
    error('ecglab:badNameFileNameText', 'The file name must be text.');
  end
  filename = char(filename);
  options = ecgLabOptions(struct('Leads', [], 'Annotations', true), ...
  varargin(2:end));
  if ~isfile(filename)
    error('ecglab:noFileFileSNotDisk', 'The file %s is not on disk.', filename);
  end
  ecgLabEnsureEdf();
  r = edfReadNeutral(filename, options.Annotations);
  labels = cell(1, numel(r.signals));
  dims = cell(1, numel(r.signals));
  for k = 1:numel(r.signals)
    labels{k} = r.signals(k).label;
    dims{k} = r.signals(k).unit;
  end
  candidates = 1:numel(r.signals);
  selected = edfSelectLeads(labels, candidates, options.Leads);
  [samples, rate, rates] = edfAssemble(r, selected);
  info = edfInfo(filename, r);
  info.rates = rates;
  recording = ecgLabRecording(samples, rate, labels(selected), dims(selected), info);
  % Annotations are read at the output rate, so a mark's sample indexes the
  % returned samples matrix.
  if options.Annotations && ~isempty(r.annotations)
    recording.annotations = edfAnnotations(r.annotations, rate);
  else
    recording.annotations = ecgLabAnnotations([], [], [], [], [], [], rate);
  end
end
%=============================================================================
function r = edfReadNeutral(filename, wantAnnotations)
  % Re-raise an edf toolbox error as the module's own error.
  try
    r = edf.read(filename, 'Annotations', logical(wantAnnotations));
  catch e
    if strncmp(e.identifier, 'edf:', 4)
      error('ecglab:notEdf', 'The file %s is not an EDF file.', filename);
    end
    rethrow(e);
  end
end
%=============================================================================
function selected = edfSelectLeads(labels, candidates, leads)
  % Default: every signal whose label names an ECG lead, or all signals when
  % none does.
  if isempty(leads)
    mask = false(1, numel(candidates));
    for k = 1:numel(candidates)
      mask(k) = edfLooksEcg(labels{candidates(k)});
    end
    if any(mask)
      selected = candidates(mask);
    else
      selected = candidates;
    end
    return;
  end
  if isnumeric(leads)
    index = round(leads(:)');
    if any(index < 1) || any(index > numel(candidates))
      error('ecglab:badLeadsLeadIndexOutsideRange2', 'A lead index is outside the range of the signals.');
    end
    selected = candidates(index);
    return;
  end
  if ischar(leads) || isStringScalar(leads)
    leads = {char(leads)};
  end
  if ~iscell(leads)
    error('ecglab:badLeadsLeadsLabelCellstrLabels', 'Leads must be a label, a cellstr of labels, or indices.');
  end
  selected = zeros(1, 0);
  for k = 1:numel(leads)
    want = char(leads{k});
    hit = [];
    for c = candidates
      if edfLabelMatches(labels{c}, want)
        hit = c;
        break;
      end
    end
    if isempty(hit)
      error('ecglab:badLeadsNoSignalLabelledS', 'No signal is labelled %s.', want);
    end
    selected(end + 1) = hit;
  end
end
%=============================================================================
function tf = edfLooksEcg(label)
  % True when the label mentions ECG or EKG, or a word of it is a standard lead
  % name (including MLII).
  upper = edfUpper(label);
  tf = ~isempty(strfind(upper, 'ECG')) || ~isempty(strfind(upper, 'EKG'));
  if tf
    return;
  end
  names = {'I', 'II', 'III', 'AVR', 'AVL', 'AVF', 'V1', 'V2', 'V3', 'V4', ...
  'V5', 'V6', 'MLII'};
  words = edfWords(upper);
  for k = 1:numel(words)
    if any(strcmp(words{k}, names))
      tf = true;
      return;
    end
  end
end
%=============================================================================
function tf = edfLabelMatches(label, want)
  % A lead matches when it equals the whole label or one of its words, case
  % insensitive, so 'II' finds 'ECG II'.
  label = edfUpper(strtrim(label));
  want = edfUpper(strtrim(want));
  tf = strcmp(label, want);
  if tf
    return;
  end
  words = edfWords(label);
  tf = any(strcmp(words, want));
end
%=============================================================================
function [samples, rate, rates] = edfAssemble(r, selected)
  % Selected leads at the highest rate among them, slower ones held sample by
  % sample within each record. Samples arrive in physical units, one per signal.
  counts = zeros(1, numel(r.signals));
  for k = 1:numel(r.signals)
    counts(k) = r.signals(k).samplesPerRecord;
  end
  duration = r.duration;
  nrec = r.records;
  rates = counts(selected) / duration;
  if isempty(selected) || nrec == 0
    samples = zeros(0, numel(selected));
    rate = max([rates, 1]);
    return;
  end
  top = max(counts(selected));
  rate = top / duration;
  out = nrec * top;
  samples = zeros(out, numel(selected));
  for k = 1:numel(selected)
    index = selected(k);
    series = r.signals(index).data(:);
    here = counts(index);
    if here == 0
      continue;
    end
    % Zero-order hold to the top rate: within a record, output position m takes
    % input sample floor(m * here / top), plus each record's block offset.
    within = floor((0:top - 1) * here / top);
    recordOffsets = (0:nrec - 1)' * here;
    pick = reshape((recordOffsets + within).', [], 1) + 1;
    pick = min(pick, numel(series));
    samples(:, k) = series(pick);
  end
end
%=============================================================================
function annotations = edfAnnotations(list, rate)
  % Neutral list to module annotations: sample from onset and rate; symbol is
  % the text, or the note symbol with text in aux; num is the duration.
  symbols = edfSymbols();
  count = numel(list);
  sample = zeros(count, 1);
  symbol = char(zeros(count, 1));
  num = zeros(count, 1);
  aux = cell(count, 1);
  for k = 1:count
    onset = list(k).onset;
    text = list(k).text;
    sample(k) = round(onset * rate) + 1;
    if numel(text) == 1 && any(text == symbols)
      symbol(k) = text;
      aux{k} = '';
    else
      symbol(k) = '"';
      aux{k} = text;
    end
    if isfield(list, 'duration') && isfinite(list(k).duration)
      num(k) = round(list(k).duration * rate);
    else
      num(k) = 0;
    end
  end
  annotations = ecgLabAnnotations(sample, symbol, num, [], [], aux, rate);
end
%=============================================================================
function info = edfInfo(filename, r)
  % Provenance for display. Patient 'X X X X' is the format's anonymous patient;
  % start date is DD/MM/YYYY.
  info = struct();
  info.source = filename;
  info.format = 'edf';
  info.subject = r.patient;
  if isempty(info.subject) || strcmp(info.subject, 'X X X X')
    info.subject = 'anonymous';
  end
  info.startTime = '00.00.00';
  info.startTimeKnown = false;
  if edfTimeIsValid(r.starttime)
    info.startTime = r.starttime;
    info.startTimeKnown = true;
  end
  info.startDate = edfDate(r.startDateTime);
  info.discontinuous = ~r.continuous;
  info.comments = {};
  if info.discontinuous
    info.comments = {['The file is EDF+D (discontinuous) and is read as ', ...
    'if continuous.']};
  end
end
%=============================================================================
function tf = edfTimeIsValid(text)
  tf = numel(text) == 8 && text(3) == '.' && text(6) == '.';
end
%=============================================================================
function out = edfDate(startDateTime)
  % 'YYYY-MM-DD hh:mm:ss' to 'DD/MM/YYYY', empty when there is no date.
  out = '';
  if numel(startDateTime) < 10 || startDateTime(5) ~= '-' || ...
    startDateTime(8) ~= '-'
    return;
  end
  year = startDateTime(1:4);
  month = startDateTime(6:7);
  day = startDateTime(9:10);
  out = [day, '/', month, '/', year];
end
%=============================================================================
function upper = edfUpper(text)
  upper = char(text);
  mask = upper >= 'a' & upper <= 'z';
  upper(mask) = upper(mask) - 32;
end
%=============================================================================
function words = edfWords(text)
  words = {};
  pieces = strsplit(text, {' ', char(9), '-', '_'});
  for k = 1:numel(pieces)
    if ~isempty(pieces{k})
      words{end + 1} = pieces{k};
    end
  end
end
%=============================================================================
function symbols = edfSymbols()
  % PhysioNet annotation mnemonics: a single text equal to one of these is kept
  % as a symbol, anything else becomes the note symbol with its text in aux.
  symbols = ['NLRBAaJSVrFejnE/fQ?', '+~|sT*D', '"', '=ptu^![]@x()'];
end
%=============================================================================
