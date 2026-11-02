%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function result = reference(varargin)
  % REFERENCE Fetch a record of an open database and read it.
  %
  %   RECORDING = ECGLAB.REFERENCE(NAME) fetches the record NAME, written
  %   'database/record' (such as 'mitdb/100' or 'ptbdb/patient001/s0010_re'),
  %   from PhysioNet into a local folder and reads it with ECGLAB.READWFDB.
  %
  %   NAMES = ECGLAB.REFERENCE('list', 'Database', DB) returns the record
  %   names of a database.
  %
  %   Nothing is redistributed: files are fetched from PhysioNet on demand and
  %   cached under the reference folder ([prefdir(), '/ecglab_reference'] by
  %   default), one sub-folder per database.
  %
  %   Options:
  %     'Folder'      where the files are kept (default the reference folder).
  %     'Download'    true to fetch what is missing (default); false to use
  %                   only what is on disk, and an error says what is missing.
  %     'Annotations' the annotator loaded into RECORDING.annotations; the
  %                   database default ('atr', or 'q1c' for qtdb, or lead
  %                   'ii' for ludb, or none for the PTB databases) unless
  %                   given, and '' to load none.
  %     'Database'    the database for 'list'.
  %
  %   The recording carries RECORDING.info.source, RECORDING.info.database,
  %   RECORDING.info.record and RECORDING.files (the paths fetched). For the QT
  %   and Lobachevsky databases, RECORDING.reference holds one annotations
  %   struct per annotator on disk.
  %
  %   Example:
  %     recording = ecglab.reference('mitdb/100');
  %     beats = ecglab.detect(recording);
  %
  %   See also ecglab.readwfdb, ecglab.detect.
  narginchk(1, inf);
  nargoutchk(0, 1);
  name = varargin{1};
  if ~ischar(name) && ~isStringScalar(name)
    error('ecglab:badNameNameText', 'The name must be text.');
  end
  name = char(name);
  defaults = struct('Folder', [prefdir(), '/ecglab_reference'], ...
  'Download', true, 'Annotations', [], 'Database', 'mitdb');
  options = ecgLabOptions(defaults, varargin(2:end));
  folder = ecgLabReferenceClean(options.Folder);
  download = ecgLabReferenceFlag(options.Download);
  if strcmpi(name, 'list')
    result = ecgLabReferenceList(options.Database, folder, download);
    return;
  end
  % database/record. A name with no slash has no record and is refused with an
  % example.
  cut = strfind(name, '/');
  if isempty(cut)
    error('ecglab:badRecordName', 'A record is named database/record, such as mitdb/100.');
  end
  database = lower(name(1:cut(1) - 1));
  record = name(cut(1) + 1:end);
  meta = ecgLabReferenceMeta(database);
  % The noise records (bw, em, ma) of nstdb carry no annotator; clear the
  % annotators so the rest of the fetch ignores them.
  if strcmp(database, 'nstdb') && any(strcmp({'bw', 'em', 'ma'}, record))
    meta.annotators = {};
    meta.optional = {};
    meta.default = '';
  end
  % Resolve and check the annotator name before any download, so a bad name
  % fails early.
  annotator = ecgLabReferenceAnnotator(options.Annotations, meta);
  % Check the record against the database's known list (embedded, or the cached
  % RECORDS file); an unavailable list is read on trust.
  known = ecgLabReferenceKnown(meta, folder, download);
  if ~isempty(known) && ~any(strcmp(known, record))
    error('ecglab:unknownRecord', 'Unknown record %s in %s.', record, database);
  end
  result = ecgLabReferenceFetch(meta, record, annotator, folder, download);
