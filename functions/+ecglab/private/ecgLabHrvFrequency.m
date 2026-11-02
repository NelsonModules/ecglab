%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [frequency, settingsOut] = ecgLabHrvFrequency(nn, options, method)
  % Task Force frequency-domain measures in the four bands ULF, VLF, LF, HF.
  % PSD is in ms^2/Hz so band powers are in ms^2. Welch and the AR model work
  % on the NN series resampled to a uniform grid and detrended; Lomb works on
  % the uneven series directly. The resampling, detrending and window are
  % returned in the settings since they define the numbers too.
  bands = struct('ulf', [0, 0.003], 'vlf', [0.003, 0.04], ...
  'lf', [0.04, 0.15], 'hf', [0.15, 0.4]);
  settingsOut = struct('resample', NaN, 'detrend', NaN, 'window', [], ...
  'arOrder', NaN, 'arMethod', '', 'bands', bands);
  fs = double(options.Resample);
  detrendOrder = double(options.Detrend);
  t = cumsum(nn);
  psd = [];
  f = [];
  switch method
    case {'welch', 'ar'}
      % Tachogram resampled on a uniform grid by cubic spline (the standard's
      % choice), then detrended so slow drift does not leak into the low band.
      ti = (t(1):1 / fs:t(end))';
      if numel(ti) >= 8
        series = ecgLabHrvSpline(t, nn, ti) * 1000;
        series = detrend(series, detrendOrder);
        settingsOut.resample = fs;
        settingsOut.detrend = detrendOrder;
        if strcmp(method, 'welch')
          win = min(round(double(options.Window)), numel(series));
          if win >= 4
            nfft = max(2 ^ nextpow2(win), 1024);
            [psd, f] = pwelch(series, hann(win), floor(win / 2), nfft, fs);
            settingsOut.window = win;
          end
        else
          order = round(double(options.ArOrder));
          arMethod = lower(char(options.ArMethod));
          nfft = max(2 ^ nextpow2(numel(series)), 1024);
          [psd, f] = ecgLabHrvAr(series, fs, order, arMethod, nfft);
          settingsOut.arOrder = order;
          settingsOut.arMethod = arMethod;
        end
      end
    case 'lomb'
      % Lomb-Scargle on the uneven series: no resampling, mean removed. Time
      % axis is cumulative beat time, values are NN intervals in milliseconds.
      series = (nn - mean(nn)) * 1000;
      [psd, f] = ecgLabHrvLomb(t, series, 0.5);
      settingsOut.resample = NaN;
      settingsOut.detrend = 'mean removed';
  end
  %===========================================================================
  frequency = ecgLabHrvBands(psd, f, bands);
end
%=============================================================================
function frequency = ecgLabHrvBands(psd, f, bands)
  % Integrate the spectrum over each band and read off its peak. When the
  % spectrum could not be estimated (too short a series), every number is NaN.
  names = {'ulf', 'vlf', 'lf', 'hf'};
  frequency = struct();
  if isempty(psd)
    for k = 1:numel(names)
      frequency.(names{k}) = NaN;
      frequency.([names{k}, 'Peak']) = NaN;
    end
    frequency.lfnu = NaN;
    frequency.hfnu = NaN;
    frequency.lfhf = NaN;
    frequency.totalPower = NaN;
    return;
  end
  f = f(:);
  psd = psd(:);
  for k = 1:numel(names)
    edges = bands.(names{k});
    mask = f >= edges(1) & f < edges(2);
    fb = f(mask);
    pb = psd(mask);
    if numel(fb) >= 2
      % trapz needs at least two abscissae; a single bin has no width.
      frequency.(names{k}) = trapz(fb, pb);
      [~, local] = max(pb);
      frequency.([names{k}, 'Peak']) = fb(local);
    elseif numel(fb) == 1
      frequency.(names{k}) = 0;
      frequency.([names{k}, 'Peak']) = fb(1);
    else
      frequency.(names{k}) = 0;
      frequency.([names{k}, 'Peak']) = NaN;
    end
  end
  % Total power is the sum of the four bands. The normalised units put LF and
  % HF over total power minus VLF, i.e. ULF + LF + HF. The ULF term must stay
  % in the denominator or the units depart from the standard on long records,
  % where the AR spectrum carries ULF power.
  frequency.totalPower = frequency.ulf + frequency.vlf + frequency.lf + ...
  frequency.hf;
  denom = frequency.ulf + frequency.lf + frequency.hf;
  if denom > 0
    frequency.lfnu = 100 * frequency.lf / denom;
    frequency.hfnu = 100 * frequency.hf / denom;
  else
    frequency.lfnu = NaN;
    frequency.hfnu = NaN;
  end
  if frequency.hf > 0
    frequency.lfhf = frequency.lf / frequency.hf;
  else
    frequency.lfhf = NaN;
  end
end
%=============================================================================
