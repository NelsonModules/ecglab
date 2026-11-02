%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% HTML = ECGLAB.REPORTHTML(X) renders the study report of X as a self-contained
% HTML page and returns it as text.
% ECGLAB.REPORTHTML(X, 'File', PATH) also writes it to PATH.
% ECGLAB.REPORTHTML(X, 'Name', value, ...) sets the language, the detector, the
% class prior, the lead and the beat shown.
%
%   X is an analysis from ecglab.analyze or an ecglab.recording (analysed
%   first). The self-contained HTML report bundles the research-only
%   disclaimer, the summary chart (ecglab.chart), the calibrated strip
%   (ecglab.strip), one beat (ecglab.beat) and the full text report
%   (ecglab.report), the pages embedded as base64 images.
%
%   The report is drawn, so it needs an advanced-CLI session with a figure. A
%   page that cannot be drawn is left out.
%
%   Options (name and value, matched without regard to case):
%     'File'     a path the HTML is written to (default '', none).
%     'Language' 'en' (default) or 'fr' (French, without accents).
%     'Detector' the QRS detector passed to ecglab.analyze (default
%                'pantompkins'), used only when X is a recording.
%     'Prior'    the classifier prior, 'empirical' (default) or 'uniform', used
%                only when X is a recording.
%     'Lead'     the lead the analysis reads, used only when X is a recording.
%     'Beat'     the beat the one-beat page opens on (default 1).
%     'Graphics' the embedded page format: 'svg' (default, vector) or 'png'
%                (a smaller raster).
%     'Visible'  'off' (default) or 'on' for the drawn pages.
%
%   With an output argument the HTML is returned; the 'File' option writes it.
%   A call with neither is refused.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 20, 'Rate', 360, 'Leads', 12);
%     ecglab.reporthtml(recording, 'File', [tempdir(), 'ecg.html']);
%
%   See also ecglab.report, ecglab.analyze, ecglab.chart, ecglab.strip,
%   ecglab.beat.
function varargout = reporthtml(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('File', '', 'Language', 'en', 'Detector', 'pantompkins', ...
  'Prior', 'empirical', 'Lead', [], 'Beat', 1, 'Graphics', 'svg', ...
  'Visible', 'off');
  options = ecgLabOptions(defaults, varargin);
  language = ecgLabReportHtmlLanguage(options.Language);
  graphics = ecgLabReportHtmlGraphics(options.Graphics);
  %===========================================================================
  % A destination is required: the report is drawn, so a call with none is
  % refused rather than drawing it and throwing it away.
  if nargout == 0 && isempty(options.File)
    error('ecglab:needDestination', 'Give a File to write the HTML report to, or capture the returned HTML.');
  end
  %===========================================================================
  % The input is a recording (analysed first) or an analysis (taken as is).
  if ~isstruct(X) || ~isscalar(X) || ~isfield(X, 'kind')
    error('ecglab:badInputInputEcglabRecordingEcglab', 'The input must be an ecglab recording or an ecglab analysis.');
  end
  switch X.kind
    case 'ecglab.recording'
      analysis = ecgLabReportHtmlAnalyze(X, options);
    case 'ecglab.analysis'
      analysis = X;
    otherwise
      error('ecglab:badInputInputEcglabRecordingEcglab', 'The input must be an ecglab recording or an ecglab analysis.');
  end
  %===========================================================================
  % The text report carries the numbers; the HTML wraps them and the pages.
  textReport = ecglab.report(analysis, 'Language', language);
  %===========================================================================
  % Draw each page, save it to a temporary image, read it back as a data URI,
  % and remove it. A page that cannot be drawn is left out.
  images = struct();
  chartPath = ecgLabReportHtmlTemp('chart', graphics);
  images.chart = ecgLabReportHtmlDraw(@() ecglab.chart(analysis, ...
  'Visible', options.Visible, 'OutputImage', chartPath), chartPath);
  stripPath = ecgLabReportHtmlTemp('strip', graphics);
  images.strip = ecgLabReportHtmlDraw(@() ecglab.strip(analysis.recording, ...
  'Visible', options.Visible, 'OutputImage', stripPath), stripPath);
  beatPath = ecgLabReportHtmlTemp('beat', graphics);
  images.beat = ecgLabReportHtmlDraw(@() ecglab.beat(analysis, ...
  'Beat', options.Beat, 'Interactive', false, 'Visible', options.Visible, ...
  'OutputImage', beatPath), beatPath);
  %===========================================================================
  html = ecgLabReportHtmlDoc(analysis, textReport, images, language);
  if ~isempty(options.File)
    ecgLabReportWrite(options.File, html);
  end
  if nargout >= 1
    varargout{1} = html;
  end
end
%=============================================================================
function analysis = ecgLabReportHtmlAnalyze(recording, options)
  % Analyse the recording with the chosen detector, prior and lead; the lead is
  % passed only when given.
  args = {'Detector', options.Detector, 'Prior', options.Prior};
  if ~isempty(options.Lead)
    args = [args, {'Lead', options.Lead}];
  end
  analysis = ecglab.analyze(recording, args{:});
end
%=============================================================================
function path = ecgLabReportHtmlTemp(page, graphics)
  % One temporary image path per page, with the chosen graphics format as the
  % extension.
  path = [tempdir(), 'ecglab_reporthtml_', page, '.', graphics];
end
%=============================================================================
function graphics = ecgLabReportHtmlGraphics(value)
  % The embedded graphics format: SVG by default (vector), or PNG for a smaller
  % file.
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badGraphics', 'The Graphics must be ''svg'' or ''png''.');
  end
  graphics = lower(char(value));
  if ~any(strcmp(graphics, {'svg', 'png'}))
    error('ecglab:badGraphics', 'The Graphics must be ''svg'' or ''png''.');
  end
end
%=============================================================================
function uri = ecgLabReportHtmlDraw(drawer, path)
  % Draw a page (the drawer saves it to path and returns its figure handle),
  % read the image into a data URI, close the figure and remove the file. A
  % draw failure leaves the page out (an empty URI) instead of aborting.
  uri = '';
  handle = [];
  try
    handle = drawer();
    uri = ecgLabReportHtmlImage(path);
  catch
    uri = '';
  end
  if ~isempty(handle)
    try
      close(handle);
    catch
    end
  end
  if isfile(path)
    try
      delete(path);
    catch
    end
  end
end
%=============================================================================
function language = ecgLabReportHtmlLanguage(value)
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
  language = lower(char(value));
  if ~any(strcmp(language, {'en', 'fr'}))
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
end
%=============================================================================
