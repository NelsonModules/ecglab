%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_BEATS() runs every ecglab.detect detector on every record of the
% MIT-BIH Arrhythmia Database, validates each against the .atr annotations with
% the EC57 defaults (150 ms window, 300 s learning, bxb table), and writes the
% README tables to data/ecglab_beats_mitdb.md.
%
% MAKE_ECGLAB_BEATS(RECORDS) runs only the named records.
%
% Records are read from prefdir()/ecglab_reference/mitdb; nothing is downloaded.
function make_ecglab_beats(records)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/mitdb'];
  if nargin < 1 || isempty(records)
    records = ecgLabMakeRecords(databaseDir);
  end
  if ischar(records)
    records = {records};
  end
  outPath = [here, '/ecglab_beats_mitdb.md'];
  window = 0.15;
  learning = 300;
  % Check whether ecglab.detect exists in this tree before calling it.
  detectFile = [moduleRoot, '/functions/+ecglab/detect.m'];
  haveDetect = isfile(detectFile);
  methods = {'pantompkins', 'hamilton', 'christov', 'engzee', ...
  'wavelet', 'elgendi', 'wqrs', 'consensus'};
  lines = ecgLabMakeHeader(records, window, learning, haveDetect);
  if ~haveDetect
    lines{end + 1} = '';
    lines{end + 1} = ['**ecglab.detect is not present in this tree**, ', ...
    'so the detection run is pending. The reading of the database and ', ...
    'the comparator were exercised on record 100 by the test suite ', ...
    '(se = ppv = 1 on the shifted truth).'];
    ecgLabMakeWrite(outPath, lines);
    fprintf('Wrote %s (detection pending).\n', outPath);
    return;
  end
  %===========================================================================
  % Run every detector on each record while it is in memory, so the records are
  % read once, not once per method.
  byMethod = cell(1, numel(methods));
  for m = 1:numel(methods)
    byMethod{m} = {};
  end
  for r = 1:numel(records)
    name = records{r};
    recording = ecglab.readwfdb([databaseDir, '/', name]);
    reference = recording.annotations;
    for m = 1:numel(methods)
      try
        chrono = tic;
        beats = ecglab.detect(recording, 'Method', methods{m});
        elapsed = toc(chrono);
        agreement = ecglab.validate(beats, reference, 'Window', window, ...
        'Learning', learning, 'Table', 'bxb', 'Record', name);
        agreement.runtime = elapsed;
        byMethod{m}{end + 1} = agreement;
      catch reason
        fprintf('%s on %s: %s\n', methods{m}, name, reason.message);
      end
    end
  end
  %===========================================================================
  % One summary per method: the whole database, and the records without a paced
  % beat. The four paced records (102, 104, 107, 217) are excluded from the beat
  % statistics by the standard, as single-lead detectors fire on pacing spikes.
  summaries = cell(1, numel(methods));
  nonPaced = cell(1, numel(methods));
  for m = 1:numel(methods)
    if isempty(byMethod{m})
      continue;
    end
    summaries{m} = ecglab.validate(byMethod{m}, 'ExcludePaced', false);
    kept = {};
    for a = 1:numel(byMethod{m})
      if ~byMethod{m}{a}.paced
        kept{end + 1} = byMethod{m}{a};
      end
    end
    if ~isempty(kept)
      nonPaced{m} = ecglab.validate(kept, 'ExcludePaced', false);
    end
  end
  lines{end + 1} = '';
  lines{end + 1} = '## Summary';
  lines{end + 1} = '';
  lines{end + 1} = ['Gross sensitivity and positive predictivity over ', ...
  'every record, and over the records without a paced beat, with the mean ', ...
  'detection time on the thirty minute records.'];
  lines{end + 1} = '';
  lines{end + 1} = ['| Method | Se (all) | +P (all) | Se (no paced) | ', ...
  '+P (no paced) | Mean time (s) |'];
  lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
  for m = 1:numel(methods)
    if isempty(summaries{m})
      continue;
    end
    npSe = NaN; npPpv = NaN;
    if ~isempty(nonPaced{m})
      npSe = nonPaced{m}.gross.se;
      npPpv = nonPaced{m}.gross.ppv;
    end
    lines{end + 1} = sprintf('| %s | %.4f | %.4f | %.4f | %.4f | %.2f |', ...
    methods{m}, summaries{m}.gross.se, summaries{m}.gross.ppv, ...
    npSe, npPpv, mean(summaries{m}.table.runtime));
  end
  for m = 1:numel(methods)
    if isempty(summaries{m})
      continue;
    end
    lines{end + 1} = '';
    lines{end + 1} = ['## ', methods{m}];
    lines{end + 1} = '';
    lines{end + 1} = summaries{m}.markdown;
  end
  ecgLabMakeWrite(outPath, lines);
  fprintf('Wrote %s.\n', outPath);
end
%=============================================================================
function records = ecgLabMakeRecords(databaseDir)
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
function lines = ecgLabMakeHeader(records, window, learning, haveDetect)
  lines = {};
  lines{end + 1} = '# Beat detection on the MIT-BIH Arrhythmia Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_beats.m.'];
  lines{end + 1} = '';
  lines{end + 1} = ['- Database: MIT-BIH Arrhythmia Database (mitdb), ', ...
  sprintf('%d record(s).', numel(records))];
  lines{end + 1} = sprintf('- Matching window: %g ms.', window * 1000);
  lines{end + 1} = sprintf('- Learning period: %g s.', learning);
  lines{end + 1} = '- Class table: bxb. Reference: the .atr annotations.';
  lines{end + 1} = ['- Detection present: ', ...
  ecgLabMakeYesNo(haveDetect), '.'];
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
end
%=============================================================================
function text = ecgLabMakeYesNo(flag)
  if flag
    text = 'yes';
  else
    text = 'no';
  end
end
%=============================================================================
function ecgLabMakeWrite(outPath, lines)
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
