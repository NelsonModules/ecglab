%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ecglab.report renders the study report from an analysis or a recording; every
% number comes from the analysis structs. Tested on a hand-built bundle.
rate = 360;
%=============================================================================
% A twelve-lead simulated recording, long enough for HRV and a rhythm window,
% so every section runs. Only that the report prints what the analysis measured.
rec = ecglab.simulate('Seconds', 40, 'Rate', rate, 'HeartRate', 72, ...
'Ectopic', 0.1, 'Leads', 12, 'Seed', 7);
beats = ecglab.detect(rec);
q = ecglab.quality(rec);
waves = ecglab.delineate(rec, 'Beats', beats);
classes = ecglab.classify(rec, 'Beats', beats);
rhy = ecglab.rhythm(rec, 'Beats', beats);
hrvResult = ecglab.hrv(rec, 'Beats', beats);
leadResult = ecglab.leads(rec, 'Beats', beats);
% The bundle has the shape ecglab.analyze returns: the recording and every
% sub-result under its own name.
bundle = struct('kind', 'ecglab.analysis', 'recording', rec, ...
'quality', q, 'beats', beats, 'waves', waves, 'classes', classes, ...
'rhythm', rhy, 'hrv', hrvResult, 'leads', leadResult);
%=============================================================================
% The analysis-input path, exercised on the hand-assembled bundle.
txt = ecglab.report(bundle);
assert_istrue(ischar(txt));
assert_istrue(~isempty(strfind(txt, char(10))));
%=============================================================================
% The first non-empty line is the research-only disclaimer.
lines = ecgLabReportSplitTest(txt);
first = '';
for k = 1:numel(lines)
  if ~isempty(strtrim(lines{k}))
    first = strtrim(lines{k});
    break;
  end
end
assert_istrue(~isempty(strfind(first, 'not a medical device')));
%=============================================================================
% The heart rate printed is the mean of the instantaneous rate over the beats.
inst = 60 ./ beats.rr(~isnan(beats.rr));
meanText = sprintf('%.0f', mean(inst));
assert_istrue(~isempty(strfind(txt, 'Heart rate')));
assert_istrue(~isempty(strfind(txt, [meanText, ' bpm'])));
%=============================================================================
% The intervals are printed beside their normal ranges, with the measured value.
prText = sprintf('%.0f', leadResult.intervals.pr);
assert_istrue(~isempty(strfind(txt, 'PR')));
assert_istrue(~isempty(strfind(txt, [prText, ' ms'])));
assert_istrue(~isempty(strfind(txt, '120 to 200 ms')));
assert_istrue(~isempty(strfind(txt, '< 120 ms')));
% The QTc upper limit (450 ms for the default male) is printed beside the QTc.
assert_istrue(~isempty(strfind(txt, '450 ms')));
% The four QTc formulas are all named.
assert_istrue(~isempty(strfind(txt, 'Bazett')));
assert_istrue(~isempty(strfind(txt, 'Fridericia')));
assert_istrue(~isempty(strfind(txt, 'Framingham')));
assert_istrue(~isempty(strfind(txt, 'Hodges')));
%=============================================================================
% Beats are counted by AAMI class, matching the classification.
total = numel(classes.label);
for c = 'NSVFQ'
  n = sum(classes.label == c);
  needle = sprintf('%s: %d ', c, n);
  assert_istrue(~isempty(strfind(txt, needle)));
end
assert_istrue(~isempty(strfind(txt, sprintf('%d beats', total))));
%=============================================================================
% The HRV summary prints the Task Force numbers the analysis measured.
assert_istrue(~isempty(strfind(txt, 'SDNN')));
assert_istrue(~isempty(strfind(txt, 'RMSSD')));
assert_istrue(~isempty(strfind(txt, 'pNN50')));
assert_istrue(~isempty(strfind(txt, 'LF/HF')));
%=============================================================================
% A measurement outside its range is flagged, not called a diagnosis. Set the
% PR outside 120 to 200 ms and check the mark.
outBundle = bundle;
outBundle.leads.intervals.pr = 260;
outBundle.leads.normal.pr.value = 260;
outBundle.leads.normal.pr.inRange = false;
outTxt = ecglab.report(outBundle);
assert_istrue(~isempty(strfind(outTxt, '[outside normal range]')));
% No clinical-verdict words appear, except inside the disclaimer's own text.
assert_istrue(isempty(strfind(outTxt, 'abnormal')));
withoutDisclaimer = strrep(outTxt, 'clinical diagnosis', '');
assert_istrue(isempty(strfind(withoutDisclaimer, 'diagnosis')));
%=============================================================================
% An empty field is printed as "not available", with no number invented. Drop
% the HRV result and check its section.
emptyBundle = bundle;
emptyBundle.hrv = [];
emptyTxt = ecglab.report(emptyBundle);
assert_istrue(~isempty(strfind(emptyTxt, 'not available')));
% The heart rate variability line carries no digit when it is not available.
eLines = ecgLabReportSplitTest(emptyTxt);
hrvLine = '';
for k = 1:numel(eLines)
  if ~isempty(strfind(eLines{k}, 'variability')) && ...
    ~isempty(strfind(eLines{k}, 'not available'))
    hrvLine = eLines{k};
    break;
  end
