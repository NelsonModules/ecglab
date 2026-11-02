%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function settings = ecgLabDelineateScales(rate)
  % Wavelet scales and thresholds for the delineator, chosen from the sampling
  % rate (Martinez et al. 2004). Scale indices are shifted by the octave
  % difference from 250 Hz so each wave stays on the band the paper intended.
  % The anchor is the scale whose centre is near 15.6 Hz, where a normal QRS
  % peaks; every other scale is placed relative to it.
  q = max(3, round(log2(rate / 15.6)));
  settings = struct();
  settings.wavelet = 'spline';
  % QRS fiducials are taken two octaves finer than the anchor, where the sharp
  % QRS slopes localise best.
  settings.qrsScale = max(1, q - 2);
  % The T wave sits at the anchor scale, where its slope pair is resolved and
  % the QRS tail forms no competing pair.
  settings.tScale = q;
  % The P is read as one opposite-sign slope pair, one octave finer than the
  % anchor: at the anchor its downslope merges into the QRS rising edge and
  % leaves no pair, while one scale finer it stands as its own maximum.
  settings.pScale = max(1, q - 1);
  % Run the transform to the coarsest scale any wave needs (the T anchor).
  settings.levels = q;
  %===========================================================================
  % Fraction of the window maximum a QRS extremum must reach to count as a
  % slope: low enough to keep the small Q and S slopes, high enough to reject
  % the baseline.
  settings.gammaQrs = 0.08;
  % Floor a P or T slope pair must clear, as a fraction of the QRS slope
  % amplitude; below it the wave is absent. Scaling to the QRS follows the
  % record's own gain.
  settings.tFloor = 0.004;
  settings.pFloor = 0.004;
  % Ratio the runner-up slope pair in the PR window must stay below for a P to
  % stand. Set near equality: a cheap first pass that only drops a window of
  % two plainly equal deflections, the isolation test below carrying the rest.
  settings.pDominance = 0.9;
  % Context, in seconds, over which a P must stand alone. About one f-wave
  % period, so the neighbouring fibrillatory crest is seen, while staying short
  % of the preceding T at a normal rate.
  settings.pIsolation = 0.22;
  % Strength that second pair must reach, as a fraction of the P's own, to
  % count as fibrillatory. Set high because the f wave's crests are nearly
  % equal, while a real P's context carries only weaker remnants.
  settings.pIsolationRatio = 0.8;
  %===========================================================================
  % Search windows, in seconds, relative to the QRS. The T runs from just after
  % the QRS offset to a point set by the RR interval; the P runs back from just
  % before the QRS onset to a point also set by the RR.
  settings.tNear = 0.04;
  settings.tFarFraction = 0.7;
  settings.tFarMax = 0.5;
  settings.pNear = 0.02;
  settings.pFarFraction = 0.45;
  settings.pFarMax = 0.25;
  % Minimum PR segment, in seconds, a P must leave before the QRS onset slope.
  % A pair whose offset sits against the QRS onset is the complex's rising edge
  % (or an f-wave crest pinned to it), not a P.
  settings.minPrSegment = 0.04;
  settings.qrsWindow = 0.10;
  % Fraction of the boundary slope maximum at which the QRS onset and offset
  % are read outward (the clinical foot of the complex), the constant of
  % Martinez et al. (2004). Fraction 1, via the BoundaryFraction option, keeps
  % the boundary on the slope maximum for a slope-planted simulator truth.
  settings.boundaryFraction = 0.06;
end
%=============================================================================
