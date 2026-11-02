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
% ecglab.reporthtml renders the study as a self-contained HTML page, embedding
% the three reading pages. Runs under the advanced CLI with figures invisible.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
root = fileparts(fileparts(nfilename('fullpath')));
% The base64 encoder is private; the test puts the private folder on the path.
addpath([root, '/functions/+ecglab/private']);
%=============================================================================
% The base64 encoder matches the RFC 4648 test vectors, so the embedded images
% are valid.
assert_isequal(ecgLabReportHtmlBase64(double('Man')), 'TWFu');
assert_isequal(ecgLabReportHtmlBase64(double('hi')), 'aGk=');
assert_isequal(ecgLabReportHtmlBase64(double('hello')), 'aGVsbG8=');
assert_isequal(ecgLabReportHtmlBase64(double('any carnal pleasure')), ...
'YW55IGNhcm5hbCBwbGVhc3VyZQ==');
assert_isequal(ecgLabReportHtmlBase64([]), '');
%=============================================================================
% A twelve-lead simulated recording, so every page draws.
rec = ecglab.simulate('Seconds', 20, 'Rate', 360, 'HeartRate', 72, ...
'Ectopic', 0.1, 'Leads', 12, 'Seed', 7);
html = ecglab.reporthtml(rec, 'Visible', 'off');
assert_istrue(ischar(html));
% It is a full HTML document.
assert_istrue(~isempty(strfind(html, '<!DOCTYPE html>')));
assert_istrue(~isempty(strfind(html, '</html>')));
assert_istrue(~isempty(strfind(html, '<title>')));
% The research-only disclaimer is present (banner and footer).
assert_istrue(~isempty(strfind(html, 'not a medical device')));
% The three pages are embedded as base64 images, SVG by default, so no side
% files are needed.
svgCount = numel(strfind(html, 'data:image/svg+xml;base64,'));
assert_istrue(svgCount == 3, 'the chart, strip and beat are embedded as SVG');
% The numbers are the text report's: a section it prints is present in the HTML.
assert_istrue(~isempty(strfind(html, 'HEART RATE VARIABILITY')));
%=============================================================================
% The Graphics option chooses the format: 'png' embeds raster, bad values fail.
pngHtml = ecglab.reporthtml(rec, 'Graphics', 'png', 'Visible', 'off');
assert_istrue(numel(strfind(pngHtml, 'data:image/png;base64,')) == 3, ...
'the png graphics embed raster images');
assert_istrue(isempty(strfind(pngHtml, 'data:image/svg+xml;base64,')));
badGraphics = false;
try
  ecglab.reporthtml(rec, 'Graphics', 'jpeg', 'Visible', 'off');
catch e
  badGraphics = startsWith(e.identifier, 'ecglab:badGraphics');
end
assert_istrue(badGraphics, 'an unknown graphics format is an error');
%=============================================================================
% The analysis-input path renders the same document; File writes it to disk.
analysis = ecglab.analyze(rec);
outFile = [tempdir(), 'test_ecglab_reporthtml_out.html'];
if isfile(outFile)
  delete(outFile);
end
htmlFromAnalysis = ecglab.reporthtml(analysis, 'File', outFile, 'Visible', 'off');
assert_istrue(isfile(outFile));
onDisk = fileread(outFile);
assert_isequal(strrep(onDisk, char(13), ''), htmlFromAnalysis);
delete(outFile);
%=============================================================================
% The French report is French: the disclaimer names the "dispositif medical".
frHtml = ecglab.reporthtml(rec, 'Language', 'fr', 'Visible', 'off');
assert_istrue(~isempty(strfind(frHtml, 'dispositif medical')));
assert_istrue(~isempty(strfind(frHtml, 'lang="fr"')));
%=============================================================================
% Errors: a call with no output and no File is refused, as are a bad input and
% an unknown option.
noDest = false;
try
  evalc('ecglab.reporthtml(rec);');
catch e
  noDest = startsWith(e.identifier, 'ecglab:needDestination');
end
assert_istrue(noDest, 'a call with no destination is refused');
badInput = false;
try
  ecglab.reporthtml(42, 'File', outFile);
catch e
  badInput = startsWith(e.identifier, 'ecglab:badInput');
end
assert_istrue(badInput);
badOption = false;
try
  ecglab.reporthtml(rec, 'Nope', 1);
catch e
  badOption = startsWith(e.identifier, 'ecglab:unknownOption');
end
assert_istrue(badOption);
%=============================================================================
