%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function recording = simulate(varargin)
  % RECORDING = ECGLAB.SIMULATE() returns a one minute, one lead synthetic
  % electrocardiogram whose truth is known exactly.
  %
  % RECORDING = ECGLAB.SIMULATE('Name', value, ...) sets the model. The
  % recording is an ecglab.recording with info.format 'simulated', its
  % annotations filled from the truth, and a RECORDING.truth struct with the
  % planted beats, RR series, wave boundaries, beat classes and rhythm.
  %
  % The morphology is the phase domain model of McSharry, Clifford, Tarassenko
  % and Smith (IEEE TBME 50(3):289-294, 2003): each beat is a sum of five
  % Gaussians of the phase theta at the angles -pi/3, -pi/12, 0, pi/12, pi/2 for
  % P, Q, R, S, T. It is evaluated in closed form (phase from the beat times by
  % cumsum and interp1, the Gaussian sum over the whole vector), then scaled so
  % the normal R peak is 'Amplitude' millivolts.
  %
  % The RR series is the paper's bimodal spectrum: Gaussian peaks at 0.1 Hz and
  % 0.25 Hz, realised by inverse FFT and rescaled to the requested mean and spread.
  %
  % Options (name and value, case insensitive):
  %   'Seconds'           length in seconds (default 60).
  %   'Rate'              sampling rate in hertz (default 360).
  %   'HeartRate'         mean heart rate in bpm (default 60).
  %   'HeartRateStd'      heart rate spread in bpm (default 1).
  %   'Amplitude'         normal R peak in mV on lead II (default 1.0).
  %   'Noise'             white noise RMS in mV (default 0).
  %   'Baseline'          baseline wander amplitude in mV (default 0).
  %   'BaselineFrequency' baseline wander frequency in Hz (default 0.2).
  %   'Mains'             mains hum amplitude in mV (default 0).
  %   'MainsFrequency'    mains frequency in Hz (default 60).
  %   'Ectopic'           fraction of beats made premature ventricular
  %                       (default 0).
  %   'Fibrillation'      true makes the whole record atrial fibrillation
  %                       (default false).
  %   'Leads'             a lead count, or a cellstr of lead names
  %                       (default {'II'}).
  %   'Seed'              integer seed for reproducibility (default [], none).
  %
  % RECORDING.truth has: beats (R peak sample, 1-based, K x 1), rr (seconds,
  % K x 1, NaN on the first), waves (K x 12 samples in the data model order
  % Pon Ppeak Poff QRSon Q R S QRSoff J Ton Tpeak Toff, NaN for an absent P),
  % classes (K x 1 char N or V), rhythm (N or AFIB) and settings.
  %
  % Example:
  %   recording = ecglab.simulate('Seconds', 30, 'Ectopic', 0.1, 'Seed', 1);
  %
  % See also ecglab.detect, ecglab.delineate, ecglab.classify.
  nargoutchk(0, 1);
  defaults = struct('Seconds', 60, 'Rate', 360, 'HeartRate', 60, ...
  'HeartRateStd', 1, 'Amplitude', 1.0, 'Noise', 0, 'Baseline', 0, ...
  'BaselineFrequency', 0.2, 'Mains', 0, 'MainsFrequency', 60, ...
  'Ectopic', 0, 'Fibrillation', false, 'Leads', 'II', 'Seed', []);
  options = ecgLabOptions(defaults, varargin);
  ecgLabSimulateCheck(options);
  [leadNames, leadGains] = ecgLabSimulateLeads(options.Leads);
  leadCount = numel(leadNames);
  rate = double(options.Rate);
  samplesCount = round(double(options.Seconds) * rate);
  if samplesCount < 2
    error('ecglab:badSecondsRecordingTooShortHold', 'The recording is too short to hold a beat.');
  end
  t = (0:samplesCount - 1)' / rate;
  %===========================================================================
  % Seed the generator in one region so the same seed gives the same recording,
  % and restore the global generator afterwards (the try restores it on error).
  restore = ~isempty(options.Seed);
  if restore
    savedState = rng();
    rng(double(options.Seed));
  end
  try
    [times, classes, hasP, isV, rhythm] = ecgLabSimulatePlan(options, rate);
    beatCount = numel(times);
    %=========================================================================
    % Per-beat morphology: fixed angles; amplitudes and widths vary only for
    % ectopic beats (no P, a wider and taller QRS, an inverted T).
    angles = [-pi / 3, -pi / 12, 0, pi / 12, pi / 2];
    aBase = [1.2, -5, 30, -7.5, 0.75];
    bBase = [0.25, 0.1, 0.1, 0.1, 0.4];
    aBeat = repmat(aBase, beatCount, 1);
    bBeat = repmat(bBase, beatCount, 1);
    aBeat(~hasP, 1) = 0;
    if any(isV)
      aBeat(isV, 2:4) = aBeat(isV, 2:4) * 1.5;
      bBeat(isV, 2:4) = bBeat(isV, 2:4) * 3;
      aBeat(isV, 5) = -aBeat(isV, 5);
    end
    %=========================================================================
    % The phase of every sample from the beat times: each R peak is one turn
    % apart, linear between them, and a sample's beat is the nearest R. A sample
    % outside the first or last beat stays on the baseline.
    beatPhase = 2 * pi * (0:beatCount - 1)';
    phi = interp1(times, beatPhase, t, 'linear', 'extrap');
    turn = round(phi / (2 * pi));
    beatIndex = turn + 1;
    valid = beatIndex >= 1 & beatIndex <= beatCount;
    theta = phi - 2 * pi * turn;
    gather = beatIndex;
    gather(~valid) = 1;
    morphology = zeros(samplesCount, 1);
    for wave = 1:5
      amplitude = aBeat(gather, wave);
      width = bBeat(gather, wave);
      delta = theta - angles(wave);
      morphology = morphology + amplitude .* exp(-(delta .^ 2) ./ ...
      (2 * width .^ 2));
    end
    morphology(~valid) = 0;
    % Scale so the normal R peak is the requested amplitude, using the peak of
    % one normal beat on a fine phase grid as the reference.
    grid = linspace(-pi, pi, 4001)';
    reference = zeros(size(grid));
    for wave = 1:5
      reference = reference + aBase(wave) * ...
      exp(-((grid - angles(wave)) .^ 2) / (2 * bBase(wave) ^ 2));
    end
    morphology = morphology * (double(options.Amplitude) / max(reference));
    % Atrial fibrillation replaces the P wave with a fine f-wave at about 6 Hz.
    if options.Fibrillation
      morphology = morphology + 0.05 * sin(2 * pi * 6 * t);
    end
    %=========================================================================
    % Spread the morphology over the leads by the gain table, then add
    % artifacts: baseline wander and mains hum shared by every lead, white
    % noise independent per lead.
    samples = morphology * leadGains;
    if options.Baseline ~= 0
      samples = samples + double(options.Baseline) * ...
      sin(2 * pi * double(options.BaselineFrequency) * t) * ones(1, leadCount);
    end
    if options.Mains ~= 0
      samples = samples + double(options.Mains) * ...
      sin(2 * pi * double(options.MainsFrequency) * t) * ones(1, leadCount);
    end
    if options.Noise > 0
      samples = samples + double(options.Noise) * ...
      randn(samplesCount, leadCount);
    end
  catch err
    if restore
      rng(savedState);
    end
    rethrow(err);
  end
  if restore
    rng(savedState);
  end
  %===========================================================================
  % The truth: the R peak sample, the realised RR series, the wave boundaries
  % from the phase angles, the classes and the rhythm.
  beats = min(max(round(times * rate) + 1, 1), samplesCount);
  rr = [NaN; diff(times)];
  waves = ecgLabSimulateWaves(times, rate, samplesCount, angles, bBeat, hasP);
  %===========================================================================
  info = struct('name', 'simulated', 'source', 'ecglab.simulate', ...
  'format', 'simulated');
  recording = ecgLabRecording(samples, rate, leadNames, ...
  repmat({'mV'}, 1, leadCount), info);
  % Annotations from the truth: a rhythm mark at the first sample, then one beat
  % mark per R carrying its class.
  annSample = [1; beats];
  annSymbol = ['+'; classes];
  annAux = [{['(', rhythm]}; repmat({''}, beatCount, 1)];
  recording.annotations = ecgLabAnnotations(annSample, annSymbol, [], [], ...
  zeros(beatCount + 1, 1), annAux, rate);
  recording.truth = struct('beats', beats, 'rr', rr, 'waves', waves, ...
  'classes', classes, 'rhythm', rhythm, 'settings', options);
end
%=============================================================================