end
%=============================================================================
function recording = ecgLabReferenceFetch(meta, record, annotator, folder, ...
  download)
  database = meta.name;
  % Lobachevsky keeps records in a data sub-folder; the local tree mirrors the
  % server path.
  relative = record;
  if ~isempty(meta.subdir)
    relative = [meta.subdir, '/', record];
  end
  localBase = [folder, '/', database, '/', relative];
  remoteBase = ['https://physionet.org/files/', database, '/', ...
  meta.version, '/', relative];
  % The header first: it names the signal files.
  headerLocal = [localBase, '.hea'];
  if ~ecgLabReferenceEnsure(headerLocal, [remoteBase, '.hea'], download, false)
    error('ecglab:missingFileFileSNotDisk', 'The file %s is not on disk and downloading was refused.', headerLocal);
  end
  files = {headerLocal};
  % The signal files the header names, each fetched once, under the header's
  % own folder (where the header names them relative to).
  recordFolderLocal = ecgLabReferenceParent(headerLocal);
  recordFolderRemote = ecgLabReferenceParent([remoteBase, '.hea']);
  signalFiles = ecgLabReferenceSignalFiles(headerLocal);
  for index = 1:numel(signalFiles)
    signalLocal = [recordFolderLocal, '/', signalFiles{index}];
    signalRemote = [recordFolderRemote, '/', signalFiles{index}];
    if ~ecgLabReferenceEnsure(signalLocal, signalRemote, download, false)
      error('ecglab:missingFileFileSNotDisk', 'The file %s is not on disk and downloading was refused.', signalLocal);
    end
    files{end + 1} = signalLocal;
  end
  % The annotation files, fetched and listed whatever annotator is loaded. An
  % optional file the server lacks (q2c, qrsc) is skipped.
  onDisk = {};
  for index = 1:numel(meta.annotators)
    extension = meta.annotators{index};
    optional = any(strcmp(meta.optional, extension));
    annLocal = [localBase, '.', extension];
    annRemote = [remoteBase, '.', extension];
    if ecgLabReferenceEnsure(annLocal, annRemote, download, optional)
      files{end + 1} = annLocal;
      onDisk{end + 1} = extension;
    end
  end
  % For the QT and Lobachevsky databases, read every annotator on disk into
  % RECORDING.reference under its own name.
  if meta.hasReference
    reference = struct();
    for index = 1:numel(onDisk)
      extension = onDisk{index};
      annotations = ecglab.readwfdb(headerLocal, 'Annotations', ...
      [localBase, '.', extension]);
      reference.(extension) = annotations.annotations;
    end
  end
  % The annotator to load. If its file is not on disk it is refused by name,
  % since an empty annotator would turn a validation into a silent pass.
  if isempty(annotator)
    % An empty annotator means load none, so tell the reader false rather than
    % let it default to 'auto' and load NAME.atr.
    recording = ecglab.readwfdb(headerLocal, 'Annotations', false);
  else
    annotatorFile = [localBase, '.', annotator];
    if ~isfile(annotatorFile)
      error('ecglab:missingAnnotator', 'The annotator %s does not exist for %s/%s.', annotator, database, record);
    end
    recording = ecglab.readwfdb(headerLocal, 'Annotations', annotatorFile);
  end
  recording.info.database = database;
  recording.info.record = record;
  recording.info.source = [database, ' ', record, ', PhysioNet, ', ...
  meta.licence];
  recording.files = files;
  if meta.hasReference
    recording.reference = reference;
  end
end
%=============================================================================
function names = ecgLabReferenceList(database, folder, download)
  meta = ecgLabReferenceMeta(lower(char(database)));
  names = ecgLabReferenceKnown(meta, folder, download);
  if isempty(names) && ~meta.embedded
    % The PTB lists live only on the server; with nothing cached or fetched
    % there is no list, which is an error rather than an empty answer.
    error('ecglab:missingFileFileSSRecords', 'The file %s/%s/RECORDS is not on disk and downloading was refused.', folder, meta.name);
  end
  names = names(:);
end
%=============================================================================
function known = ecgLabReferenceKnown(meta, folder, download)
  % The record names: the embedded list for fixed databases, or the cached
  % RECORDS file for the PTB databases (fetched once if missing and allowed).
  if meta.embedded
    known = ecgLabReferenceRecords(meta.name);
    return;
  end
  recordsLocal = [folder, '/', meta.name, '/RECORDS'];
  recordsRemote = ['https://physionet.org/files/', meta.name, '/', ...
  meta.version, '/RECORDS'];
  if ~ecgLabReferenceEnsure(recordsLocal, recordsRemote, download, false)
    known = {};
    return;
  end
  known = ecgLabReferenceLines(fileread(recordsLocal));
end
%=============================================================================
function present = ecgLabReferenceEnsure(localPath, remoteUrl, download, ...
  optional)
  % True when LOCALPATH is on disk, fetching it first when missing and allowed.
  % A missing optional file, or downloading refused, leaves PRESENT false.
  if isfile(localPath)
    present = true;
    return;
  end
  if ~download
    present = false;
    return;
  end
  present = ecgLabReferenceGet(remoteUrl, localPath, optional);
