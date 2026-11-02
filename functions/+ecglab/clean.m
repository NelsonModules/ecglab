%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% CLEAN = ECGLAB.CLEAN(X) removes baseline wander and mains interference.
% CLEAN = ECGLAB.CLEAN(X, 'Name', value, ...) sets the methods and options.
%
%   X is an ecglab.recording (every lead is cleaned) or a plain signal vector
%   in millivolts whose 'Rate' in hertz is given. CLEAN is the same shape as
%   X: a recording with the same fields and the samples replaced, or a vector
%   with the same orientation. When X is a recording the result carries
%   CLEAN.info.cleaning, a record of what was done.
%
%   Removes two artefacts: slow baseline wander (breathing and electrode drift,
%   below the heart rate) and mains hum at 50 or 60 Hz. Both are removed without
%   moving the QRS peak or tilting the ST segment.
%
%   Options (name and value, matched without regard to case):
%     'Baseline'       'highpass' (default), 'median', 'spline' or 'none'.
%     'BaselineCut'    the high-pass edge in hertz (default 0.5).
%     'Mains'          'auto' (default), 50, 60 or false.
%     'MainsThreshold' how far above the neighbouring harmonics the mains line
%                      must stand for 'auto' to remove it (default 3).
%     'MainsQ'         the quality factor of the notch (default 35).
%     'MainsHarmonics' true (default) also notches the harmonics up to Nyquist.
%     'Lead'           the leads to clean, names or column indices (default
%                      all). The leads left out pass through unchanged.
%     'Rate'           the sampling rate in hertz, required when X is a vector.
%
%   The baseline methods.
%   'highpass' is a second-order Butterworth high pass at 'BaselineCut', applied
%   with filtfilt so it is zero phase and does not tilt the ST segment.
%   'median' is the two-stage sliding median of de Chazal et al. (2004): a
%   200 ms median removes the QRS, a 600 ms median of that removes the P and T
%   waves, and the rest is subtracted as the baseline. The window median is
%   evaluated on an 80 ms grid and interpolated, for speed.
%   'spline' finds beats with ecglab.detect, reads the isoelectric level about
%   40 ms before each QRS onset, and subtracts a natural cubic spline through
%   those points. It runs a detector first, so it is the slowest method.
%
%   The mains notch.
%   'auto' measures the power at 50 and 60 Hz on the baseline-cleaned spectrum
%   and removes whichever line stands above its neighbouring harmonics by
%   'MainsThreshold', else removes nothing. The removal is a second-order IIR
%   notch designed from the frequency and 'MainsQ', applied with filtfilt so the
%   phase is not bent. With 'MainsHarmonics' true the notch is repeated at every
%   multiple of the mains frequency below Nyquist.
%
%   CLEAN.info.cleaning (a recording only) has: baseline, a struct with the
%   method and the cut in hertz (NaN when the method has no cut); mains, the
%   frequency removed or 0; and baselineRemoved, the RMS in millivolts of what
%   the baseline stage subtracted, per lead (0 for a lead left out).
%
%   Example:
%     recording = ecglab.simulate('Seconds', 30, 'Baseline', 0.5, ...
%       'Mains', 0.1, 'MainsFrequency', 50, 'Seed', 1);
%     cleaned = ecglab.clean(recording);
%     cleaned.info.cleaning.mains
%
%   See also ecglab.detect, ecglab.quality, ecglab.simulate.
function clean = clean(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Baseline', 'highpass', 'BaselineCut', 0.5, ...
  'Mains', 'auto', 'MainsThreshold', 3, 'MainsQ', 35, ...
  'MainsHarmonics', true, 'Lead', [], 'Rate', []);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % The signal matrix, its rate and the shape to return. A recording is rebuilt
  % at the end; a plain vector needs its rate and keeps its orientation.
  [samples, rate, isRecording, wasRow] = ecgLabCleanInput(X, options);
  leadCount = size(samples, 2);
  columns = ecgLabCleanColumns(X, options.Lead, isRecording, leadCount);
  %===========================================================================
  % Check the baseline method before any work, so a typo is a clear error.
  method = ecgLabCleanBaselineMethod(options.Baseline);
  if size(samples, 1) < ecgLabCleanMinSamples(rate, method)
    error('ecglab:tooShortSignalTooShortClean', 'The signal is too short to clean.');
  end
  cut = double(options.BaselineCut);
  %===========================================================================
  % Baseline first, on every selected lead, keeping the RMS removed per lead.
  % The mains decision then reads the baseline-cleaned signal.
  baselineRemoved = zeros(1, leadCount);
  for index = 1:numel(columns)
    col = columns(index);
    before = samples(:, col);
    after = ecgLabCleanBaseline(before, rate, method, cut);
    baselineRemoved(col) = sqrt(mean((before - after) .^ 2));
    samples(:, col) = after;
  end
  %===========================================================================
  % The mains frequency, decided once for the record, then notched out of each
  % selected lead.
  mainsFreq = ecgLabCleanMainsFreq(samples(:, columns), rate, options.Mains, ...
  double(options.MainsThreshold));
  if mainsFreq > 0
    for index = 1:numel(columns)
      col = columns(index);
      samples(:, col) = ecgLabCleanNotch(samples(:, col), rate, mainsFreq, ...
      double(options.MainsQ), logical(options.MainsHarmonics));
    end
  end
  %===========================================================================
  clean = ecgLabCleanOutput(X, samples, isRecording, wasRow, method, cut, ...
  mainsFreq, baselineRemoved);
