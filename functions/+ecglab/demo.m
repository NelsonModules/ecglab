%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% ECGLAB.DEMO() runs the whole module end to end on a simulated recording and
% PRINTS the guided tour: a line for each stage of the analysis and then the
% study report.
% ANALYSIS = ECGLAB.DEMO(...) returns the analysis and prints nothing.
% [ANALYSIS, TEXT] = ECGLAB.DEMO(...) also returns the tour as text.
%
%   The tour runs the whole analysis chain with ecglab.analyze (clean, quality,
%   detect, delineate, classify, rhythm, hrv, twelve-lead leads), narrates what
%   each stage found, and prints the ecglab.report study report. With no Record
%   it simulates a twelve-lead recording, so the tour runs with no file and no
%   network.
%
%   The tour text opens with the research-only disclaimer. Every number it
%   narrates comes from ecglab.analyze; the tour recomputes nothing.
%
%   Options (name and value, matched without regard to case):
%     'Record'    a recording from a reader or ecglab.simulate, a file path, or
%                 a 'database/record' name for ecglab.reference; '' (default)
%                 simulates a recording.
%     'Seconds'   the length of the simulated recording, in seconds (default 30;
%                 used only when Record is '').
%     'Seed'      the seed of the simulated recording (default 7; used only when
%                 Record is ''), so a tour is reproducible.
%     'Detector'  the beat detector the analysis uses (default 'pantompkins').
%     'Draw'      draw and save the three reading pages (strip, chart, beat);
%                 false by default, so the tour is a headless call. Drawing needs
%                 an advanced-CLI session with a figure.
%     'OutputDir' the directory the pages are saved in when Draw is true
%                 (default the temporary directory).
%     'Visible'   'off' (default) or 'on' for the drawn pages.
%     'Language'  'en' (default) or 'fr' (French, without accents).
%
%   With no output argument the tour is printed; with one the analysis is
%   returned and nothing is printed.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     ecglab.demo();
%
%   See also ecglab.analyze, ecglab.report, ecglab.strip, ecglab.chart,
%   ecglab.beat, ecglab.simulate.
function varargout = demo(varargin)
  nargoutchk(0, 2);
  defaults = struct('Record', '', 'Seconds', 30, 'Seed', 7, ...
  'Detector', 'pantompkins', 'Draw', false, 'OutputDir', '', ...
  'Visible', 'off', 'Language', 'en');
  options = ecgLabOptions(defaults, varargin);
  language = ecgLabDemoLanguage(options.Language);
  %===========================================================================
  % The recording. With no Record one is simulated; a recording or a name is
  % passed straight to ecglab.analyze.
  recording = ecgLabDemoRecording(options);
  %===========================================================================
  % One call runs the whole analysis; the tour and report read this struct and
  % recompute nothing.
  analysis = ecglab.analyze(recording, 'Detector', options.Detector);
  %===========================================================================
  % The tour: the disclaimer, a line per stage, then the full study report.
  tour = ecgLabDemoNarrate(analysis, language);
  report = ecglab.report(analysis, 'Language', language);
  text = [tour, sprintf('\n'), report];
  %===========================================================================
  % The three reading pages, when asked. Drawn off-screen by default and saved;
  % the saved paths are named at the end of the tour.
  if ecgLabDemoDrawWanted(options.Draw)
    saved = ecgLabDemoDraw(analysis, options);
    text = [text, sprintf('\n'), ecgLabDemoSavedNote(saved, ...
    ecgLabDemoLabels(language))];
  end
  %===========================================================================
  % No output argument prints the tour; an output argument returns the analysis
  % (and the text when asked).
  if nargout == 0
    fprintf('%s\n', text);
  else
    varargout{1} = analysis;
    if nargout >= 2
      varargout{2} = text;
    end
  end
