%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [features, featureNames, report] = ecgLabClassifyFeatures(signal, ...
  rate, beats, options)
  % Build the feature vector of every beat, the same way for the fit and for
  % classify since both call this. Two families (de Chazal 2004): the RR rhythm
  % around the beat and the shape of the beat itself.
  %
  %   prevRR              interval before the beat, in seconds.
  %   nextRR              interval after the beat, in seconds.
  %   prevRR_over_avgRR   prevRR over the local average RR (flags a premature beat).
  %   nextRR_over_avgRR   nextRR over the local average RR (the post-beat pause).
  %   avgRR               average RR over Context beats each side.
  %   qrsWidth            QRS width in ms, from the derivative energy spread near R.
  %   morph01..morphL     beat segment, baseline removed, amplitude normalised,
  %                       resampled to MorphLength points.
  %
  % SIGNAL is one lead as a column, RATE its sampling rate, BEATS a struct with
  % a sample field or a vector of R-peak indices, OPTIONS carries Before, After,
  % MorphLength and Context. FEATURES is K by 6 + MorphLength, FEATURENAMES names
  % each column, and REPORT counts beats whose window was padded at a record end.
  signal = double(signal(:));
  N = numel(signal);
  rate = double(rate);
  sample = ecgLabClassifyFeatureSamples(beats);
  K = numel(sample);
  [before, after, morphLength, context] = ecgLabClassifyFeatureParams(options);
  %===========================================================================
  % The column names, fixed in order so a stored model and a fresh extraction
  % line their columns up by position and by name.
  morphNames = cell(1, morphLength);
  for index = 1:morphLength
    morphNames{index} = sprintf('morph%02d', index);
  end
  featureNames = [{'prevRR', 'nextRR', 'prevRR_over_avgRR', ...
  'nextRR_over_avgRR', 'avgRR', 'qrsWidth'}, morphNames];
  F = 6 + morphLength;
  report = struct('total', K, 'padded', 0);
  if K == 0
    features = zeros(0, F);
    return;
  end
  %===========================================================================
  % The RR block. Beat times come from the samples. The first and last beats
  % have a missing RR, filled with the local average rather than left NaN.
  time = (sample - 1) / rate;
  rr = [NaN; diff(time)];
  finiteRr = rr(isfinite(rr));
  if isempty(finiteRr)
    % A single beat has no interval; a nominal 0.8 s (75 bpm) keeps the features
    % finite.
    nominal = 0.8;
  else
    nominal = median(finiteRr);
  end
  rrFilled = rr;
  rrFilled(~isfinite(rrFilled)) = nominal;
  % The local average over Context beats each side, as a moving sum on the
  % cumulative sum; the window shrinks at the ends and is divided by its width.
  cumulative = [0; cumsum(rrFilled)];
  k = (1:K)';
  lo = max(1, k - context);
  hi = min(K, k + context);
  avgRr = (cumulative(hi + 1) - cumulative(lo)) ./ (hi - lo + 1);
  prevRr = rr;
  nextRr = [rr(2:end); NaN];
  missingPrev = ~isfinite(prevRr);
  missingNext = ~isfinite(nextRr);
  prevRr(missingPrev) = avgRr(missingPrev);
  nextRr(missingNext) = avgRr(missingNext);
  ratio = prevRr ./ max(avgRr, eps);
  % The interval after the beat over the local average, the post-beat pause,
  % which separates a ventricular ectopic (compensatory pause) from a
  % supraventricular one.
  nextRatio = nextRr ./ max(avgRr, eps);
  %===========================================================================
  % The morphology block. Each beat's window is gathered as one matrix by
  % broadcasting the offset range over the beat samples. A window running off an
  % end is clamped (edge padding) so no beat is dropped; REPORT counts those.
  beforeN = round(before * rate);
  afterN = round(after * rate);
  segmentLength = beforeN + afterN + 1;
  offsets = -beforeN:afterN;
  indices = sample + offsets;
  outside = indices < 1 | indices > N;
  report.padded = sum(any(outside, 2));
  indices = min(max(indices, 1), N);
  segment = signal(indices);
  % Baseline removal: subtract the mean of the first 20 ms of the window, so a
  % wandering baseline does not change the shape.
  baselineN = max(1, round(0.02 * rate));
  baselineN = min(baselineN, segmentLength);
  baseline = mean(segment(:, 1:baselineN), 2);
  segment = segment - baseline;
  % The QRS width: the RMS spread of the derivative energy within 120 ms of the
  % R peak, with the energy normalised to sum to one so the measure is scale
  % free. A wide complex spreads its energy away from R, a narrow one keeps it close.
  slope = diff(segment, 1, 2);
  energy = slope .^ 2;
  centre = beforeN;
  widthN = max(1, round(0.12 * rate));
  lo = max(1, centre - widthN);
  hi = min(size(energy, 2), centre + widthN);
  windowEnergy = energy(:, lo:hi);
  windowEnergy = windowEnergy ./ max(sum(windowEnergy, 2), eps);
  offset = ((lo:hi) - centre)';
  qrsWidth = sqrt(windowEnergy * (offset .^ 2)) / rate * 1000;
  % Amplitude normalisation: divide by the largest absolute deflection so shape,
  % not lead gain, is what the discriminant sees. A flat segment keeps a scale of one.
  amplitude = max(abs(segment), [], 2);
  amplitude(amplitude < eps) = 1;
  segment = segment ./ amplitude;
  % Resample to a fixed length with interp1. It works down columns, so the
  % segment is transposed in and the result transposed back to one row per beat.
  queryPoints = linspace(1, segmentLength, morphLength)';
  morphology = interp1((1:segmentLength)', segment', queryPoints)';
  %===========================================================================
  features = [prevRr, nextRr, ratio, nextRatio, avgRr, qrsWidth, morphology];
end
%=============================================================================
function sample = ecgLabClassifyFeatureSamples(beats)
  if isstruct(beats)
    if ~isfield(beats, 'sample')
      error('ecglab:noSampleBeatsCarrySampleField', 'The beats must carry a sample field.');
    end
    sample = round(double(beats.sample(:)));
  elseif isnumeric(beats)
    sample = round(double(beats(:)));
  else
    error('ecglab:badBeatsBeatsStructSampleField', 'The beats must be a struct with a sample field or a vector of samples.');
  end
end
%=============================================================================
function [before, after, morphLength, context] = ...
  ecgLabClassifyFeatureParams(options)
  % The four window parameters, read from the options struct, so the extraction
  % is tied to the numbers the model was trained with.
  before = double(options.Before);
  after = double(options.After);
  morphLength = round(double(options.MorphLength));
  context = round(double(options.Context));
  if ~(before > 0) || ~(after > 0)
    error('ecglab:badWindowBeforeAfterPositiveNumbers', 'Before and After must be positive numbers of seconds.');
  end
  if morphLength < 2
    error('ecglab:badMorphLength', 'MorphLength must be at least two points.');
  end
  if context < 1
    error('ecglab:badContext', 'Context must be at least one beat.');
  end
end
%=============================================================================