end
%=============================================================================
function [samples, rate, isRecording, wasRow] = ecgLabCleanInput(X, options)
  if isstruct(X) && isfield(X, 'kind') && strcmp(X.kind, 'ecglab.recording')
    samples = double(X.samples);
    rate = double(X.rate);
    isRecording = true;
    wasRow = false;
    return;
  end
  if isnumeric(X) && isvector(X) && ~isempty(X)
    if isempty(options.Rate)
      error('ecglab:needRateSignalVectorNeedsIts', 'A signal vector needs its sampling rate, given as Rate.');
    end
    rate = double(options.Rate);
    if ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
      error('ecglab:badRateSamplingRateOnePositive', 'The sampling rate must be one positive number of hertz.');
    end
    wasRow = isrow(X);
    samples = double(X(:));
    isRecording = false;
    return;
  end
  error('ecglab:notASignalXEcglabRecordingSignal', 'X must be an ecglab.recording or a signal vector with a Rate.');
end
%=============================================================================
function columns = ecgLabCleanColumns(X, lead, isRecording, leadCount)
  % Which leads to clean. A plain vector is one signal; a recording may be
  % narrowed to named leads or indices, the rest left unchanged.
  if isempty(lead)
    columns = 1:leadCount;
    return;
  end
  if ~isRecording
    columns = 1;
    return;
  end
  if ischar(lead) || isStringScalar(lead)
    lead = {char(lead)};
  end
  if iscell(lead)
    columns = zeros(1, numel(lead));
    for index = 1:numel(lead)
      match = find(strcmpi(char(lead{index}), X.leads), 1);
      if isempty(match)
        error('ecglab:unknownLeadRecordingHasNoLead', 'The recording has no lead named %s.', char(lead{index}));
      end
      columns(index) = match;
    end
    return;
  end
  if isnumeric(lead)
    columns = round(double(lead(:)'));
    if any(columns < 1) || any(columns > leadCount)
      error('ecglab:unknownLeadLeadIndexOutsideD', 'A lead index is outside the %d leads.', leadCount);
    end
    return;
  end
  error('ecglab:badLeadLeadNamesColumnIndices', 'The lead must be names or column indices.');
end
%=============================================================================
function method = ecgLabCleanBaselineMethod(value)
  if ~ischar(value) && ~isStringScalar(value)
    error('ecglab:badBaseline', 'The baseline method must be highpass, median, spline or none.');
  end
  method = lower(char(value));
  if ~any(strcmp(method, {'highpass', 'median', 'spline', 'none'}))
    error('ecglab:unknownBaseline', 'Unknown baseline method: %s.', method);
  end
end
%=============================================================================
function n = ecgLabCleanMinSamples(rate, method)
  % The shortest signal the chosen stage can work on: a fifth of a second for
  % the high pass and notch, the long window for the median.
  n = max(16, round(0.2 * rate));
  if strcmp(method, 'median')
    n = max(n, round(0.6 * rate) + 1);
  end
  if strcmp(method, 'spline')
    % The spline runs ecglab.detect, which needs three seconds; raise this
    % error below that, not the detector's.
    n = max(n, round(3 * rate));
  end
end
%=============================================================================
function clean = ecgLabCleanOutput(X, samples, isRecording, wasRow, method, ...
  cut, mainsFreq, baselineRemoved)
  if ~isRecording
    if wasRow
      clean = samples.';
    else
      clean = samples;
    end
    return;
  end
  clean = X;
  clean.samples = samples;
  % The cut belongs to the high pass only; NaN for the other methods.
  if strcmp(method, 'highpass')
    baselineCut = cut;
  else
    baselineCut = NaN;
  end
  cleaning = struct('baseline', struct('method', method, 'cut', baselineCut), ...
  'mains', mainsFreq, 'baselineRemoved', baselineRemoved);
  clean.info.cleaning = cleaning;
end
%=============================================================================
