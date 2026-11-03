%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% HANDLE = ECGLAB.CHART(X) draws the summary page of a recording.
% HANDLE = ECGLAB.CHART(X, 'Name', value, ...) sets the options.
%
%   X is an ecglab.recording (analysed with ecglab.analyze) or an
%   ecglab.analysis (drawn as it stands, nothing recomputed). HANDLE is the
%   figure.
%
%   One printable page on a light ground. A header names the subject, source,
%   start, length and detector, with tiles for heart rate, rhythm (with AF
%   burden), PR/QRS/QT and corrected QT, frontal axis (with a vector diagram
%   when the twelve leads ran) and signal quality, each with the AHA/ACC/HRS
%   normal range where one applies.
%
%   Then the lanes, all on one time axis: the rhythm strip (one lead on the
%   paper grid), the RR tachogram, the beats coloured by AAMI class (one row
%   per class), the rhythm episodes as a band, the heart rate, and below a
%   divider the detector's evidence (thresholded series and threshold). A margin
%   carries the class counts, the HRV summary and the Poincare plot.
%
%   Fills are image rasters and outlines single NaN-broken lines; the beats lane
%   is one image, so thousands of beats still draw fast. No control is drawn, so
%   the printed and screen pages are the same.
%
%   Each lane is an axes tagged 'ecglab.chart.<lane>' (strip, tachogram, beats,
%   episodes, rate, divider, evidence), sharing one time axis with tick labels
%   under the lowest lane only.
%
%   Options (name and value, matched without regard to case):
%     'Visible'      'on' (default) or 'off'.
%     'OutputImage'  a file the page is saved to (none by default).
%     'Title'        a heading of your own, replacing the first header line.
%     'Lead'         the lead the rhythm strip draws and the analyses read, a
%                    name or a column index; used only when X is a recording.
%     'Detector'     the QRS detector, passed to ecglab.analyze; used only
%                    when X is a recording (default 'pantompkins').
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 120, 'Ectopic', 0.1, 'Seed', 1);
%     ecglab.chart(recording, 'OutputImage', [tempdir(), '/summary.png']);
%
%   See also ecglab.analyze, ecglab.strip, ecglab.beat, ecglab.report.
function handle = chart(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Visible', 'on', 'OutputImage', '', 'Title', '', ...
  'Lead', [], 'Detector', 'pantompkins');
  options = ecgLabOptions(defaults, varargin);
  if ~any(strcmpi(options.Visible, {'on', 'off'}))
    error('ecglab:badVisible', 'The ''Visible'' option is ''on'' or ''off''.');
  end
  %===========================================================================
  % Analyse a recording here, or take an analysis as it stands. The page reads
  % everything from this struct and recomputes nothing.
  analysis = ecgLabChartResolve(X, options);
  colour = ecgLabDrawPalette('paper');
  plan = ecgLabChartPlan(analysis, options, colour);
  %===========================================================================
  % Fixed 1400 by 1100 page on a light ground; lanes and margin are placed as
  % fractions of it.
  % The page is always built on a hidden figure and revealed once at the end.
  % Cascaded so several pages open at once do not stack on the same spot.
  handle = figure('Name', 'Nelson ecglab', 'NumberTitle', 'off', ...
  'Color', colour.background, 'Visible', 'off', ...
  'MenuBar', 'none', 'ToolBar', 'none', 'SelectionHighlight', 'off', ...
  'Position', ecgLabFigurePosition(1400, 1100));
  %===========================================================================
  % Header and tiles, then the lanes (created, drawn, then their shared time
  % axis set last so a later child cannot move a limit), margin, footer.
  ecgLabChartHeader(handle, plan, colour);
  lanes = ecgLabChartLanes(handle, plan, colour);
  ecgLabChartDraw(lanes, plan, colour);
  ecgLabChartLanes(lanes, plan);
  ecgLabChartMargin(handle, plan, colour);
  ecgLabChartFooter(handle, plan, colour);
  %===========================================================================
  % The plan rides in UserData so a caller or test can read the counts and
  % headline numbers the page drew, without scraping text off the figure.
  set(handle, 'UserData', plan);
  if ~isempty(options.OutputImage)
    saveas(handle, options.OutputImage);
  end
  ecgLabFreezeView(handle);
  if strcmpi(options.Visible, 'on')
    set(handle, 'Visible', 'on');
  end
  drawnow();
end
%=============================================================================
function ecgLabChartFooter(handle, plan, colour)
  % Provenance and the research-only statement along the bottom.
  foot = axes('Parent', handle, 'Units', 'normalized', ...
  'Position', [0.035, 1 - 1086 / 1100, 0.94, 22 / 1100], 'Tag', ...
  'ecglab.chart.footer');
  set(foot, 'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off');
  text(foot, 0, 0.5, plan.footer, 'Color', colour.dim, 'FontSize', 7, ...
  'VerticalAlignment', 'middle');
end
%=============================================================================
