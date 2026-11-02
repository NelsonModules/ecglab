%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% <--ADV-CLI MODE-->
% ecglab.demo is the guided tour: one call runs the module end to end and
% narrates the result. The Draw path opens the reading pages, drawn headless;
% the headless path narrates and carries the research-only disclaimer.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
% The headless tour returns the analysis and, as a second output, the tour
% text. With no Record it simulates a twelve-lead record.
[analysis, text] = ecglab.demo('Seconds', 20, 'Seed', 7);
assert_istrue(isstruct(analysis));
assert_isequal(analysis.kind, 'ecglab.analysis');
assert_istrue(ischar(text));
assert_istrue(~isempty(strfind(text, char(10))));
%=============================================================================
% The first non-empty line is the research-only disclaimer.
lines = ecgLabDemoSplitTest(text);
first = '';
for k = 1:numel(lines)
  if ~isempty(strtrim(lines{k}))
    first = strtrim(lines{k});
    break;
  end
end
assert_istrue(~isempty(strfind(first, 'not a medical device')));
%=============================================================================
% The text carries both the tour header and the report sections.
assert_istrue(~isempty(strfind(text, 'guided tour')));
assert_istrue(~isempty(strfind(text, 'Heart rate')));
% A beat count is narrated, and it is the number the analysis found.
nBeats = numel(analysis.beats.sample);
assert_istrue(~isempty(strfind(text, sprintf('%d beats', nBeats))));
%=============================================================================
% With no output argument the tour prints; with an output argument it returns
% the analysis and prints nothing.
printed = evalc('ecglab.demo(''Seconds'', 20, ''Seed'', 7);');
assert_istrue(~isempty(strfind(printed, 'guided tour')));
assert_istrue(~isempty(strfind(printed, 'not a medical device')));
silent = evalc('captured = ecglab.demo(''Seconds'', 20, ''Seed'', 7);');
assert_istrue(isempty(strtrim(silent)));
%=============================================================================
% A recording passed as the Record is toured as it stands, not resimulated.
rec = ecglab.simulate('Seconds', 15, 'Rate', 360, 'Leads', 12, 'Seed', 3);
a2 = ecglab.demo('Record', rec);
assert_isequal(a2.kind, 'ecglab.analysis');
assert_isequal(a2.recording.seconds, rec.seconds);
%=============================================================================
% The Draw path opens and saves the three reading pages headless, into a
% directory the test owns.
outDir = tempdir();
strip = [outDir, 'ecglab_demo_strip.png'];
chart = [outDir, 'ecglab_demo_chart.png'];
beat = [outDir, 'ecglab_demo_beat.png'];
ecgLabDemoDeleteTest(strip);
ecgLabDemoDeleteTest(chart);
ecgLabDemoDeleteTest(beat);
a3 = ecglab.demo('Seconds', 15, 'Seed', 7, 'Draw', true, 'Visible', 'off', ...
'OutputDir', outDir);
assert_isequal(a3.kind, 'ecglab.analysis');
assert_istrue(isfile(strip));
assert_istrue(isfile(chart));
assert_istrue(isfile(beat));
ecgLabDemoDeleteTest(strip);
ecgLabDemoDeleteTest(chart);
ecgLabDemoDeleteTest(beat);
%=============================================================================
% The French tour reads in French: the disclaimer names the "dispositif
% medical" and the English one is absent.
[~, frText] = ecglab.demo('Seconds', 15, 'Seed', 7, 'Language', 'fr');
assert_istrue(~isempty(strfind(frText, 'dispositif medical')));
assert_istrue(isempty(strfind(frText, 'not a medical device')));
%=============================================================================
% Errors: an unknown option and a Record that is neither a recording nor a
% name are refused.
ok = false;
try
  ecglab.demo('Nope', 1);
catch e
  ok = startsWith(e.identifier, 'ecglab:unknownOption');
end
assert_istrue(ok);
ok = false;
try
  ecglab.demo('Record', 42);
catch e
  ok = startsWith(e.identifier, 'ecglab:badRecord');
end
assert_istrue(ok);
%=============================================================================
function lines = ecgLabDemoSplitTest(text)
  % Split on newline without a toolbox, keeping empty lines.
  text = strrep(text, char(13), '');
  lines = strsplit(text, char(10), 'CollapseDelimiters', false);
end
%=============================================================================
function ecgLabDemoDeleteTest(f)
  % Remove a scratch page the test wrote, quietly.
  try
    if isfile(f)
      delete(f);
    end
  catch
  end
end
%=============================================================================