end
%=============================================================================
function language = ecgLabDemoLanguage(value)
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
  language = lower(char(value));
  if ~any(strcmp(language, {'en', 'fr'}))
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
end
%=============================================================================
function recording = ecgLabDemoRecording(options)
  % An empty Record means simulate one; a recording or a name is toured as is.
  % A twelve-lead simulation with some ectopy gives an axis and more than one
  % beat class, and a seed makes the run reproducible.
  record = options.Record;
  if isempty(record)
    seconds = ecgLabDemoSeconds(options.Seconds);
    seed = ecgLabDemoSeed(options.Seed);
    recording = ecglab.simulate('Seconds', seconds, 'Rate', 360, ...
    'HeartRate', 72, 'Ectopic', 0.08, 'Leads', 12, 'Seed', seed);
    return;
  end
  if isstruct(record) && isscalar(record) && isfield(record, 'kind') && ...
    strcmp(record.kind, 'ecglab.recording')
    recording = record;
    return;
  end
  if ischar(record) || isStringScalar(record)
    % A path or 'database/record' name: passed through unread; analyze
    % dispatches it.
    recording = char(record);
    return;
  end
  error('ecglab:badRecord', 'The Record must be a recording, a file path, or a ''database/record'' name.');
end
%=============================================================================
function seconds = ecgLabDemoSeconds(value)
  if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('ecglab:badSecondsSecondsPositiveNumber', 'The Seconds must be a positive number.');
  end
  seconds = double(value);
end
%=============================================================================
function seed = ecgLabDemoSeed(value)
  if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('ecglab:badSeedSeedNumber', 'The Seed must be a number.');
  end
  seed = double(value);
end
%=============================================================================
function wanted = ecgLabDemoDrawWanted(value)
  if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    error('ecglab:badDraw', 'The Draw must be true or false.');
  end
  wanted = logical(value);
end
%=============================================================================
function text = ecgLabDemoNarrate(analysis, language)
  % A line per stage, from the flat summary. A value the chain did not produce
  % is skipped, and a note names any analysis that could not run.
  s = analysis.summary;
  L = ecgLabDemoLabels(language);
  parts = {};
  parts{end + 1} = ecgLabDemoDisclaimer(language);
  parts{end + 1} = '';
  parts{end + 1} = L.title;
  parts{end + 1} = '';
  parts{end + 1} = ecgLabDemoRecordingLine(analysis.recording, L);
  parts{end + 1} = ecgLabDemoQualityLine(s.quality, L);
  parts{end + 1} = ecgLabDemoBeatsLine(analysis.beats, s.provenance, L);
  parts{end + 1} = ecgLabDemoIntervalLine(s.intervals, L);
  parts{end + 1} = ecgLabDemoClassLine(s.counts, L);
  parts{end + 1} = ecgLabDemoRhythmLine(s.rhythm, L);
  parts{end + 1} = ecgLabDemoHrvLine(s.hrv, L);
  axisLine = ecgLabDemoAxisLine(s.axis, L);
  if ~isempty(axisLine)
    parts{end + 1} = axisLine;
  end
  noteLines = ecgLabDemoNoteLines(analysis, L);
  for k = 1:numel(noteLines)
    parts{end + 1} = noteLines{k};
  end
  text = strjoin(parts, sprintf('\n'));
end
%=============================================================================
function line = ecgLabDemoRecordingLine(recording, L)
  name = '';
  source = '';
  if isfield(recording, 'info')
    if isfield(recording.info, 'name')
      name = recording.info.name;
    end
    if isfield(recording.info, 'source')
      source = recording.info.source;
    end
  end
  if isempty(name)
    name = L.unknown;
  end
  nLeads = numel(recording.leads);
  line = sprintf(L.recording, name, nLeads, recording.rate, ...
  recording.seconds, source);
end
%=============================================================================
function line = ecgLabDemoQualityLine(quality, L)
  if ~isfinite(quality.usableFraction)
    line = L.qualityNone;
    return;
  end
  line = sprintf(L.quality, 100 * quality.usableFraction);
end
%=============================================================================
function line = ecgLabDemoBeatsLine(beats, provenance, L)
  if isempty(beats)
    line = L.beatsNone;
    return;
  end
  line = sprintf(L.beats, numel(beats.sample), provenance.detector);
