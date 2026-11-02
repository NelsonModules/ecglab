%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% HRV = ECGLAB.HRV(X) measures heart rate variability from X.
% HRV = ECGLAB.HRV(X, 'Name', value, ...) sets the cleaning and the estimators.
%
%   X is one of three things:
%     an ecglab.recording (its beats are detected with ecglab.detect unless a
%       beats struct is given as 'Beats'),
%     an ecglab.beats struct (its rr series is used), or
%     a numeric vector, read as RR intervals ('Input' 'rr', the default) or as
%       R-peak times ('Input' 'peaks'), in seconds ('Unit' 'seconds', the
%       default) or milliseconds ('Unit' 'ms').
%
%   HRV is a struct of the data model: kind 'ecglab.hrv', with sub-structs
%   'time', 'frequency' and 'nonlinear' (field names from the standard), 'nn'
%   (the NN series used, in seconds, after ectopic handling), 'rejected' (how
%   many intervals were removed and by which rule), and 'settings' (every choice
%   that defines a number: the ectopic rule and threshold, the interpolation and
%   rate, the detrending, the spectral estimator and window, the bands).
%
%   The definitions follow the Task Force standard (Circulation 93:1043-1065,
%   1996); the non-linear measures follow Sassi et al. (Europace 17:1341-1353,
%   2015). The method, resampling and detrending behind a spectral number are
%   all recorded in 'settings'.
%
%   Options (name and value, matched without regard to case):
%     'Beats'       an ecglab.beats struct to use instead of detecting, when X
%                   is a recording (default [], detect).
%     'Input'       how a numeric X is read: 'rr' (default) or 'peaks'.
%     'Unit'        the unit of a numeric X: 'seconds' (default) or 'ms'.
%     'Range'       [lo hi] seconds; NN outside it are removed first (default
%                   [0.3 2.0]); [] disables the range filter.
%     'Ectopic'     the rule that flags an ectopic or erroneous NN: 'none',
%                   'malik' (default), 'karlsson', 'kamath', 'acar', or a
%                   numeric fraction (as malik with that fraction).
%     'Interp'      how a removed NN is replaced: 'linear' (default), 'spline'
%                   or 'none' (dropped).
%     'Method'      the spectral estimator: 'welch' (default), 'lomb' or 'ar'.
%     'Resample'    resampling rate in hertz for welch and ar (default 4).
%     'Detrend'     detrend order for welch and ar (default 1, linear).
%     'Window'      Welch window length in samples (default 256, a Hann window).
%     'ArOrder'     autoregressive model order (default 16).
%     'ArMethod'    'burg' (default) or 'yulewalker'.
%     'Segment'     segment length in seconds for SDANN and the SDNN index
%                   (default 300, five minutes).
%     'EntropyMax'  longest NN series the entropies run on; a longer one is
%                   capped to its first EntropyMax intervals, because sample
%                   and approximate entropy are quadratic in the length
%                   (default 3000).
%
%   Example:
%     recording = ecglab.simulate('Seconds', 300, 'HeartRateStd', 5, 'Seed', 1);
%     hrv = ecglab.hrv(recording);
%     ratio = hrv.frequency.lfhf;
%
%   See also ecglab.detect, ecglab.simulate, ecglab.validate.
function hrv = hrv(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Beats', [], 'Input', 'rr', 'Unit', 'seconds', ...
  'Range', [0.3 2.0], 'Ectopic', 'malik', 'Interp', 'linear', ...
  'Method', 'welch', 'Resample', 4, 'Detrend', 1, 'Window', 256, ...
  'ArOrder', 16, 'ArMethod', 'burg', 'Segment', 300, 'EntropyMax', 3000);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % Check the estimator before any work, so an unknown one fails fast.
  method = lower(char(options.Method));
  if ~any(strcmp(method, {'welch', 'lomb', 'ar'}))
    error('ecglab:unknownEstimator', 'Unknown spectral estimator: %s. Use welch, lomb or ar.', method);
  end
  %===========================================================================
  % Reduce X to a plain RR series in seconds, whatever it arrived as.
  rr = ecgLabHrvInput(X, options);
  %===========================================================================
  % The range filter and ectopic rule reduce the series to NN before any
  % measure, since every number is defined on normal-to-normal intervals.
  [nn, rejected, ectopicSettings] = ecgLabHrvEctopic(rr, options);
  if numel(nn) < 4
    error('ecglab:tooFewBeatsTooFewIntervalsRemain', 'Too few intervals remain to measure variability.');
  end
  %===========================================================================
  time = ecgLabHrvTime(nn, options);
  [frequency, freqSettings] = ecgLabHrvFrequency(nn, options, method);
  nonlinear = ecgLabHrvNonlinear(nn, options);
  %===========================================================================
  % The settings carry every choice behind each number: SDNN depends on the
  % rule, LF power on the estimator as much as the band.
  settings = struct();
  settings.ectopic = ectopicSettings.rule;
  settings.ectopicThreshold = ectopicSettings.threshold;
  settings.range = options.Range;
  settings.interp = lower(char(options.Interp));
  settings.method = method;
  settings.resample = freqSettings.resample;
  settings.detrend = freqSettings.detrend;
  settings.window = freqSettings.window;
  settings.arOrder = freqSettings.arOrder;
  settings.arMethod = freqSettings.arMethod;
  settings.bands = freqSettings.bands;
  settings.segment = double(options.Segment);
  settings.entropyN = nonlinear.entropyN;
  settings.entropyCapped = nonlinear.entropyCapped;
  settings.entropyM = 2;
  settings.entropyR = 0.2;
  nonlinear = rmfield(nonlinear, {'entropyN', 'entropyCapped'});
  %===========================================================================
  hrv = struct('kind', 'ecglab.hrv', 'time', time, 'frequency', frequency, ...
  'nonlinear', nonlinear, 'nn', nn, 'rejected', rejected, ...
  'settings', settings);
end
%=============================================================================
