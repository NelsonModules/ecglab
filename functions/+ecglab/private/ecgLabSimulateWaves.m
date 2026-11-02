%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function waves = ecgLabSimulateWaves(times, rate, samplesCount, angles, ...
  bBeat, hasP)
  % The twelve wave boundaries, as samples, one row per beat in the order
  % Pon Ppeak Poff QRSon Q R S QRSoff J Ton Tpeak Toff.
  %
  % Each wave peak is at its Gaussian centre; onset and offset are one Gaussian
  % width away. R is the phase reference at angle zero and J the end of the
  % QRS. A boundary before R scales its phase by the preceding RR, one after R
  % by the following RR.
  %
  % One width, not the Gaussian tail, so the boundaries match the textbook
  % intervals a delineator is scored against (at 60 bpm: PR 147, QRS 117,
  % QT 372 ms). The P boundaries of a beat with no P are NaN (the model's
  % "absent").
  boundary = 1.0;
  beatCount = numel(times);
  previous = [times(2) - times(1); diff(times)];
  following = [diff(times); times(beatCount) - times(beatCount - 1)];
  waves = zeros(beatCount, 12);
  thetaP = angles(1);
  thetaQ = angles(2);
  thetaS = angles(4);
  thetaT = angles(5);
  widthP = bBeat(1, 1);
  widthT = bBeat(1, 5);
  for index = 1:beatCount
    wq = bBeat(index, 2);
    ws = bBeat(index, 4);
    angle = [thetaP - boundary * widthP, thetaP, thetaP + boundary * widthP, ...
    thetaQ - boundary * wq, thetaQ, 0, thetaS, thetaS + boundary * ws, ...
    thetaS + boundary * ws, thetaT - boundary * widthT, thetaT, ...
    thetaT + boundary * widthT];
    scale = following(index) * ones(1, 12);
    scale(angle < 0) = previous(index);
    second = times(index) + angle / (2 * pi) .* scale;
    sample = min(max(round(second * rate) + 1, 1), samplesCount);
    if ~hasP(index)
      sample(1:3) = NaN;
    end
    waves(index, :) = sample;
  end
end
%=============================================================================
