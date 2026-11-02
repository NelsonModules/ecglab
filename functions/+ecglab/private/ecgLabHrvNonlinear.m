%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function nonlinear = ecgLabHrvNonlinear(nn, options)
  % Non-linear measures (2015 position paper): the Poincare plot, detrended
  % fluctuation analysis, and the two entropies. No single accepted standard,
  % so every parameter is fixed here and written into the settings.
  nnms = nn * 1000;
  d = diff(nnms);
  %===========================================================================
  % Poincare plot: each NN against the next. SD1 is the spread across the line
  % of identity, SD2 along it; Brennan's closed forms (2001) tie them to SDSD
  % and SDNN. The ellipse has axes SD1, SD2 and area pi SD1 SD2.
  sdsd = std(d);
  sdnn = std(nnms);
  nonlinear = struct();
  nonlinear.sd1 = sqrt(0.5) * sdsd;
  nonlinear.sd2 = sqrt(max(2 * sdnn ^ 2 - 0.5 * sdsd ^ 2, 0));
  if nonlinear.sd1 > 0
    nonlinear.sdRatio = nonlinear.sd2 / nonlinear.sd1;
  else
    nonlinear.sdRatio = NaN;
  end
  nonlinear.ellipseArea = pi * nonlinear.sd1 * nonlinear.sd2;
  %===========================================================================
  % Detrended fluctuation analysis: short-term alpha1 over boxes of 4 to 16
  % beats, longer alpha2 over 16 to 64. Around 1 is healthy variability, 0.5
  % white noise, 1.5 a random walk.
  nonlinear.alpha1 = ecgLabHrvDfa(nn, 4:16);
  nonlinear.alpha2 = ecgLabHrvDfa(nn, 16:64);
  %===========================================================================
  % Sample and approximate entropy, embedding dimension 2 and tolerance 0.2 of
  % the standard deviation. Both are quadratic in series length, so a long
  % record is capped to its first EntropyMax intervals; the length used and
  % whether it was capped are reported.
  entropyMax = round(double(options.EntropyMax));
  nUse = min(numel(nn), entropyMax);
  xEnt = nn(1:nUse);
  [nonlinear.sampen, nonlinear.apen] = ecgLabHrvEntropy(xEnt, 2, 0.2);
  nonlinear.entropyN = nUse;
  nonlinear.entropyCapped = numel(nn) > entropyMax;
end
%=============================================================================
