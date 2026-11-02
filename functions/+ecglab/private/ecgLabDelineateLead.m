%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [sample, morphology] = ecgLabDelineateLead(signal, rate, beatSample, ...
  settings)
  % Delineate one lead: for every beat in BEATSAMPLE (1-based R peak indices)
  % return the twelve wave fiducials as 1-based sample indices (K x 12, order
  % Pon Ppeak Poff QRSon Q R S QRSoff J Ton Tpeak Toff, NaN for an absent wave)
  % and the ecgpuwave T morphology code per beat (K x 1).
  %
  % Method: wavelet modulus maxima (Martinez et al. 2004). A wave is a pair of
  % opposite-sign detail extrema straddling a zero crossing (the peak); onset
  % and offset are the outer extrema. QRS is anchored on R at a fine scale; T
  % and P are searched after and before the QRS at coarser scales.
  signal = signal(:);
  N = numel(signal);
  K = numel(beatSample);
  sample = nan(K, 12);
  morphology = nan(K, 1);
  if K == 0
    return;
  end
  %===========================================================================
  % One transform for the whole lead, to the coarsest scale any wave needs.
  [~, ~, details] = ecgLabSwt(signal, settings.wavelet, settings.levels);
  dQrs = details{settings.qrsScale};
  dT = details{settings.tScale};
  dP = details{settings.pScale};
  %===========================================================================
  % RR interval per beat, in samples, used to size the T and P windows. The
  % first beat borrows the second interval, the rest use the preceding one.
  beatSample = round(beatSample(:));
  if K >= 2
    rrSamples = [beatSample(2) - beatSample(1); diff(beatSample)];
  else
    rrSamples = round(rate);
  end
  qrsHalf = max(2, round(settings.qrsWindow * rate));
  tNear = max(1, round(settings.tNear * rate));
  pNear = max(1, round(settings.pNear * rate));
  %===========================================================================
  for k = 1:K
    R = beatSample(k);
    rr = rrSamples(k);
    %=========================================================================
    % A beat whose QRS window runs off either end of the record is truncated,
    % so leave the whole beat NaN rather than localize R against a clipped
    % complex.
    if R - qrsHalf < 1 || R + qrsHalf > N
      continue;
    end
    %=========================================================================
    % QRS: the dominant opposite-sign slope pair at the fine scale gives R (its
    % zero crossing); the significant slopes flanking it give Q, S, onset, offset.
    lo = max(1, R - qrsHalf);
    hi = min(N, R + qrsHalf);
    [exPos, exVal] = ecgLabDelineateExtrema(dQrs, lo, hi);
    if numel(exPos) < 2
      continue;
    end
    maxAbs = max(abs(exVal));
    keep = abs(exVal) >= settings.gammaQrs * maxAbs;
    exPos = exPos(keep);
    exVal = exVal(keep);
    if numel(exPos) < 2
      continue;
    end
    % R slope pair: the adjacent opposite-sign pair with the largest summed
    % amplitude (the R up- and down-stroke).
    [iL, iR] = ecgLabDelineateDominantPair(exPos, exVal);
    if iL == 0
      continue;
    end
    rPeak = ecgLabDelineateZero(dQrs, exPos(iL), exPos(iR));
    % The outermost significant slopes are the QRS edges; the P and T searches
    % anchor on them, so the boundary widening below does not move them.
    qrsOnSlope = exPos(1);
    qrsOffSlope = exPos(end);
    % QRS onset and offset read outward from the slopes to the clinical foot
    % (boundaryFraction); at fraction 1 they stay on the slope. Q and S are the
    % zero crossings just inside the R slopes, when a slope is there.
    qrsOn = ecgLabDelineateBoundary(dQrs, qrsOnSlope, -1, ...
    settings.boundaryFraction);
    qrsOff = ecgLabDelineateBoundary(dQrs, qrsOffSlope, 1, ...
    settings.boundaryFraction);
    qSample = NaN;
    if iL >= 2 && sign(exVal(iL - 1)) ~= sign(exVal(iL))
      qSample = ecgLabDelineateZero(dQrs, exPos(iL - 1), exPos(iL));
    end
    sSample = NaN;
    if iR <= numel(exPos) - 1 && sign(exVal(iR + 1)) ~= sign(exVal(iR))
      sSample = ecgLabDelineateZero(dQrs, exPos(iR), exPos(iR + 1));
    end
    sample(k, 4) = qrsOn;
    sample(k, 5) = qSample;
    sample(k, 6) = rPeak;
    sample(k, 7) = sSample;
    sample(k, 8) = qrsOff;
    sample(k, 9) = qrsOff;
    qrsScaleMax = maxAbs;
    %=========================================================================
    % T wave: from after the QRS offset slope out to a point set by the RR
    % interval. Anchored on the slope, not the clinical foot.
    tLo = min(N, qrsOffSlope + tNear);
    tFar = qrsOffSlope + min(round(settings.tFarFraction * rr), ...
    round(settings.tFarMax * rate));
    tHi = min(N, tFar);
    [tOn, tPeak, tOff, tCode] = ecgLabDelineateWave(dT, tLo, tHi, ...
    settings.tFloor * qrsScaleMax);
    % T offset: at boundary fraction 1 it stays on the slope maximum. With a
    % clinical fraction (default) it is read outward to the foot of the T by
    % the tangent method: the tangent at the steepest point of the return limb
    % meets the PR-segment baseline.
    if settings.boundaryFraction < 1 && isfinite(tOff) && isfinite(tPeak) && ...
      tOff > tPeak
      tEndWidth = max(1, round(0.010 * rate));
      a = max(1, tOff - tEndWidth);
      b = min(N, tOff + tEndWidth);
      tSlope = (signal(b) - signal(a)) / max(b - a, 1);
      isoLo = max(1, qrsOn - round(0.06 * rate));
      iso = median(signal(isoLo:qrsOn));
      if abs(tSlope) > eps
        tFoot = tOff + (iso - signal(tOff)) / tSlope;
        tOff = min(max(round(tFoot), tOff), tHi);
      end
    end
    sample(k, 10) = tOn;
    sample(k, 11) = tPeak;
    sample(k, 12) = tOff;
    morphology(k) = tCode;
    %=========================================================================
    % P wave: the opposite-sign slope pair before the QRS onset, at the P
    % scale, same biphasic model as the T. A lone sinus P is told from the
    % fibrillatory f wave by the dominance and isolation tests inside.
    pHi = max(1, qrsOnSlope - pNear);
    pFar = qrsOnSlope - min(round(settings.pFarFraction * rr), ...
    round(settings.pFarMax * rate));
    pLo = max(1, pFar);
    pCtxBack = round(settings.pIsolation * rate);
    pCtxFwd = pNear;
    [pOn, pPeak, pOff] = ecgLabDelineateP(dP, pLo, pHi, ...
    settings.pFloor * qrsScaleMax, settings.pDominance, pCtxBack, pCtxFwd, ...
    settings.pIsolationRatio);
    % Keep the P only when a PR segment of at least minPrSegment separates it
    % from the QRS; a pair running straight into the complex is its rising
    % edge, not a P.
    if isfinite(pOff) && qrsOnSlope - pOff >= round(settings.minPrSegment * rate)
      sample(k, 1) = pOn;
      sample(k, 2) = pPeak;
      sample(k, 3) = pOff;
    end
  end
  %===========================================================================
  % Clamp the finite marks into the signal range; an absent wave stays NaN.
  finite = isfinite(sample);
  sample(finite) = min(max(sample(finite), 1), N);
