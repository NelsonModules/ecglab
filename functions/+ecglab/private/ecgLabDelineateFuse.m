%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function fused = ecgLabDelineateFuse(perLeadSample)
  % Fuse per-lead wave marks into global marks (AHA rule). Onsets (Pon, QRSon,
  % Ton) take the earliest across leads, offsets (Poff, QRSoff, J, Toff) the
  % latest, and peaks (Ppeak, Q, R, S, Tpeak) the median of the leads that saw
  % the wave. An all-NaN column stays NaN.
  %
  % PERLEADSAMPLE is a 1 x L cell of K x 12 matrices. FUSED is K x 12.
  L = numel(perLeadSample);
  [K, C] = size(perLeadSample{1});
  % Stack the leads into a K x 12 x L array so each fiducial reduces across the
  % third dimension at once.
  stack = nan(K, C, L);
  for index = 1:L
    stack(:, :, index) = perLeadSample{index};
  end
  % S (column 7) is a peak, not a boundary, so it goes with the peak group and
  % takes the median, not the offset group's latest mark.
  onsetCols = [1, 4, 10];
  offsetCols = [3, 8, 9, 12];
  peakCols = [2, 5, 6, 7, 11];
  fused = nan(K, C);
  % omitnan: a lead that missed a wave does not drag a boundary to NaN.
  fused(:, onsetCols) = min(stack(:, onsetCols, :), [], 3, 'omitnan');
  fused(:, offsetCols) = max(stack(:, offsetCols, :), [], 3, 'omitnan');
  fused(:, peakCols) = round(median(stack(:, peakCols, :), 3, 'omitnan'));
  % An all-NaN slice stays NaN (the absent outcome), with no sentinel.
end
%=============================================================================
