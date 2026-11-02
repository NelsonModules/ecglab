%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [nn, rejected, settingsOut] = ecgLabHrvEctopic(rr, options)
  % Turn a raw RR series into the NN series. Two filters run in order: a range
  % filter removes physically impossible intervals (default 0.3 to 2.0 s),
  % then a named ectopic rule flags intervals that jump too far from their
  % accepted neighbours. Flagged intervals are interpolated or dropped.
  % Rules supported: Malik, Karlsson, Kamath, Acar. The reference-based ones
  % compare each interval to the last accepted interval, not the previous raw
  % one, so one ectopic beat cannot also reject its successor.
  n0 = numel(rr);
  removed = false(n0, 1);
  rangeRemoved = 0;
  %===========================================================================
  % The range filter. Intervals outside it are set aside before the ectopic
  % rule so they cannot pose as a neighbour.
  range = options.Range;
  if ~isempty(range)
    if ~(isnumeric(range) && numel(range) == 2 && range(1) < range(2))
      error('ecglab:badRange', 'Range must be [low high] seconds with low below high.');
    end
    outside = rr < range(1) | rr > range(2);
    removed = removed | outside;
    rangeRemoved = sum(outside);
  end
  %===========================================================================
  % The ectopic rule. work carries NaN where a value is already removed so the
  % rule skips it when it looks for the last accepted interval.
  work = rr;
  work(removed) = NaN;
  [ectopicMask, rule, threshold] = ecgLabHrvEctopicRule(work, options.Ectopic);
  ectopicRemoved = sum(ectopicMask & ~removed);
  removed = removed | ectopicMask;
  %===========================================================================
  % Replace or drop. Linear or spline interpolation fills a flagged interval
  % from the finite intervals around it; a flag at the start or end has no
  % neighbour on one side and is dropped. 'none' drops every flagged interval.
  interp = lower(char(options.Interp));
  cleaned = rr;
  cleaned(removed) = NaN;
  switch interp
    case 'none'
      nn = cleaned(~isnan(cleaned));
    case {'linear', 'spline'}
      index = (1:n0)';
      good = ~isnan(cleaned);
      if sum(good) < 2
        nn = cleaned(good);
      else
        filled = interp1(index(good), cleaned(good), index, interp);
        % interp1 leaves NaN outside the finite range; those end flags are
        % dropped.
        nn = filled(~isnan(filled));
      end
    otherwise
      error('ecglab:badInterp', 'Interp must be linear, spline or none.');
  end
  nn = nn(:);
  %===========================================================================
  rejected = struct('count', rangeRemoved + ectopicRemoved, ...
  'rule', rule, 'rangeRemoved', rangeRemoved, ...
  'ectopicRemoved', ectopicRemoved, 'total', n0, 'interp', interp);
  settingsOut = struct('rule', rule, 'threshold', threshold);
end
%=============================================================================
function [mask, rule, threshold] = ecgLabHrvEctopicRule(work, ectopic)
  % One reject mask per rule. work may carry NaN (already removed); a NaN is
  % never a reference and is never itself re-flagged here.
  n = numel(work);
  mask = false(n, 1);
  if isnumeric(ectopic)
    % A bare fraction is the Malik test with that fraction (default 0.2).
    if ~(isscalar(ectopic) && ectopic > 0 && ectopic < 1)
      error('ecglab:badEctopicNumericEctopicFractionBetween', 'A numeric Ectopic must be a fraction between 0 and 1.');
    end
    rule = 'fraction';
    threshold = double(ectopic);
    mask = ecgLabHrvReference(work, threshold);
    return;
  end
  rule = lower(char(ectopic));
  switch rule
    case 'none'
      threshold = [];
    case 'malik'
      threshold = 0.2;
      mask = ecgLabHrvReference(work, 0.2);
    case 'kamath'
      threshold = [0.325, 0.245];
      mask = ecgLabHrvKamath(work, 0.325, 0.245);
    case 'karlsson'
      threshold = 0.2;
      mask = ecgLabHrvKarlsson(work, 0.2);
    case 'acar'
      threshold = 0.2;
      mask = ecgLabHrvAcar(work, 0.2, 9);
    otherwise
      error('ecglab:badEctopicUnknownEctopicRuleS', 'Unknown ectopic rule: %s.', rule);
  end
end
%=============================================================================
function mask = ecgLabHrvReference(work, fraction)
  % Malik: keep an interval within FRACTION of the last accepted one, flag it
  % otherwise. The first finite interval is always accepted as the reference.
  n = numel(work);
  mask = false(n, 1);
  ref = NaN;
  for i = 1:n
    x = work(i);
    if isnan(x)
      continue;
    end
    if isnan(ref)
      ref = x;
      continue;
    end
    if abs(x - ref) > fraction * ref
      mask(i) = true;
    else
      ref = x;
    end
  end
end
%=============================================================================
function mask = ecgLabHrvKamath(work, up, down)
  % Kamath: keep when a rise is at most UP of the last accepted interval or a
  % fall at most DOWN of it. Asymmetric because a premature beat shortens more
  % sharply than the following pause lengthens.
  n = numel(work);
  mask = false(n, 1);
  ref = NaN;
  for i = 1:n
    x = work(i);
    if isnan(x)
      continue;
    end
    if isnan(ref)
      ref = x;
      continue;
    end
    d = x - ref;
    keep = (d >= 0 && d <= up * ref) || (d < 0 && -d <= down * ref);
    if keep
      ref = x;
    else
      mask(i) = true;
    end
  end
end
%=============================================================================
function mask = ecgLabHrvKarlsson(work, fraction)
  % Karlsson: flag an interval more than FRACTION away from the mean of its two
  % nearest finite neighbours. An interval with a neighbour on only one side is
  % compared to that one.
  n = numel(work);
  mask = false(n, 1);
  good = find(~isnan(work));
  for k = 1:numel(good)
    i = good(k);
    neighbours = [];
    if k > 1
      neighbours(end + 1) = work(good(k - 1));
    end
    if k < numel(good)
      neighbours(end + 1) = work(good(k + 1));
    end
    if isempty(neighbours)
      continue;
    end
    m = mean(neighbours);
    if abs(work(i) - m) > fraction * m
      mask(i) = true;
    end
  end
end
%=============================================================================
function mask = ecgLabHrvAcar(work, fraction, span)
  % Acar: flag an interval more than FRACTION away from the mean of the last
  % SPAN accepted intervals, a running comparison that follows slow rate drift
  % while catching a sudden ectopic jump.
  n = numel(work);
  mask = false(n, 1);
  history = [];
  for i = 1:n
    x = work(i);
    if isnan(x)
      continue;
    end
    if isempty(history)
      history = x;
      continue;
    end
    m = mean(history);
    if abs(x - m) > fraction * m
      mask(i) = true;
    else
      history(end + 1) = x;
      if numel(history) > span
        history = history(end - span + 1:end);
      end
    end
  end
end
%=============================================================================
