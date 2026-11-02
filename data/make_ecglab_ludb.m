%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_LUDB() delineates every lead of every record of the Lobachevsky
% University Database, scores it against the manual marks, and writes
% data/ecglab_delineation_ludb.md, the twelve-lead companion to the QT table.
%
% The Lobachevsky database (Kalyakulina et al. 2020) is 200 ten-second
% twelve-lead records, annotated on all twelve leads, each lead in its own file
% (.i, .ii, ... .v6). Each lead is delineated against its own marks and the
% errors are pooled over every lead.
%
% MAKE_ECGLAB_LUDB(RECORDS) runs only the named records (char or cellstr).
function summary = make_ecglab_ludb(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  hasRecords = nargin >= 1 && ~isempty(records);
  if hasRecords
    requested = records;
  end
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/ludb/data'];
  outPath = [here, '/ecglab_delineation_ludb.md'];
  window = 0.15;
  %===========================================================================
  % The twelve leads, each with its annotation-file extension and header name, so
  % a lead is scored against its own marks.
  leadExt = {'.i', '.ii', '.iii', '.avr', '.avl', '.avf', '.v1', '.v2', ...
  '.v3', '.v4', '.v5', '.v6'};
  leadName = {'i', 'ii', 'iii', 'avr', 'avl', 'avf', 'v1', 'v2', 'v3', ...
  'v4', 'v5', 'v6'};
  if hasRecords
    records = requested;
    if ischar(records)
      records = {records};
    end
  else
    records = ecgLabLudbRecords(databaseDir);
  end
  %===========================================================================
  agr = {};
  skipped = 0;
  for ri = 1:numel(records)
    name = records{ri};
    base = [databaseDir, '/', name];
    if ~isfile([base, '.hea'])
      skipped = skipped + 1;
      continue;
    end
    for li = 1:numel(leadExt)
      annPath = [base, leadExt{li}];
      if ~isfile(annPath)
        continue;
      end
      try
        recording = ecglab.readwfdb(base, 'Annotations', leadExt{li});
        lead = find(strcmpi(recording.leads, leadName{li}), 1);
        if isempty(lead)
          lead = li;
        end
        waves = ecglab.delineate(recording, 'Lead', lead);
        agr{end + 1} = ecglab.validate(waves, recording, 'Kind', 'waves', ...
        'Window', window, 'Record', [name, '.', leadName{li}]);
      catch reason
        fprintf('Skipped %s %s: %s\n', name, leadName{li}, reason.message);
      end
    end
    fprintf('record %s done (%d lead agreements so far).\n', name, numel(agr));
  end
  if isempty(agr)
    error('ecglab:noLudbData', ...
    'No ludb lead was delineated; is the database on disk?');
  end
  %===========================================================================
  summary = ecglab.validate(agr);
  lines = ecgLabLudbHeader(records, agr, window);
  lines{end + 1} = '';
  lines{end + 1} = '## All twelve leads, every record';
  lines{end + 1} = '';
  lines{end + 1} = summary.markdown;
  fid = fopen(outPath, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotWriteS', 'Cannot write %s.', outPath);
  end
  for index = 1:numel(lines)
    fprintf(fid, '%s\n', lines{index});
  end
  fclose(fid);
  fprintf('Wrote %s (%d lead agreements over %d records).\n', outPath, ...
  numel(agr), numel(records) - skipped);
end
%=============================================================================
function records = ecgLabLudbRecords(databaseDir)
  % Record numbers 1..200 as strings, filtered to those on disk.
  records = {};
  for n = 1:200
    if isfile([databaseDir, '/', num2str(n), '.hea'])
      records{end + 1} = num2str(n);
    end
  end
end
%=============================================================================
function lines = ecgLabLudbHeader(records, agr, window)
  lines = {};
  lines{end + 1} = '# Wave delineation on the Lobachevsky University Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_ludb.m.'];
  lines{end + 1} = '';
  lines{end + 1} = ['- Database: Lobachevsky University Database (ludb), ', ...
  sprintf('%d record(s), twelve leads each, annotated on every lead.', ...
  numel(records))];
  lines{end + 1} = ['- Each lead is delineated and compared against that ', ...
  'lead''s own P, QRS and T marks; the errors are pooled over all twelve leads.'];
  lines{end + 1} = sprintf(['- Error convention: delineated minus manual, in ', ...
  'milliseconds; a negative mean is early. Matching window: %g ms.'], ...
  window * 1000);
  lines{end + 1} = sprintf('- Lead agreements pooled: %d.', numel(agr));
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
end
%=============================================================================
