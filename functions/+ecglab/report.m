%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% TEXT = ECGLAB.REPORT(X) renders the study report of X as plain text.
% TEXT = ECGLAB.REPORT(X, 'Name', value, ...) sets the language, the wrap and
% an output file.
% ECGLAB.REPORT(X) with no output argument PRINTS the report instead.
%
%   X is an analysis from ecglab.analyze or an ecglab.recording (analysed
%   first). No number is computed here: every value is read from the analysis,
%   and an empty field is printed as "not available" with a reason.
%
%   The report is plain text in sections, opening with the research-only
%   disclaimer. Every interval is printed beside its AHA/ACC/HRS normal range
%   with a mark when outside it; the mark is a flag, never a diagnosis.
%
%   The sections, in order: the subject, source and start; the length, rate
%   and leads; the signal quality; the heart rate and rhythm; the PR, QRS, QT
%   and corrected QT intervals beside their normal ranges; the frontal axis;
%   the beats by AAMI class N S V F Q; the heart rate variability summary; and
%   a provenance footer naming the detector, the Nelson build and the version.
%
%   Options (name and value, matched without regard to case):
%     'File'     a path the text is also written to (default '', none).
%     'Language' 'en' (default) or 'fr' (French, without accents).
%     'Width'    the wrap column in characters (default 78).
%
%   With no output argument the report is printed; with an output argument the
%   text (a char array with newlines) is returned and nothing is printed.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 30, 'Rate', 500, 'Leads', 12);
%     ecglab.report(recording);
%
%   See also ecglab.analyze, ecglab.leads, ecglab.hrv, ecglab.rhythm.
function varargout = report(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('File', '', 'Language', 'en', 'Width', 78);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % Validate the language and wrap width before rendering.
  language = ecgLabReportLanguage(options.Language);
  width = ecgLabReportWidth(options.Width);
  %===========================================================================
  % Input is an analysis or a recording. A recording is analysed first; anything
  % else is refused.
  if ~isstruct(X) || ~isscalar(X) || ~isfield(X, 'kind')
    error('ecglab:badInputInputEcglabRecordingEcglab', 'The input must be an ecglab recording or an ecglab analysis.');
  end
  switch X.kind
    case 'ecglab.recording'
      analysis = ecgLabReportAnalyze(X);
    case 'ecglab.analysis'
      analysis = X;
    otherwise
      error('ecglab:badInputInputEcglabRecordingEcglab', 'The input must be an ecglab recording or an ecglab analysis.');
  end
  %===========================================================================
  % The summary reads the numbers out of the analysis; the renderer below only
  % formats them.
  summary = ecgLabReportSummary(analysis);
  text = ecgLabReportText(summary, language, width);
  %===========================================================================
  % Write the file when asked, before returning, so a caller gets both.
  if ~isempty(options.File)
    ecgLabReportWrite(options.File, text);
  end
  %===========================================================================
  % No output argument prints; an output argument returns the text.
  if nargout == 0
    fprintf('%s\n', text);
  else
    varargout{1} = text;
  end
end
%=============================================================================
function language = ecgLabReportLanguage(value)
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
  language = lower(char(value));
  if ~any(strcmp(language, {'en', 'fr'}))
    error('ecglab:badLanguage', 'The Language must be ''en'' or ''fr''.');
  end
end
%=============================================================================
function width = ecgLabReportWidth(value)
  % Floor the width so every fixed label fits and only the prose wraps.
  if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
    value < 40 || value ~= round(value)
    error('ecglab:badWidth', 'The Width must be a whole number of at least 40 characters.');
  end
  width = double(value);
end
%=============================================================================