end
%=============================================================================
function line = ecgLabDemoIntervalLine(intervals, L)
  if ~isfinite(intervals.qrs) && ~isfinite(intervals.qt)
    line = L.intervalNone;
    return;
  end
  line = sprintf(L.interval, ecgLabDemoMs(intervals.pr), ...
  ecgLabDemoMs(intervals.qrs), ecgLabDemoMs(intervals.qt), ...
  ecgLabDemoMs(intervals.qtc.bazett));
end
%=============================================================================
function line = ecgLabDemoClassLine(counts, L)
  if ~isfinite(counts.N)
    line = L.classNone;
    return;
  end
  line = sprintf(L.class, counts.N, counts.S, counts.V, counts.F, counts.Q);
end
%=============================================================================
function line = ecgLabDemoRhythmLine(rhythm, L)
  label = rhythm.label;
  if isempty(label)
    line = L.rhythmNone;
    return;
  end
  burden = rhythm.afBurden;
  if isfinite(burden) && burden > 0.005
    line = sprintf(L.rhythmAf, label, 100 * burden);
  else
    line = sprintf(L.rhythm, label);
  end
end
%=============================================================================
function line = ecgLabDemoHrvLine(hrv, L)
  if ~isfinite(hrv.sdnn) && ~isfinite(hrv.rmssd)
    line = L.hrvNone;
    return;
  end
  line = sprintf(L.hrv, ecgLabDemoMs(hrv.sdnn), ecgLabDemoMs(hrv.rmssd), ...
  ecgLabDemoRatio(hrv.lfhf));
end
%=============================================================================
function line = ecgLabDemoAxisLine(axis, L)
  % The frontal axis exists only when the twelve-lead measurement ran; drop the
  % line otherwise.
  if isempty(axis)
    line = '';
    return;
  end
  line = sprintf(L.axis, round(axis.degrees), axis.label);
end
%=============================================================================
function lines = ecgLabDemoNoteLines(analysis, L)
  % The analyses that could not run, each with the reason analyze kept.
  lines = {};
  if ~isfield(analysis, 'notes') || isempty(analysis.notes)
    return;
  end
  notes = analysis.notes;
  names = fieldnames(notes);
  for k = 1:numel(names)
    reason = notes.(names{k});
    if ischar(reason) && ~isempty(reason)
      lines{end + 1} = sprintf(L.note, names{k}, reason);
    end
  end
end
%=============================================================================
function saved = ecgLabDemoDraw(analysis, options)
  % Draw the three reading pages and save them. The strip takes the recording,
  % the chart and beat take the analysis. Each figure is closed when off, so a
  % headless tour leaves files, not windows.
  outDir = options.OutputDir;
  if isempty(outDir)
    outDir = tempdir();
  end
  visible = options.Visible;
  strip = ecgLabDemoJoin(outDir, 'ecglab_demo_strip.png');
  chart = ecgLabDemoJoin(outDir, 'ecglab_demo_chart.png');
  beat = ecgLabDemoJoin(outDir, 'ecglab_demo_beat.png');
  hStrip = ecglab.strip(analysis.recording, 'Visible', visible, ...
  'OutputImage', strip);
  hChart = ecglab.chart(analysis, 'Visible', visible, 'OutputImage', chart);
  hBeat = ecglab.beat(analysis, 'Visible', visible, 'Interactive', false, ...
  'OutputImage', beat);
  if strcmpi(visible, 'off')
    ecgLabDemoClose(hStrip);
    ecgLabDemoClose(hChart);
    ecgLabDemoClose(hBeat);
  end
  saved = {strip, chart, beat};
end
%=============================================================================
function path = ecgLabDemoJoin(directory, name)
  % Join a directory and a file name with one separator, whatever the directory
  % ended with.
  if isempty(directory)
    path = name;
    return;
  end
  last = directory(end);
  if last == '/' || last == '\'
    path = [directory, name];
  else
    path = [directory, '/', name];
  end
end
%=============================================================================
function ecgLabDemoClose(h)
  try
    if ~isempty(h) && isgraphics(h)
      close(h);
    end
  catch
  end
end
%=============================================================================
function line = ecgLabDemoSavedNote(saved, L)
  line = sprintf(L.saved, saved{1}, saved{2}, saved{3});
