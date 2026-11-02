%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function text = ecgLabReportText(summary, language, width)
  % Format the summary into the report text. Formats only: an unavailable field
  % is printed "not available" with its reason, never a value.
  L = ecgLabReportLabels(language);
  lines = {};
  %===========================================================================
  % The disclaimer first, wrapped to the width.
  lines = ecgLabReportPush(lines, ecgLabReportWrap(L.disclaimer, width));
  lines = ecgLabReportPush(lines, {''});
  lines = ecgLabReportPush(lines, {L.title});
  %===========================================================================
  lines = ecgLabReportSection(lines, L.recording);
  header = summary.header;
  if header.available
    lines = ecgLabReportPush(lines, {ecgLabReportKV(L.subject, ...
    ecgLabReportOr(header.subject, L.unknown), width)});
    sourceText = ecgLabReportOr(header.source, L.unknown);
    if ~isempty(header.format)
      sourceText = sprintf('%s (%s %s)', sourceText, L.format, header.format);
    end
    lines = ecgLabReportPush(lines, {ecgLabReportKV(L.source, sourceText, ...
    width)});
    if header.startKnown
      lines = ecgLabReportPush(lines, {ecgLabReportKV(L.start, ...
      header.startText, width)});
    else
      lines = ecgLabReportPush(lines, {ecgLabReportKV(L.start, ...
      L.startUnknown, width)});
    end
    lines = ecgLabReportPush(lines, {ecgLabReportKV(L.length, ...
    sprintf('%.1f %s %s %g %s', header.seconds, L.seconds, L.at, ...
    header.rate, L.hz), width)});
    leadText = sprintf('%s: %s', L.leads, strjoin(header.leads, ', '));
    lines = ecgLabReportPush(lines, ...
    ecgLabReportIndentWrap(leadText, width));
  else
    lines = ecgLabReportPush(lines, {['  ', L.noRecording]});
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.quality);
  quality = summary.quality;
  if quality.available
    leadPart = '';
    if ~isempty(quality.lead)
      leadPart = sprintf(' %s %s', L.onLead, quality.lead);
    end
    lines = ecgLabReportPush(lines, {sprintf('  %s %.0f%% %s;%s', ...
    L.usable, 100 * quality.usableFraction, L.ofWindows, leadPart)});
    lines = ecgLabReportPush(lines, {sprintf('  %s %.1f %s', ...
    L.longestClean, quality.goodSeconds, L.seconds)});
    if quality.refused
      lines = ecgLabReportPush(lines, {['  ', L.leadRefused]});
    end
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable(quality.reason, width));
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.rateRhythm);
  hr = summary.heartRate;
  if hr.available
    lines = ecgLabReportPush(lines, {sprintf(...
    '  %s %.0f %s (%s %.0f %s %.0f %s), %d %s', L.heartRate, hr.mean, ...
    L.bpm, L.range, hr.low, L.to, hr.high, L.bpm, hr.beats, L.beats)});
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable([L.heartRate, ': ', hr.reason], width));
  end
  rhythm = summary.rhythm;
  if rhythm.available
    lines = ecgLabReportPush(lines, {sprintf('  %s %s; %s %.0f%% %s', ...
    L.dominantRhythm, ecgLabReportOr(rhythm.dominant, L.unknown), ...
    L.afBurden, 100 * rhythm.afBurden, L.ofAnalysed)});
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable([L.rhythm, ': ', rhythm.reason], width));
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.intervals);
  intervals = summary.intervals;
  if intervals.available
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.pr, ...
    intervals.pr, L, width));
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.qrs, ...
    intervals.qrs, L, width));
    lines = ecgLabReportPush(lines, {ecgLabReportIntervalPlain(L.qt, ...
    intervals.qt, L)});
    lines = ecgLabReportPush(lines, {sprintf('  %s < %g %s (%s)', L.qtcLimit, ...
    intervals.qtcLimit, L.ms, intervals.qtcSex)});
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.qtcBazett, ...
    intervals.qtc.bazett, L, width));
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.qtcFridericia, ...
    intervals.qtc.fridericia, L, width));
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.qtcFramingham, ...
    intervals.qtc.framingham, L, width));
    lines = ecgLabReportPush(lines, ecgLabReportInterval(L.qtcHodges, ...
    intervals.qtc.hodges, L, width));
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable(intervals.reason, width));
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.axis);
  axis = summary.axis;
  if axis.available
    main = sprintf('  %-14s %.0f %s (%s)', L.frontalAxis, axis.degrees, ...
    L.degrees, axis.label);
    lines = ecgLabReportPush(lines, ecgLabReportFlag(main, ~axis.inRange, ...
    L.outside, width));
    lines = ecgLabReportPush(lines, {sprintf('  %s %g %s %g %s', ...
    L.normalAxis, axis.low, L.to, axis.high, L.degrees)});
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable([L.frontalAxis, ': ', axis.reason], width));
  end
  %===========================================================================
  classes = summary.classes;
  if classes.available
    lines = ecgLabReportSection(lines, sprintf('%s (%d %s %s)', ...
    L.beatsByClass, classes.total, L.beats, L.total));
    order = classes.order;
    for index = 1:numel(order)
      lines = ecgLabReportPush(lines, {sprintf('  %s: %d (%.1f%%)', ...
      order(index), classes.counts(index), classes.shares(index))});
    end
  else
    lines = ecgLabReportSection(lines, L.beatsByClass);
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable(classes.reason, width));
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.hrv);
  hrv = summary.hrv;
  if hrv.available
    lines = ecgLabReportPush(lines, {sprintf('  %s %.1f %s', 'SDNN', ...
    hrv.sdnn, L.ms)});
    lines = ecgLabReportPush(lines, {sprintf('  %s %.1f %s', 'RMSSD', ...
    hrv.rmssd, L.ms)});
    lines = ecgLabReportPush(lines, {sprintf('  %s %.1f %%', 'pNN50', ...
    hrv.pnn50)});
    lines = ecgLabReportPush(lines, {sprintf('  %s %.2f', 'LF/HF', ...
    hrv.lfhf)});
  else
    lines = ecgLabReportPush(lines, ...
    ecgLabReportNotAvailable([L.hrvLine, ': ', hrv.reason], width));
  end
  %===========================================================================
  lines = ecgLabReportSection(lines, L.provenance);
  prov = summary.provenance;
  lines = ecgLabReportPush(lines, ecgLabReportIndentWrap(sprintf(...
  '%s %s; Nelson %s; ecglab %s', L.detector, ...
  ecgLabReportOr(prov.detector, L.unknown), prov.nelson, ...
  prov.moduleVersion), width));
  lines = ecgLabReportPush(lines, {''});
  lines = ecgLabReportPush(lines, ecgLabReportWrap(L.footer, width));
  %===========================================================================
  % Final guard: fold the fixed data lines that sprintf lays out at one shape,
  % so a narrow width is honoured too.
  lines = ecgLabReportFoldAll(lines, width);
  text = strjoin(ecgLabReportTrim(lines), char(10));
