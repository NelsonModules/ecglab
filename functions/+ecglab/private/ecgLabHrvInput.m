%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function rr = ecgLabHrvInput(X, options)
  % Turn every accepted form of X into a column of RR intervals in seconds. A
  % recording is detected (or given its beats), a beats struct gives its rr
  % series, and a vector is read as intervals or peak times in the given unit.
  % Only finite positive intervals survive.
  if isstruct(X) && isfield(X, 'kind')
    switch X.kind
      case 'ecglab.recording'
        beats = options.Beats;
        if isempty(beats)
          % No beats given: detect them on the recording's preferred lead.
          beats = ecglab.detect(X);
        elseif ~(isstruct(beats) && isfield(beats, 'kind') && ...
          strcmp(beats.kind, 'ecglab.beats'))
          error('ecglab:badBeatsBeatsEcglabBeatsStruct2', 'Beats must be an ecglab.beats struct.');
        end
        rr = beats.rr;
      case 'ecglab.beats'
        rr = X.rr;
      otherwise
        error('ecglab:notHrvInput', 'X must be a recording, a beats struct, or a numeric vector.');
    end
    rr = rr(:);
  elseif isnumeric(X) && isvector(X) && ~isempty(X)
    values = double(X(:));
    if strcmpi(char(options.Unit), 'ms')
      values = values / 1000;
    elseif ~strcmpi(char(options.Unit), 'seconds')
      error('ecglab:badUnitUnitSecondsMs', 'Unit must be seconds or ms.');
    end
    input = lower(char(options.Input));
    if strcmp(input, 'peaks')
      % R-peak times: intervals are their differences, and times must increase.
      if any(diff(values) <= 0)
        error('ecglab:peakOrder', 'R-peak times must strictly increase.');
      end
      rr = diff(values);
    elseif strcmp(input, 'rr')
      rr = values;
    else
      error('ecglab:badInputInputRrPeaks', 'Input must be rr or peaks.');
    end
  else
    error('ecglab:notHrvInput', 'X must be a recording, a beats struct, or a numeric vector.');
  end
  % Drop non-finite and non-positive intervals (a NaN marks a first beat or a
  % flagged gap) so the range filter and ectopic rule see real intervals only.
  rr = rr(isfinite(rr) & rr > 0);
  if numel(rr) < 4
    error('ecglab:tooFewBeatsTooFewIntervalsMeasure', 'Too few intervals to measure variability.');
  end
end
%=============================================================================
