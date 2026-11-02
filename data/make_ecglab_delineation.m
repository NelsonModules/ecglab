%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_DELINEATION() delineates every record of the QT Database, scores
% it against the manual wave annotations, and writes the pooled table to
% data/ecglab_delineation_qtdb.md.
%
% MAKE_ECGLAB_DELINEATION(RECORDS) runs only the named records (char or cellstr).
%
% For each record the annotation lead is delineated and compared with the waves
% basis of ecglab.validate against annotator 1 (.q1c, every record) and, where
% present, annotator 2 (.q2c, eleven records), pooled separately. The signed
% error (delineated minus manual) is reported per fiducial in milliseconds.
%
% Records are read from prefdir()/ecglab_reference/qtdb; nothing is downloaded.
function [summary1, summary2] = make_ecglab_delineation(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  % run(loader.m) inside a function resets the argument state, so nargin reads as
  % zero afterwards even when RECORDS was supplied; capture the request before
  % loading the module.
  hasRecords = nargin >= 1 && ~isempty(records);
  if hasRecords
    requested = records;
  end
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/qtdb'];
  if hasRecords
    records = requested;
  else
    records = ecgLabMakeDelRecords(databaseDir);
  end
  if ischar(records)
    records = {records};
  end
  outPath = [here, '/ecglab_delineation_qtdb.md'];
  window = 0.15;
  %===========================================================================
  % One pass over the records. Each is read once with annotator 1, delineated and
  % compared; annotator 2 is compared against the same delineation where .q2c is
  % present. A record that fails to read or delineate is skipped.
  agr1 = {};
  agr2 = {};
  boundaryFraction = NaN;
  skipped = {};
  for index = 1:numel(records)
    name = records{index};
    base = [databaseDir, '/', name];
    if ~isfile([base, '.hea']) || ~isfile([base, '.q1c'])
      skipped{end + 1} = name;
      continue;
    end
    try
      rec = ecglab.readwfdb(base, 'Annotations', '.q1c');
      lead = ecgLabMakeDelLead(rec.annotations, numel(rec.leads));
      waves = ecglab.delineate(rec, 'Lead', lead);
      boundaryFraction = waves.settings.boundaryFraction;
      agr1{end + 1} = ecglab.validate(waves, rec, 'Kind', 'waves', ...
      'Window', window, 'Record', name);
      if isfile([base, '.q2c'])
        rec2 = ecglab.readwfdb(base, 'Annotations', '.q2c');
        agr2{end + 1} = ecglab.validate(waves, rec2, 'Kind', 'waves', ...
        'Window', window, 'Record', name);
      end
    catch reason
      skipped{end + 1} = name;
      fprintf('Skipped %s: %s\n', name, reason.message);
    end
  end
  %===========================================================================
  summary1 = [];
  summary2 = [];
  lines = ecgLabMakeDelHeader(records, agr1, agr2, window, boundaryFraction);
  if ~isempty(agr1)
    summary1 = ecglab.validate(agr1);
    lines{end + 1} = '';
    lines{end + 1} = '## Annotator 1 (.q1c), every record';
    lines{end + 1} = '';
    lines{end + 1} = summary1.markdown;
  end
  if ~isempty(agr2)
    summary2 = ecglab.validate(agr2);
    lines{end + 1} = '';
    lines{end + 1} = '## Annotator 2 (.q2c), the eleven doubly annotated records';
    lines{end + 1} = '';
    lines{end + 1} = summary2.markdown;
  end
  if ~isempty(skipped)
    lines{end + 1} = '';
    lines{end + 1} = ['_Skipped (no record or no q1c on disk, or a read ', ...
    'error): ', strjoin(skipped, ', '), '._'];
  end
  ecgLabMakeDelWrite(outPath, lines);
  fprintf('Wrote %s (%d records against annotator 1, %d against annotator 2).\n', ...
  outPath, numel(agr1), numel(agr2));
end
%=============================================================================
function records = ecgLabMakeDelRecords(databaseDir)
  recordsFile = [databaseDir, '/RECORDS'];
  if ~isfile(recordsFile)
    error('ecglab:noRecordsRecordListSNot', 'The record list %s is not on disk.', recordsFile);
  end
  text = fileread(recordsFile);
  parts = strsplit(strtrim(text), char(10));
  records = {};
  for index = 1:numel(parts)
    one = strtrim(parts{index});
    if ~isempty(one)
      records{end + 1} = one;
    end
  end
end
%=============================================================================
function lead = ecgLabMakeDelLead(annotations, leadCount)
  % The lead the manual marks were made on, from the channel the wave marks
  % carry (0-based in WFDB) plus one. On the QT Database this is lead 1; the rule
  % is written out so another channel would still be delineated correctly.
  lead = 1;
  if isempty(annotations) || ~isfield(annotations, 'symbol') || ...
    isempty(annotations.symbol)
    return;
  end
  symbol = reshape(char(annotations.symbol), [], 1);
  waveMark = ismember(symbol, '()pt') | ...
  ismember(symbol, 'NLRBAaJSVrFejnE/fQ?');
  if ~any(waveMark) || ~isfield(annotations, 'chan')
    return;
  end
  chan = double(annotations.chan(:));
  lead = mode(chan(waveMark)) + 1;
  if ~isfinite(lead) || lead < 1 || lead > leadCount
    lead = 1;
  end
end
%=============================================================================
function lines = ecgLabMakeDelHeader(records, agr1, agr2, window, fraction)
  lines = {};
  lines{end + 1} = '# Wave delineation on the QT Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_delineation.m.'];
  lines{end + 1} = '';
  lines{end + 1} = ['- Database: QT Database (qtdb), ', ...
  sprintf('%d record(s) requested, %d measured against annotator 1, %d against annotator 2.', ...
  numel(records), numel(agr1), numel(agr2))];
  lines{end + 1} = ['- Lead: the channel the manual marks were made on ', ...
  '(signal 0 on every QT Database record, so the first lead).'];
  if isfinite(fraction)
    lines{end + 1} = sprintf(['- Boundary setting: QRS onset and offset read ', ...
    'outward to %.3g of the slope maximum (Martinez et al. 2004).'], fraction);
  else
    lines{end + 1} = '- Boundary setting: the ecglab.delineate default.';
  end
  lines{end + 1} = sprintf('- Matching window: %g ms (QRS peak).', ...
  window * 1000);
  lines{end + 1} = ['- Error convention: delineated minus manual, in ', ...
  'milliseconds; a negative mean is early.'];
  lines{end + 1} = ['- CSE tolerance: the accepted standard deviation of a ', ...
  'program boundary (survey 5.3); the QT Database is two-lead Holter data, ', ...
  'so the SD exceeding it on P and QRS onset is expected (survey 5.6).'];
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
end
%=============================================================================
function ecgLabMakeDelWrite(outPath, lines)
  fid = fopen(outPath, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotWriteS', 'Cannot write %s.', outPath);
  end
  for index = 1:numel(lines)
    fprintf(fid, '%s\n', lines{index});
  end
  fclose(fid);
end
%=============================================================================
