%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% RESULT = ECGLAB.LEADS(X) derives the missing standard leads, measures the
% frontal axis and the global intervals, and reports them beside the
% AHA/ACC/HRS normal limits.
% RESULT = ECGLAB.LEADS(X, 'Name', value, ...) sets the options.
%
%   X is an ecglab.recording carrying the limb leads I and II (ideally the
%   precordials V1 to V6 too), or a numeric matrix with one column per lead
%   whose 'Rate' in hertz and 'Leads' (the lead names) are given.
%
%   These are measurements and reference ranges, not a diagnosis. ecglab is
%   research and teaching software, not a medical device.
%
%   The six limb leads are linear combinations of I and II: III = II - I,
%   aVR = -(I + II)/2, aVL = I - II/2, aVF = II - I/2. A lead already present is
%   kept as is; only a missing one is derived.
%
%   The frontal QRS axis is atan2 of the net QRS area in aVF against that in I,
%   in degrees, labelled by quadrant: 'normal' -30 to +90, 'left' below -30,
%   'right' +90 to +180, 'extreme' beyond -90. The net area is the signal
%   integrated over the global QRS window with the isoelectric line removed,
%   summed over the beats.
%
%   The global PR, QRS and QT are measured on the fused leads (ecglab.delineate
%   with 'Lead' 'all'), the AHA rule: the onset is the earliest across leads and
%   the offset the latest. The reported interval is the median over the beats.
%   The corrected QT is computed four ways from the global QT and median RR
%   (RR in seconds, QT in ms): Bazett QT/sqrt(RR), Fridericia QT/RR^(1/3),
%   Framingham QT + 154(1 - RR), Hodges QT + 1.75(HR - 60) with HR = 60/RR.
%
%   When the precordials are present the Sokolow-Lyon voltage is reported: S in
%   V1 plus the larger of R in V5 and R in V6, in mV, and whether it exceeds
%   3.5 mV (the LVH voltage criterion).
%
%   On this build a ten second twelve-lead record at 500 Hz is measured in about
%   0.4 s, dominated by the delineation.
%
%   Options (name and value, matched without regard to case):
%     'Rate'    the sampling rate in hertz, required when X is a matrix.
%     'Leads'   the lead names, a cellstr with one per column, required when X
%               is a matrix.
%     'Sex'     'male' (default) or 'female', which picks the QTc normal limit
%               (450 ms for men, 460 ms for women).
%     'Beats'   a beats struct from ecglab.detect to hang the delineation on;
%               when absent the beats are detected with the default method.
%     'Method'  the detector used when 'Beats' is absent.
%
%   RESULT is a struct: kind 'ecglab.leads'; derived (an ecglab.recording with
%   the standard leads, III and the augmented ones filled in from I and II);
%   axis (degrees and label); intervals (global pr, qrs, qt in ms); qtc (bazett,
%   fridericia, framingham, hodges in ms); heartRate (bpm); sokolowLyon (sV1,
%   rV5, rV6, amplitude in mV, exceeds; only when the precordials are present);
%   and normal (the AHA/ACC/HRS ranges with an inRange flag per measurement).
%
%   Example:
%     recording = ecglab.simulate('Seconds', 20, 'Rate', 500, 'Leads', 12);
%     result = ecglab.leads(recording);
%     result.axis.degrees
%
%   See also ecglab.delineate, ecglab.simulate, ecglab.detect.
function result = leads(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Rate', [], 'Leads', [], 'Sex', 'male', 'Beats', [], ...
  'Method', []);
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % The signal matrix, its rate and the lead names, from a recording or from a
  % matrix with its Rate and Leads given.
  [samples, rate, names] = ecgLabLeadsInput(X, options);
  %===========================================================================
  % The derived recording: the six limb leads always, plus whatever precordials
  % are present, every already-present lead kept untouched.
  derived = ecgLabLeadsDerive(samples, rate, names);
  %===========================================================================
  % The beats the delineation hangs on, detected on the derived recording unless
  % given, so intervals and axis share the same beats.
  beats = ecgLabLeadsBeats(derived, options);
  %===========================================================================
  % Delineate over all leads: 'Lead' 'all' fuses them to the earliest onset and
  % latest offset, the global boundary the AHA measures on.
  waves = ecglab.delineate(derived, 'Lead', 'all', 'Beats', beats);
  %===========================================================================
  % The global intervals, the median over the beats, in milliseconds.
  pr = median(waves.intervals.pr, 'omitnan');
  qrs = median(waves.intervals.qrs, 'omitnan');
  qt = median(waves.intervals.qt, 'omitnan');
  % The representative RR and heart rate from the same beats, for the rate
  % correction below.
  rr = median(beats.rr, 'omitnan');
  heartRate = 60 / rr;
  qtc = ecgLabLeadsQtc(qt, rr);
  %===========================================================================
  % The frontal axis from the net QRS area in I and aVF of the derived
  % recording, over the fused QRS windows.
  axis = ecgLabLeadsAxis(derived, waves);
  %===========================================================================
  result = struct();
  result.kind = 'ecglab.leads';
  result.derived = derived;
  result.axis = axis;
  result.intervals = struct('pr', pr, 'qrs', qrs, 'qt', qt);
  result.qtc = qtc;
  result.heartRate = heartRate;
  %===========================================================================
  % Sokolow-Lyon only when the precordials are present (S in V1, R in V5/V6);
  % the field is absent, not NaN, for a limb-only recording.
  sokolow = ecgLabLeadsSokolow(derived, waves);
  if ~isempty(sokolow)
    result.sokolowLyon = sokolow;
  end
  %===========================================================================
  % The normal ranges and the inRange flag per measurement.
  result.normal = ecgLabLeadsNormal(pr, qrs, qtc.bazett, axis, options.Sex);
end
%=============================================================================