end
%=============================================================================
function [pos, val] = ecgLabDelineateExtrema(d, lo, hi)
  % Local extrema of the detail in [lo, hi], as 1-based positions and signed
  % values. Found where the first difference changes sign.
  lo = max(1, lo);
  hi = min(numel(d), hi);
  if hi - lo < 2
    pos = zeros(0, 1);
    val = zeros(0, 1);
    return;
  end
  seg = d(lo:hi);
  dd = diff(seg);
  % An extremum is where two neighbouring slopes have opposite sign (product
  % negative). Exact flat runs are not handled; they do not occur in practice.
  s = sign(dd);
  isExt = false(numel(seg), 1);
  isExt(2:end - 1) = s(1:end - 1) .* s(2:end) < 0;
  idx = find(isExt);
  pos = lo + idx - 1;
  val = seg(idx);
  pos = pos(:);
  val = val(:);
end
%=============================================================================
function [iL, iR] = ecgLabDelineateDominantPair(pos, val)
  % The adjacent opposite-sign pair with the largest summed amplitude (the R
  % up- and down-stroke). Returns the left and right indices into POS, or zero
  % when no opposite-sign pair exists.
  iL = 0;
  iR = 0;
  best = -inf;
  for i = 1:numel(pos) - 1
    if sign(val(i)) ~= sign(val(i + 1))
      strength = abs(val(i)) + abs(val(i + 1));
      if strength > best
        best = strength;
        iL = i;
        iR = i + 1;
      end
    end
  end