end
%=============================================================================
function meta = ecgLabReferenceMeta(database)
  % Database metadata: server version, data sub-folder, annotators and the
  % optional ones, default annotator, reference flag, licence, embedded flag.
  leads = {'i', 'ii', 'iii', 'avr', 'avl', 'avf', 'v1', 'v2', 'v3', 'v4', ...
  'v5', 'v6'};
  odc = 'Open Data Commons Attribution License v1.0';
  cc = 'Creative Commons Attribution 4.0';
  switch database
    case 'mitdb'
      meta = ecgLabReferenceEntry('mitdb', '1.0.0', '', {'atr'}, {}, ...
      'atr', false, odc, true);
    case 'qtdb'
      meta = ecgLabReferenceEntry('qtdb', '1.0.0', '', ...
      {'atr', 'man', 'q1c', 'q2c', 'pu', 'pu0', 'pu1'}, {'q2c'}, 'q1c', ...
      true, odc, true);
    case 'nsrdb'
      meta = ecgLabReferenceEntry('nsrdb', '1.0.0', '', {'atr'}, {}, ...
      'atr', false, odc, true);
    case 'afdb'
      meta = ecgLabReferenceEntry('afdb', '1.0.0', '', ...
      {'atr', 'qrs', 'qrsc'}, {'qrsc'}, 'atr', false, odc, true);
    case 'nstdb'
      meta = ecgLabReferenceEntry('nstdb', '1.0.0', '', {'atr'}, {}, ...
      'atr', false, odc, true);
    case 'ludb'
      meta = ecgLabReferenceEntry('ludb', '1.0.1', 'data', leads, {}, ...
      'ii', true, odc, true);
    case 'ptbdb'
      meta = ecgLabReferenceEntry('ptbdb', '1.0.0', '', {}, {}, '', ...
      false, odc, false);
    case 'ptb-xl'
      meta = ecgLabReferenceEntry('ptb-xl', '1.0.3', '', {}, {}, '', ...
      false, cc, false);
    otherwise
      error('ecglab:unknownDatabase', 'Unknown database: %s (mitdb, qtdb, nsrdb, afdb, nstdb, ludb, ptbdb, ptb-xl).', database);
  end
end
%=============================================================================
function meta = ecgLabReferenceEntry(name, version, subdir, annotators, ...
  optional, default, hasReference, licence, embedded)
  meta = struct('name', name, 'version', version, 'subdir', subdir, ...
  'annotators', {annotators}, 'optional', {optional}, 'default', default, ...
  'hasReference', hasReference, 'licence', licence, 'embedded', embedded);
end
%=============================================================================
function annotator = ecgLabReferenceAnnotator(requested, meta)
  % The annotator to load: the database default when not given, else one the
  % database carries or '' for none. Anything else is refused with the list.
  if isnumeric(requested) && isempty(requested)
    annotator = meta.default;
    return;
  end
  annotator = char(requested);
  if isempty(annotator)
    return;
  end
  if ~any(strcmp(meta.annotators, annotator))
    if isempty(meta.annotators)
      list = 'none';
    else
      list = strjoin(meta.annotators, ', ');
    end
    error('ecglab:unknownAnnotator', 'Unknown annotator %s for %s (%s).', annotator, meta.name, list);
  end
end
%=============================================================================
function files = ecgLabReferenceSignalFiles(headerPath)
  % The distinct signal files a header names, in order and deduplicated, since
  % one record may spread signals over several files or share one file.
  lines = ecgLabReferenceLines(fileread(headerPath));
  if isempty(lines)
    error('ecglab:badHeaderHeaderSEmpty', 'The header %s is empty.', headerPath);
  end
  first = ecgLabReferenceWords(lines{1});
  count = 0;
  if numel(first) >= 2
    count = round(str2double(first{2}));
  end
  files = {};
  read = 0;
  for index = 2:numel(lines)
    words = ecgLabReferenceWords(lines{index});
    if numel(words) < 2
      continue;
    end
    name = words{1};
    if ~any(strcmp(files, name))
      files{end + 1} = name;
    end
    read = read + 1;
    if count > 0 && read == count
      break;
    end
  end
end
%=============================================================================
function folder = ecgLabReferenceClean(folder)
  % Forward slashes, no trailing slash, so concatenated paths match exactly.
  folder = strrep(char(folder), char(92), '/');
  while ~isempty(folder) && folder(end) == '/'
    folder = folder(1:end - 1);
  end
end
%=============================================================================
function flag = ecgLabReferenceFlag(value)
  if ~islogical(value) && ~(isnumeric(value) && isscalar(value))
    error('ecglab:badDownload', 'Download is true or false.');
  end
  flag = logical(value);
end
%=============================================================================
function parent = ecgLabReferenceParent(path)
  path = strrep(path, char(92), '/');
  cut = strfind(path, '/');
  if isempty(cut)
    parent = '';
    return;
  end
  parent = path(1:cut(end) - 1);
end
%=============================================================================
function lines = ecgLabReferenceLines(text)
  % Non-empty lines with carriage returns stripped; lines beginning with a hash
  % are comments and dropped.
  lines = {};
  pieces = strsplit(strrep(text, char(13), ''), char(10));
  for index = 1:numel(pieces)
    piece = strtrim(pieces{index});
    if ~isempty(piece) && piece(1) ~= '#'
      lines{end + 1} = piece;
    end
  end
end
%=============================================================================
function words = ecgLabReferenceWords(line)
  words = {};
  pieces = strsplit(line, ' ');
  for index = 1:numel(pieces)
    piece = strtrim(pieces{index});
    if ~isempty(piece)
      words{end + 1} = piece;
    end
  end
end
%=============================================================================
