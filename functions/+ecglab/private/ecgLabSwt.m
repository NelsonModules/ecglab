%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [detail, approx, details] = ecgLabSwt(signal, wavelet, level, ...
  minDetailLevel)
  % Stationary (undecimated) wavelet transform by the a trous algorithm, not
  % provided by Nelson's core. It never downsamples; at each level the filters
  % are upsampled by inserting zeros, keeping the full sample rate and the
  % shift invariance a beat detector needs.
  %
  % At level j the low-pass and high-pass are upsampled by 2^(j - 1) and
  % convolved with the running approximation, which feeds the next level.
  % DETAIL and APPROX are N x 1 columns; optional DETAILS is a 1 x level cell of
  % the detail at every level. MINDETAILLEVEL (default 1) is the lowest level
  % whose detail is wanted; shallower high-passes are skipped, but the low-pass
  % cascade still runs at every level.
  %
  % Zero phase: conv '...same' centres the output on the kernel. The spline
  % filters are symmetric, so exactly zero phase; db3 leaves a sub-sample
  % residual that is immaterial here.
  if nargin < 4 || isempty(minDetailLevel)
    minDetailLevel = 1;
  end
  [decLow, decHigh] = ecgLabSwtFilters(wavelet);
  approx = signal(:);
  detail = zeros(numel(approx), 1);
  details = cell(1, level);
  for j = 1:level
    up = 2 ^ (j - 1);
    % Build the detail only for the levels asked for; the low-pass runs every
    % level to feed the next approximation.
    if j >= minDetailLevel
      highUp = ecgLabSwtUpsample(decHigh, up);
      detail = conv(approx, highUp, 'same');
      details{j} = detail;
    end
    lowUp = ecgLabSwtUpsample(decLow, up);
    approx = conv(approx, lowUp, 'same');
  end
end
%=============================================================================
function up = ecgLabSwtUpsample(filterTaps, factor)
  % Insert factor - 1 zeros between the taps (the a trous dilation). Returns a
  % column so conv keeps the approximation a column.
  filterTaps = filterTaps(:);
  if factor <= 1
    up = filterTaps;
    return;
  end
  L = numel(filterTaps);
  up = zeros((L - 1) * factor + 1, 1);
  up(1:factor:end) = filterTaps;
end
%=============================================================================
function [decLow, decHigh] = ecgLabSwtFilters(wavelet)
  % Two wavelets: db3 is the detector's band pass, the quadratic spline is for
  % the delineator's modulus maxima. Kept together so both share one transform.
  switch lower(char(wavelet))
    case 'db3'
      % Length-6 Daubechies extremal-phase reconstruction low-pass (Daubechies,
      % Ten Lectures on Wavelets, 1992, Table 6.1, N = 3). The decomposition
      % low-pass is it reversed; the high-pass is its quadrature mirror,
      % dec_hi(k) = (-1)^k * rec_lo(k).
      recLow = [0.3326705529509569; 0.8068915093133388; ...
      0.4598775021193313; -0.1350110200102546; ...
      -0.0854412738820267; 0.0352262918857095];
      decLow = flipud(recLow);
      signs = ((-1) .^ (1:numel(recLow)))';
      decHigh = signs .* recLow;
    case 'spline'
      % Quadratic spline wavelet of Martinez et al. (IEEE TBME 51(4), 2004):
      % smoothing low-pass [1 3 3 1]/8 and high-pass [2 -2] (a derivative), so
      % its modulus maxima mark the steep slopes of a wave.
      decLow = [1; 3; 3; 1] / 8;
      decHigh = [2; -2];
    otherwise
      error('ecglab:unknownWavelet', 'The wavelet must be db3 or spline.');
  end
end
%=============================================================================