end
%=============================================================================
function lines = ecgLabReportFoldAll(lines, width)
  out = {};
  for index = 1:numel(lines)
    out = ecgLabReportPush(out, ecgLabReportFold(lines{index}, width));
  end
  lines = out;
end
%=============================================================================
function out = ecgLabReportFold(line, width)
  % Fold one line at word boundaries when it overruns the width, continuations
  % under a two-space hanging indent; a line that fits is returned unchanged.
  if numel(line) <= width
    out = {line};
    return;
  end
  firstNonSpace = find(line ~= ' ', 1);
  if isempty(firstNonSpace)
    out = {line};
    return;
  end
  indent = repmat(' ', 1, firstNonSpace - 1);
  cont = [indent, '  '];
  words = ecgLabReportFoldWords(line(firstNonSpace:end));
  out = {};
  current = [indent, words{1}];
  for index = 2:numel(words)
    candidate = [current, ' ', words{index}];
    if numel(candidate) <= width
      current = candidate;
    else
      out{end + 1} = current;
      current = [cont, words{index}];
    end
  end
  out{end + 1} = current;
end
%=============================================================================
function words = ecgLabReportFoldWords(text)
  % Split on runs of blanks, dropping empties from alignment padding.
  parts = strsplit(text, ' ');
  words = {};
  for index = 1:numel(parts)
    if ~isempty(parts{index})
      words{end + 1} = parts{index};
    end
  end
  if isempty(words)
    words = {''};
  end
