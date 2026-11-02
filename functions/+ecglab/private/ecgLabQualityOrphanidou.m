%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [ok, heartRate] = ecgLabQualityOrphanidou(beatSample, signal, rate)
  % Orphanidou et al. (2015) acceptability: heart rate 40-180, no RR over 3 s,
  % max/min RR under 2.2, and mean beat-to-template correlation above 0.66.
  % beatSample is one detector's fiducials in the window; the full signal is
  % passed so the template can reach past the window edge.
  ok = false;
  heartRate = NaN;
  beatSample = round(beatSample(:));
  if numel(beatSample) < 2
    % Fewer than two beats: no interval or template, so not acceptable.
    return;
  end
  times = (beatSample - 1) / rate;
  rr = diff(times);
  if any(rr <= 0)
    return;
  end
  heartRate = 60 / median(rr);
  rateOk = heartRate >= 40 && heartRate <= 180;
  pauseOk = max(rr) <= 3;
  ratioOk = (max(rr) / min(rr)) < 2.2;
  if ~(rateOk && pauseOk && ratioOk)
    return;
  end
  %===========================================================================
  % Template correlation. Cut each beat as a fixed +/- 125 ms window; the
  % template is their mean, and the rule reads the mean Pearson correlation.
  half = max(1, round(0.125 * rate));
  keep = beatSample - half >= 1 & beatSample + half <= numel(signal);
  fiducials = beatSample(keep);
  if numel(fiducials) < 2
    return;
  end
  offsets = (-half:half)';
  index = fiducials(:)' + offsets;
  beatsMatrix = double(signal(index));
  template = mean(beatsMatrix, 2);
  correlations = ecgLabQualityTemplateCorr(beatsMatrix, template);
  meanCorrelation = mean(correlations);
  templateOk = meanCorrelation > 0.66;
  ok = rateOk && pauseOk && ratioOk && templateOk;
end
%=============================================================================
function correlations = ecgLabQualityTemplateCorr(beatsMatrix, template)
  % Pearson correlation of each column of beatsMatrix to the template: centre
  % both, divide the column dot product by the product of the norms.
  centredBeats = beatsMatrix - mean(beatsMatrix, 1);
  centredTemplate = template - mean(template);
  numerator = sum(centredBeats .* centredTemplate, 1);
  beatNorm = sqrt(sum(centredBeats .^ 2, 1));
  templateNorm = sqrt(sum(centredTemplate .^ 2));
  denominator = beatNorm * templateNorm;
  correlations = zeros(1, size(beatsMatrix, 2));
  valid = denominator > 0;
  correlations(valid) = numerator(valid) ./ denominator(valid);
end
%=============================================================================
