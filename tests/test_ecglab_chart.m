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
%=============================================================================
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ecglab.chart draws the summary page of a recording: header tiles, the lanes
% on one shared time axis, the detector evidence, and a margin of counts, HRV
% and the Poincare plot. Every number comes from ecglab.analyze; the page
% recomputes nothing. Figures are drawn headless. The beats lane must be one
% image, never one patch per beat.
tmp = tempdir();
%=============================================================================
% The fixture: a fibrillation stretch joined to an ectopic stretch in one
% lead-II recording, so both an AFIB episode and a V class appear on the page.
% They are built apart because the simulator makes the whole record fibrillate
% or none of it.
fib = ecglab.simulate('Seconds', 60, 'Rate', 360, 'Fibrillation', true, ...
'HeartRate', 75, 'Seed', 1);
ect = ecglab.simulate('Seconds', 60, 'Rate', 360, 'Ectopic', 0.15, ...
'HeartRate', 75, 'HeartRateStd', 2, 'Seed', 2);
rec = fib;
rec.samples = [fib.samples; ect.samples];
rec.seconds = fib.seconds + ect.seconds;
rec.annotations = [];
%=============================================================================
% One analysis, shared by the self-consistency checks below.
analysis = ecglab.analyze(rec);
%=============================================================================
% The page draws from a recording and returns a figure handle.
h = ecglab.chart(rec, 'Visible', 'off');
assert_istrue(isgraphics(h, 'figure'));
%=============================================================================
% It draws from an analysis too, without analysing a second time.
h2 = ecglab.chart(analysis, 'Visible', 'off');
assert_istrue(isgraphics(h2, 'figure'));
close(h2);
%=============================================================================
% Every lane axis exists, found by its tag 'ecglab.chart.<lane>'.
laneNames = {'strip', 'tachogram', 'beats', 'episodes', 'rate', ...
'divider', 'evidence'};
for k = 1:numel(laneNames)
  ax = findobj(h, 'Tag', ['ecglab.chart.', laneNames{k}]);
  assert_isequal(numel(ax), 1, ['missing lane axis for ', laneNames{k}]);
end
%=============================================================================
% Anti-quadratic guard: the beats lane holds one image (the class raster), and
% the whole page holds only a few patch objects, never one per beat.
beatsAx = findobj(h, 'Tag', 'ecglab.chart.beats');
beatImages = findobj(beatsAx, 'Type', 'image');
fprintf('beats lane holds %d image object(s)\n', numel(beatImages));
assert_istrue(numel(beatImages) >= 1);
patches = findobj(h, 'Type', 'patch');
fprintf('whole page holds %d patch object(s) for %d beats\n', ...
numel(patches), numel(analysis.beats.sample));
assert_istrue(numel(patches) < 60);
close(h);
%=============================================================================
% The headline numbers on the page match the analysis. They are read from the
% figure UserData, exactly what the tiles drew.
h = ecglab.chart(analysis, 'Visible', 'off');
data = get(h, 'UserData');
counts = analysis.summary.counts;
assert_isequal(data.counts.N, counts.N);
assert_isequal(data.counts.S, counts.S);
assert_isequal(data.counts.V, counts.V);
assert_isequal(data.counts.F, counts.F);
assert_isequal(data.counts.Q, counts.Q);
assert_isequal(data.headline.heartRate, analysis.summary.heartRate.mean);
assert_isequal(data.headline.afBurden, analysis.summary.rhythm.afBurden);
assert_isequal(data.headline.pr, analysis.summary.intervals.pr);
assert_isequal(data.headline.qrs, analysis.summary.intervals.qrs);
assert_isequal(data.headline.qt, analysis.summary.intervals.qt);
fprintf('mean heart rate on page %.1f bpm, AF burden %.2f\n', ...
data.headline.heartRate, data.headline.afBurden);
%=============================================================================
% The analysis carries at least one AFIB episode and at least one V beat, so
% both lanes have something to draw.
afib = sum(strcmp(analysis.rhythm.episodes.label, 'AFIB'));
fprintf('analysis carries %d AFIB episode(s), %d V beats\n', afib, counts.V);
assert_istrue(afib >= 1);
assert_istrue(counts.V >= 1);
close(h);
%=============================================================================
% Saving to PNG produces the page with no control on it: the chart creates no
% uicontrol.
pngFile = [tmp, '/test_ecglab_chart.png'];
if isfile(pngFile)
  delete(pngFile);
end
h = ecglab.chart(analysis, 'Visible', 'off', 'OutputImage', pngFile);
controls = findobj(h, 'Type', 'uicontrol');
assert_isequal(numel(controls), 0);
close(h);
assert_istrue(isfile(pngFile));
%=============================================================================
% A twelve-lead record exercises the frontal-axis tile and vector diagram,
% drawn only when ecglab.leads ran.
rec12 = ecglab.simulate('Seconds', 20, 'Rate', 500, 'Leads', 12, 'Seed', 3);
a12 = ecglab.analyze(rec12);
h = ecglab.chart(a12, 'Visible', 'off');
assert_istrue(isgraphics(h, 'figure'));
assert_istrue(~isempty(a12.leads));
close(h);
%=============================================================================
% The draw is fast even for a few thousand beats. The analysis is done first
% and is not timed; only the draw is.
big = ecglab.simulate('Seconds', 900, 'Rate', 250, 'HeartRate', 150, ...
'Ectopic', 0.05, 'Seed', 4);
bigAnalysis = ecglab.analyze(big);
nBeats = numel(bigAnalysis.beats.sample);
tic;
h = ecglab.chart(bigAnalysis, 'Visible', 'off');
elapsed = toc;
close(h);
fprintf('drew a page of %d beats in %.3f s\n', nBeats, elapsed);
assert_istrue(nBeats >= 1500);
assert_istrue(elapsed < 6);
%=============================================================================
% Errors: a bad input, a bad Visible, and an unknown option are each refused
% with their own identifier.
assert_istrue(startsWith(localChartError(@() ecglab.chart(42)), 'ecglab:badInput'));
assert_istrue(startsWith(localChartError(@() ecglab.chart(analysis, 'Visible', 'x')), 'ecglab:badVisible'));
assert_istrue(startsWith(localChartError(@() ecglab.chart(analysis, 'Nope', 1)), 'ecglab:unknownOption'));
%=============================================================================
function id = localChartError(thunk)
  % The identifier of the error a call raises, or empty when it raises none.
  id = '';
  try
    thunk();
  catch e
    id = e.identifier;
  end
end
%=============================================================================