end
%=============================================================================
function s = ecgLabDelineateZero(d, a, b)
  % Zero crossing of the detail between two extrema, the sample nearest zero in
  % [a, b]. This is the wave's peak.
  a = max(1, min(a, b));
  b = min(numel(d), max(a, b));
  if b <= a
    s = a;
    return;
  end
  seg = d(a:b);
  crossed = find(seg(1:end - 1) .* seg(2:end) <= 0, 1);
  if isempty(crossed)
    [~, rel] = min(abs(seg));
    s = a + rel - 1;
    return;
  end
  if abs(seg(crossed)) <= abs(seg(crossed + 1))
    s = a + crossed - 1;
  else
    s = a + crossed;
  end
end
%=============================================================================
function b = ecgLabDelineateBoundary(d, peakPos, direction, fraction)
  % Wave boundary from a slope extremum. At FRACTION 1 the boundary is the
  % extremum itself; otherwise step outward (DIRECTION -1 for an onset, +1 for
  % an offset) to the first sample where the detail falls below that fraction
  % of the extremum.
  N = numel(d);
  if fraction >= 1
    b = peakPos;
    return;
  end
  target = fraction * abs(d(peakPos));
  pos = peakPos;
  while pos + direction >= 1 && pos + direction <= N
    pos = pos + direction;
    if abs(d(pos)) < target
      break;
    end
  end
  b = pos;
end
%=============================================================================
function [onset, peak, offset, code] = ecgLabDelineateWave(d, lo, hi, floorLevel)
  % A slow wave (the T) in [lo, hi]. Biphasic case: an opposite-sign extremum
  % pair straddling a zero crossing (the peak); onset and offset are the outer
  % extrema. When the pair clears FLOORLEVEL the morphology code is the
  % ecgpuwave number (0 normal, 1 inverted, 4/5 biphasic). A single dominant
  % slope above the floor is monophasic, coded 2 (positive) or 3 (negative).
  % Nothing above the floor means the wave is absent (NaN, NaN code).
  onset = NaN;
  peak = NaN;
  offset = NaN;
  code = NaN;
  [pos, val] = ecgLabDelineateExtrema(d, lo, hi);
  if isempty(pos)
    return;
  end
  [iL, iR, strength] = ecgLabDelineateBestPair(pos, val);
  if iL ~= 0 && strength >= floorLevel
    onset = pos(iL);
    offset = pos(iR);
    peak = ecgLabDelineateZero(d, pos(iL), pos(iR));
    code = ecgLabDelineateMorphologyCode(pos, val, iL, iR);
    return;
  end
  % No opposite-sign pair clears the floor. If a single slope does, the wave is
  % monophasic (its return limb is below the floor or past the window); emit it
  % so it is not dropped as absent.
  [mx, imx] = max(abs(val));
  if mx < floorLevel
    return;
  end
  slopePos = pos(imx);
  % Peak: the first zero crossing of the detail past the slope, or, if it never
  % crosses, where the detail is weakest past the slope. Onset is the slope;
  % offset sits at the peak (no distinct descending limb).
  peak = ecgLabDelineateZeroAfter(d, slopePos, hi);
  if isnan(peak)
    tail = d(slopePos:min(numel(d), hi));
    [~, rel] = min(abs(tail));
    peak = slopePos + rel - 1;
  end
  onset = slopePos;
  offset = peak;
  if sign(val(imx)) > 0
    code = 2;
  else
    code = 3;
  end
