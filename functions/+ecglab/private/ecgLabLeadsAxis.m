%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function axis = ecgLabLeadsAxis(derived, waves)
  % Frontal QRS axis from the net QRS area in lead I (at 0 degrees) and aVF (at
  % +90): atan2 of the aVF area against the I area. The net area is the signal
  % over the global QRS window with the isoelectric baseline removed, summed
  % over beats.
  lowered = lower(derived.leads);
  iCol = find(strcmp(lowered, 'i'), 1);
  fCol = find(strcmp(lowered, 'avf'), 1);
  onset = waves.sample(:, 4);
  offset = waves.sample(:, 8);
  areaI = ecgLabLeadsNetArea(derived.samples(:, iCol), onset, offset);
  areaF = ecgLabLeadsNetArea(derived.samples(:, fCol), onset, offset);
  degrees = atan2d(areaF, areaI);
  axis = struct('degrees', degrees, 'label', ecgLabLeadsAxisLabel(degrees));
end
%=============================================================================
function label = ecgLabLeadsAxisLabel(degrees)
  % Quadrant label (survey 5.4). Normal -30 to +90; left below -30 to -90;
  % right above +90 to +180; extreme beyond -90. Unknown when there is no QRS.
  if ~isfinite(degrees)
    label = 'unknown';
  elseif degrees >= -30 && degrees <= 90
    label = 'normal';
  elseif degrees >= -90 && degrees < -30
    label = 'left';
  elseif degrees > 90 && degrees <= 180
    label = 'right';
  else
    label = 'extreme';
  end
end
%=============================================================================
function area = ecgLabLeadsNetArea(signal, onset, offset)
  % Median net QRS area of one lead over the beats. For each beat the signal
  % between the global QRS onset and offset is summed after subtracting the
  % straight line joining them, so a sloping baseline does not bias the area.
  % A beat missing either boundary contributes nothing.
  signal = signal(:);
  K = numel(onset);
  areas = nan(K, 1);
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
    areas(k) = sum(segment - baseline);
  end
  area = median(areas, 'omitnan');
end
%=============================================================================
