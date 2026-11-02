%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function sokolow = ecgLabLeadsSokolow(derived, waves)
  % Sokolow-Lyon voltage, empty when the needed precordial leads are absent.
  % S in V1 plus the larger of R in V5/V6 (mV), with the 3.5 mV LVH flag.
  lowered = lower(derived.leads);
  v1 = find(strcmp(lowered, 'v1'), 1);
  v5 = find(strcmp(lowered, 'v5'), 1);
  v6 = find(strcmp(lowered, 'v6'), 1);
  % Need V1 and at least one of V5/V6, else no criterion.
  if isempty(v1) || (isempty(v5) && isempty(v6))
    sokolow = [];
    return;
  end
  onset = waves.sample(:, 4);
  offset = waves.sample(:, 8);
  % S in V1 is the downward deflection, R in V5/V6 the upward, median over beats.
  [~, sV1] = ecgLabLeadsDeflection(derived.samples(:, v1), onset, offset);
  rV5 = ecgLabLeadsDeflectionR(derived.samples, v5, onset, offset);
  rV6 = ecgLabLeadsDeflectionR(derived.samples, v6, onset, offset);
  amplitude = sV1 + max([rV5, rV6]);
  sokolow = struct('sV1', sV1, 'rV5', rV5, 'rV6', rV6, ...
  'amplitude', amplitude, 'exceeds', amplitude > 3.5);
end
%=============================================================================
function r = ecgLabLeadsDeflectionR(samples, column, onset, offset)
  % R height of a precordial lead, NaN when the lead is absent.
  if isempty(column)
    r = NaN;
    return;
  end
  r = ecgLabLeadsDeflection(samples(:, column), onset, offset);
end
%=============================================================================
function [rAmp, sAmp] = ecgLabLeadsDeflection(signal, onset, offset)
  % Upward (R) and downward (S) deflection of one lead over the QRS window,
  % median over beats, measured from the baseline line between onset and offset.
  signal = signal(:);
  K = numel(onset);
  rs = nan(K, 1);
  ss = nan(K, 1);
  for k = 1:K
    on = onset(k);
    off = offset(k);
    if ~isfinite(on) || ~isfinite(off)
      continue;
    end
    on = round(on);
    off = round(off);
    if off <= on
      continue;
    end
    segment = signal(on:off);
    baseline = linspace(segment(1), segment(end), numel(segment))';
    centred = segment - baseline;
    rs(k) = max(max(centred), 0);
    ss(k) = max(-min(centred), 0);
  end
  rAmp = median(rs, 'omitnan');
  sAmp = median(ss, 'omitnan');
end
%=============================================================================
