%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function cosen = ecgLabRhythmCosen(rr, toleranceFraction, m)
  % Coefficient of sample entropy of an RR window (Lake and Moorman 2011):
  % COSEn = SampEn + ln(2 r) - ln(mean RR), with template length m = 1.
  % Here the tolerance r is a fraction of the mean RR. A regular rhythm gives a
  % low, very negative value; atrial fibrillation gives one near zero.
  rr = rr(:);
  meanRR = mean(rr);
  r = toleranceFraction * meanRR;
  if ~(r > 0)
    cosen = -Inf;
    return;
  end
  sampen = ecgLabRhythmSampen(rr, m, r);
  cosen = sampen + log(2 * r) - log(meanRR);
end
%=============================================================================
function sampen = ecgLabRhythmSampen(u, m, r)
  % Sample entropy -ln(A / B): B is the count of length-m template pairs
  % matching within tolerance r (Chebyshev), A those still matching at length
  % m + 1, self-matches removed. Counted on the full distance matrix at once.
  % A is floored to 1 so the entropy stays finite when nothing matches.
  u = u(:);
  N = numel(u);
  last = N - m;
  if last < 2
    sampen = 0;
    return;
  end
  % Compare length-m templates by Chebyshev distance; each coordinate is a
  % shifted copy of the series.
  matchM = true(last, last);
  for k = 0:(m - 1)
    coordinate = u((1 + k):(last + k));
    matchM = matchM & (abs(coordinate - coordinate') <= r);
  end
  coordinate = u((1 + m):(last + m));
  matchM1 = matchM & (abs(coordinate - coordinate') <= r);
  % Remove the diagonal self-matches, then count over all ordered pairs.
  B = sum(matchM(:)) - last;
  A = sum(matchM1(:)) - last;
  if B <= 0
    sampen = 0;
    return;
  end
  if A <= 0
    A = 1;
  end
  sampen = -log(A / B);
end
%=============================================================================