end
%=============================================================================
function lines = ecgLabReportSection(lines, titleText)
  % A blank line then the uppercase section title.
  lines = ecgLabReportPush(lines, {''});
  lines = ecgLabReportPush(lines, {upper(titleText)});
end
%=============================================================================
function lines = ecgLabReportPush(lines, more)
  for index = 1:numel(more)
    lines{end + 1} = more{index};
  end
end
%=============================================================================
function line = ecgLabReportKV(key, value, width)
  % A key and a value on one line, kept whole. The width is accepted for a
  % uniform signature.
  line = sprintf('  %s: %s', key, value);
end
%=============================================================================
function out = ecgLabReportIndentWrap(text, width)
  % Wrap a long value under a two-space indent.
  wrapped = ecgLabReportWrap(text, width - 2);
  out = cell(1, numel(wrapped));
  for index = 1:numel(wrapped)
    out{index} = ['  ', wrapped{index}];
  end
end
%=============================================================================
function out = ecgLabReportInterval(label, item, L, width)
  % One interval: the value and its normal range, with the outside flag when
  % marked. A NaN value is printed "not available".
  if ~isfinite(item.value)
    out = {sprintf('  %-14s %s', label, 'not available')};
    return;
  end
  valueText = sprintf('%.0f %s', item.value, L.ms);
  main = sprintf('  %-14s %-8s %s', label, valueText, ...
  ecgLabReportRangeText(item, L));
  out = ecgLabReportFlag(main, ~item.inRange, L.outside, width);
end
%=============================================================================
function rangeText = ecgLabReportRangeText(item, L)
  % The normal range in the report language: "low to high" for a two-bound
  % range, "< high" for an upper limit.
  if strcmp(item.kind, 'between')
    rangeText = sprintf('%g %s %g %s', item.low, L.to, item.high, L.ms);
  else
    rangeText = sprintf('< %g %s', item.high, L.ms);
  end
end
%=============================================================================
function line = ecgLabReportIntervalPlain(label, value, L)
  if ~isfinite(value)
    line = sprintf('  %-14s %s', label, 'not available');
    return;
  end
  line = sprintf('  %-14s %.0f %s', label, value, L.ms);
end
%=============================================================================
function out = ecgLabReportFlag(main, flagged, marker, width)
  % Append the flag when it fits, else move it to its own indented line.
  if ~flagged
    out = {main};
    return;
  end
  candidate = [main, ' ', marker];
  if numel(candidate) <= width
    out = {candidate};
  else
    out = {main, ['      ', marker]};
  end
end
%=============================================================================
function out = ecgLabReportNotAvailable(reason, width)
  out = ecgLabReportIndentWrap(sprintf('not available: %s', reason), width);
end
%=============================================================================
function value = ecgLabReportOr(value, fallback)
  value = char(value);
  if isempty(strtrim(value))
    value = fallback;
  end
end
%=============================================================================
function lines = ecgLabReportTrim(lines)
  % Strip trailing blanks from every line and drop a leading blank line.
  for index = 1:numel(lines)
    lines{index} = deblank(lines{index});
  end
  while ~isempty(lines) && isempty(lines{1})
    lines(1) = [];
  end
end
%=============================================================================
function L = ecgLabReportLabels(language)
  % The labels in the report language. French is written without accents (ASCII).
  if strcmp(language, 'fr')
    L = ecgLabReportLabelsFr();
  else
    L = ecgLabReportLabelsEn();
  end