end
%=============================================================================
function text = ecgLabDemoMs(value)
  if ~isfinite(value)
    text = '-';
    return;
  end
  text = sprintf('%.0f', value);
end
%=============================================================================
function text = ecgLabDemoRatio(value)
  if ~isfinite(value)
    text = '-';
    return;
  end
  text = sprintf('%.2f', value);
end
%=============================================================================
function disclaimer = ecgLabDemoDisclaimer(language)
  % The research-only sentence, the same one ecglab.report prints. French
  % without accents.
  if strcmp(language, 'fr')
    disclaimer = ['Logiciel de recherche, pas un dispositif medical. ecglab ', ...
    'est destine a la recherche et a l''enseignement. Ce n''est pas un ', ...
    'dispositif medical et il ne doit pas servir au diagnostic clinique, a ', ...
    'la surveillance des patients, aux decisions de traitement, ni a aucune ', ...
    'fin medicale.'];
  else
    disclaimer = ['Research software, not a medical device. ecglab is for ', ...
    'research and education. It is not a medical device and must not be used ', ...
    'for clinical diagnosis, patient monitoring, treatment decisions, or any ', ...
    'medical purpose.'];
  end
end
%=============================================================================
function L = ecgLabDemoLabels(language)
  % The one place the tour's sentences live, so English and French stay in step.
  if strcmp(language, 'fr')
    L = struct( ...
    'title', 'Visite guidee ecglab', ...
    'unknown', 'inconnu', ...
    'recording', 'Enregistrement : %s, %d derivations a %g Hz, %.0f s, source %s.', ...
    'quality', 'Qualite : lisible sur %.0f%% de l''enregistrement.', ...
    'qualityNone', 'Qualite : non mesuree.', ...
    'beats', 'Battements : %d detectes avec le detecteur %s.', ...
    'beatsNone', 'Battements : aucun detecte.', ...
    'interval', 'Intervalles : PR %s ms, QRS %s ms, QT %s ms (QTc Bazett %s ms).', ...
    'intervalNone', 'Intervalles : non mesures.', ...
    'class', 'Classes AAMI : N %d, S %d, V %d, F %d, Q %d.', ...
    'classNone', 'Classes : non mesurees.', ...
    'rhythm', 'Rythme : %s.', ...
    'rhythmAf', 'Rythme : %s, charge de fibrillation auriculaire %.0f%%.', ...
    'rhythmNone', 'Rythme : non mesure.', ...
    'hrv', 'Variabilite : SDNN %s ms, RMSSD %s ms, LF/HF %s.', ...
    'hrvNone', 'Variabilite : non mesuree.', ...
    'axis', 'Douze derivations : axe frontal %d degres (%s).', ...
    'note', 'Note (%s) : %s', ...
    'saved', 'Pages enregistrees : %s, %s, %s.');
  else
    L = struct( ...
    'title', 'ecglab guided tour', ...
    'unknown', 'unknown', ...
    'recording', 'Recording: %s, %d leads at %g Hz, %.0f s, from %s.', ...
    'quality', 'Quality: readable over %.0f%% of the record.', ...
    'qualityNone', 'Quality: not measured.', ...
    'beats', 'Beats: %d found with the %s detector.', ...
    'beatsNone', 'Beats: none found.', ...
    'interval', 'Intervals: PR %s ms, QRS %s ms, QT %s ms (QTc Bazett %s ms).', ...
    'intervalNone', 'Intervals: not measured.', ...
    'class', 'AAMI classes: N %d, S %d, V %d, F %d, Q %d.', ...
    'classNone', 'Classes: not measured.', ...
    'rhythm', 'Rhythm: %s.', ...
    'rhythmAf', 'Rhythm: %s, atrial fibrillation burden %.0f%%.', ...
    'rhythmNone', 'Rhythm: not measured.', ...
    'hrv', 'Variability: SDNN %s ms, RMSSD %s ms, LF/HF %s.', ...
    'hrvNone', 'Variability: not measured.', ...
    'axis', 'Twelve leads: frontal axis %d degrees (%s).', ...
    'note', 'Note (%s): %s', ...
    'saved', 'Pages saved: %s, %s, %s.');
  end
end
%=============================================================================