end
%=============================================================================
function [onset, peak, offset] = ecgLabDelineateP(d, lo, hi, floorLevel, ...
  dominance, ctxBack, ctxFwd, isoRatio)
  % The P wave as an opposite-sign slope pair in the PR window [lo, hi] at the
  % P scale, read exactly as the T is. Three tests separate a lone sinus P from
  % the sustained fibrillatory f wave: the pair must clear FLOORLEVEL, must
  % dominate its window (no runner-up above DOMINANCE times the best), and must
  % be ISOLATED over a wider context (no second pair above ISORATIO times the
  % best within one f-wave period). ONSET, PEAK and OFFSET are NaN when absent.
  onset = NaN;
  peak = NaN;
  offset = NaN;
  [pos, val] = ecgLabDelineateExtrema(d, lo, hi);
  if numel(pos) < 2
    return;
  end
  [iL, iR, strength, runnerUp] = ecgLabDelineateBestPair(pos, val);
  if iL == 0 || strength < floorLevel
    return;
  end
  if runnerUp > dominance * strength
    return;
  end
  % Isolation: count opposite-sign pairs reaching ISORATIO times the best over
  % the context from CTXBACK before the offset to CTXFWD past it. A lone P
  % leaves one (its own); the f wave leaves more, so reject when two or more.
  if ecgLabDelineatePairCount(d, pos(iR) - ctxBack, pos(iR) + ctxFwd, ...
    isoRatio * strength) >= 2
    return;
  end
  onset = pos(iL);
  offset = pos(iR);
  peak = ecgLabDelineateZero(d, pos(iL), pos(iR));
end
%=============================================================================
function n = ecgLabDelineatePairCount(d, lo, hi, level)
  % Count adjacent opposite-sign extremum pairs in [lo, hi] whose geometric
  % mean amplitude reaches LEVEL. Used for the P isolation test.
  n = 0;
  [pos, val] = ecgLabDelineateExtrema(d, lo, hi);
  for i = 1:numel(pos) - 1
    if sign(val(i)) ~= sign(val(i + 1)) && ...
      sqrt(abs(val(i)) * abs(val(i + 1))) >= level
      n = n + 1;
    end
  end
end
%=============================================================================
function s = ecgLabDelineateZeroAfter(d, p, hi)
  % First zero crossing of the detail strictly to the right of P, up to HI; NaN
  % when the detail keeps its sign to the window end.
  hi = min(numel(d), hi);
  if hi <= p
    s = NaN;
    return;
  end
  seg = d(p:hi);
  crossed = find(seg(1:end - 1) .* seg(2:end) <= 0, 1);
  if isempty(crossed)
    s = NaN;
    return;
  end
  if abs(seg(crossed)) <= abs(seg(crossed + 1))
    s = p + crossed - 1;
  else
    s = p + crossed;
  end
end
%=============================================================================
function [iL, iR, strength, runnerUp] = ecgLabDelineateBestPair(pos, val)
  % The adjacent opposite-sign extremum pair of greatest strength, strength
  % being the geometric mean of the two amplitudes. RUNNERUP is the next best
  % such pair's strength (for the dominance test), zero when there is only one.
  iL = 0;
  iR = 0;
  strength = 0;
  runnerUp = 0;
  for i = 1:numel(pos) - 1
    if sign(val(i)) ~= sign(val(i + 1))
      s = sqrt(abs(val(i)) * abs(val(i + 1)));
      if s > strength
        runnerUp = strength;
        strength = s;
        iL = i;
        iR = i + 1;
      elseif s > runnerUp
        runnerUp = s;
      end
    end
  end
end
%=============================================================================
function code = ecgLabDelineateMorphologyCode(pos, val, iL, iR)
  % ecgpuwave T morphology code from the wave's slopes: 0 normal (positive then
  % negative slope), 1 inverted, 4 biphasic negative-positive, 5 biphasic
  % positive-negative. An extremum counts as a lobe when it lies within the
  % wave's span (onset to half a wave-width past the offset) and reaches 0.4 of
  % the pair's strength, so the QRS tail is not counted.
  strength = sqrt(abs(val(iL)) * abs(val(iR)));
  margin = round(0.5 * (pos(iR) - pos(iL)));
  lo = pos(iL);
  hi = pos(iR) + margin;
  within = pos >= lo & pos <= hi & abs(val) >= 0.4 * strength;
  nLobe = sum(within);
  up = sign(val(iL));
  if up > 0
    if nLobe >= 3
      code = 5;
    else
      code = 0;
    end
  else
    if nLobe >= 3
      code = 4;
    else
      code = 1;
    end
  end
end
%=============================================================================