end
%=============================================================================
function L = ecgLabReportLabelsEn()
  L = struct();
  L.disclaimer = ['Research software, not a medical device. ecglab is for ', ...
  'research and education. It is not a medical device and must not be ', ...
  'used for clinical diagnosis, patient monitoring, treatment decisions, ', ...
  'or any medical purpose.'];
  L.footer = ['Research software, not a medical device: for research and ', ...
  'education only.'];
  L.title = 'ELECTROCARDIOGRAM STUDY REPORT';
  L.recording = 'Recording';
  L.subject = 'Subject';
  L.source = 'Source';
  L.format = 'format';
  L.start = 'Start';
  L.startUnknown = 'not recorded';
  L.length = 'Length';
  L.seconds = 's';
  L.at = 'at';
  L.hz = 'Hz';
  L.leads = 'Leads';
  L.unknown = 'unknown';
  L.noRecording = 'not available: the analysis carried no recording.';
  L.quality = 'Signal quality';
  L.usable = 'Usable';
  L.ofWindows = 'of windows';
  L.onLead = 'on lead';
  L.longestClean = 'Longest clean stretch';
  L.leadRefused = 'The lead was refused: no window reached the quality rule.';
  L.rateRhythm = 'Rate and rhythm';
  L.heartRate = 'Heart rate';
  L.bpm = 'bpm';
  L.range = 'range';
  L.to = 'to';
  L.beats = 'beats';
  L.dominantRhythm = 'Dominant rhythm';
  L.rhythm = 'Rhythm';
  L.afBurden = 'AF burden';
  L.ofAnalysed = 'of the analysed time';
  L.intervals = 'Intervals';
  L.pr = 'PR';
  L.qrs = 'QRS';
  L.qt = 'QT';
  L.qtcLimit = 'QTc upper limit';
  L.qtcBazett = 'QTc Bazett';
  L.qtcFridericia = 'QTc Fridericia';
  L.qtcFramingham = 'QTc Framingham';
  L.qtcHodges = 'QTc Hodges';
  L.axis = 'Frontal axis';
  L.frontalAxis = 'Axis';
  L.degrees = 'degrees';
  L.normalAxis = 'Normal range';
  L.outside = '[outside normal range]';
  L.beatsByClass = 'Beats by AAMI class';
  L.total = 'total';
  L.hrv = 'Heart rate variability';
  L.hrvLine = 'Heart rate variability';
  L.ms = 'ms';
  L.provenance = 'Provenance';
  L.detector = 'Detector';
end
%=============================================================================
function L = ecgLabReportLabelsFr()
  % French without accents (the module rule), so the report stays pure ASCII.
  L = ecgLabReportLabelsEn();
  L.disclaimer = ['Logiciel de recherche, pas un dispositif medical. ecglab ', ...
  'est destine a la recherche et a l''enseignement. Ce n''est pas un ', ...
  'dispositif medical et ne doit pas servir au diagnostic clinique, a la ', ...
  'surveillance des patients, aux decisions therapeutiques, ni a aucun ', ...
  'usage medical.'];
  L.footer = ['Logiciel de recherche, pas un dispositif medical : pour la ', ...
  'recherche et l''enseignement seulement.'];
  L.title = 'RAPPORT D''ETUDE ELECTROCARDIOGRAPHIQUE';
  L.recording = 'Enregistrement';
  L.subject = 'Sujet';
  L.source = 'Source';
  L.format = 'format';
  L.start = 'Debut';
  L.startUnknown = 'non enregistre';
  L.length = 'Duree';
  L.at = 'a';
  L.leads = 'Derivations';
  L.unknown = 'inconnu';
  L.noRecording = 'non disponible : l''analyse ne portait aucun enregistrement.';
  L.quality = 'Qualite du signal';
  L.usable = 'Utilisable';
  L.ofWindows = 'des fenetres';
  L.onLead = 'sur la derivation';
  L.longestClean = 'Plus longue plage propre';
  L.leadRefused = ['La derivation a ete refusee : aucune fenetre n''atteint ', ...
  'la regle de qualite.'];
  L.rateRhythm = 'Frequence et rythme';
  L.heartRate = 'Frequence cardiaque';
  L.range = 'intervalle';
  L.to = 'a';
  L.beats = 'battements';
  L.dominantRhythm = 'Rythme dominant';
  L.rhythm = 'Rythme';
  L.afBurden = 'Charge de FA';
  L.ofAnalysed = 'du temps analyse';
  L.intervals = 'Intervalles';
  L.qtcLimit = 'Limite superieure du QTc';
  L.axis = 'Axe frontal';
  L.frontalAxis = 'Axe';
  L.degrees = 'degres';
  L.normalAxis = 'Plage normale';
  L.outside = '[hors de la plage normale]';
  L.beatsByClass = 'Battements par classe AAMI';
  L.total = 'au total';
  L.hrv = 'Variabilite de la frequence cardiaque';
  L.hrvLine = 'Variabilite de la frequence cardiaque';
  L.provenance = 'Provenance';
  L.detector = 'Detecteur';
end
%=============================================================================