end
assert_istrue(~isempty(hrvLine));
assert_istrue(isempty(regexp(hrvLine, '[0-9]', 'once')));
%=============================================================================
% With no output argument the report prints; with one it returns the text and
% prints nothing.
printed = evalc('ecglab.report(bundle);');
assert_istrue(~isempty(strfind(printed, 'not a medical device')));
silent = evalc('captured = ecglab.report(bundle);');
assert_istrue(isempty(strtrim(silent)));
%=============================================================================
% The 'File' option writes the same text to a file as well.
outFile = [tempdir(), 'test_ecglab_report_out.txt'];
if isfile(outFile)
  ecgLabReportDeleteTest(outFile);
end
txtFile = ecglab.report(bundle, 'File', outFile);
assert_istrue(isfile(outFile));
onDisk = fileread(outFile);
% A text-mode write may add carriage returns on Windows; compare on the text.
assert_isequal(strrep(onDisk, char(13), ''), txtFile);
ecgLabReportDeleteTest(outFile);
%=============================================================================
% The 'Width' option sets the wrap column: no printed line is longer than it.
narrow = ecglab.report(bundle, 'Width', 60);
nLines = ecgLabReportSplitTest(narrow);
for k = 1:numel(nLines)
  assert_istrue(numel(nLines{k}) <= 60);
end
%=============================================================================
% The width guarantee holds down to the narrowest accepted widths: no line
% overruns, the fixed data lines folded like the prose.
for w = [40, 48, 56]
  tight = ecglab.report(bundle, 'Width', w);
  tLines = ecgLabReportSplitTest(tight);
  for k = 1:numel(tLines)
    assert_istrue(numel(tLines{k}) <= w);
  end
end
%=============================================================================
% The French report is French throughout: the out-of-range marker, the normal
% range and the axis unit all read in French.
frOut = ecglab.report(outBundle, 'Language', 'fr');
assert_istrue(~isempty(strfind(frOut, '[hors de la plage normale]')));
assert_istrue(isempty(strfind(frOut, '[outside normal range]')));
assert_istrue(~isempty(strfind(frOut, 'degres')));
assert_istrue(isempty(strfind(frOut, 'degrees')));
assert_istrue(~isempty(strfind(frOut, '120 a 200 ms')));
%=============================================================================
% The recording-input path: with no analysis, the report analyses first and
% prints the same shape, disclaimer first.
recTxt = ecglab.report(rec);
recLines = ecgLabReportSplitTest(recTxt);
recFirst = '';
for k = 1:numel(recLines)
  if ~isempty(strtrim(recLines{k}))
    recFirst = strtrim(recLines{k});
    break;
  end
end
assert_istrue(~isempty(strfind(recFirst, 'not a medical device')));
assert_istrue(~isempty(strfind(recTxt, 'Heart rate')));
%=============================================================================
% The errors: a bad input is refused, and an unknown option is refused.
ok = false;
try
  ecglab.report(42);
catch e
  ok = startsWith(e.identifier, 'ecglab:badInput');
end
assert_istrue(ok);
ok = false;
try
  ecglab.report(bundle, 'Nope', 1);
catch e
  ok = startsWith(e.identifier, 'ecglab:unknownOption');
end
assert_istrue(ok);
%=============================================================================
function lines = ecgLabReportSplitTest(text)
  % Split on newline without a toolbox, keeping empty lines.
  text = strrep(text, char(13), '');
  parts = strsplit(text, char(10), 'CollapseDelimiters', false);
  lines = parts;
end
%=============================================================================
function ecgLabReportDeleteTest(f)
  % Remove a scratch file the test wrote, quietly.
  try
    delete(f);
  catch
  end
end
%=============================================================================
