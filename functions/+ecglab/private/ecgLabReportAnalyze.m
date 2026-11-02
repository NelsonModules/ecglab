%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function analysis = ecgLabReportAnalyze(recording)
  % Turn a recording into the analysis the report renders: ecglab.analyze when
  % present, else a fallback of individual functions, as kind 'ecglab.analysis'.
  privateDir = fileparts(nfilename('fullpath'));
  packageDir = fileparts(privateDir);
  if isfile([packageDir, '/analyze.m'])
    analysis = ecglab.analyze(recording);
    return;
  end
  %===========================================================================
  % The fallback. Each measurement is attempted; on failure the field is left
  % empty and the reason kept, so the report can say "not available" with it.
  analysis = struct();
  analysis.kind = 'ecglab.analysis';
  analysis.recording = recording;
  analysis.beats = [];
  analysis.quality = [];
  analysis.waves = [];
  analysis.classes = [];
  analysis.rhythm = [];
  analysis.hrv = [];
  analysis.leads = [];
  reasons = struct();
  %===========================================================================
  % Beats first: delineation, classification, rhythm and HRV all share this one
  % detection rather than each detecting again.
  beats = [];
  try
    beats = ecglab.detect(recording);
    analysis.beats = beats;
  catch e
    reasons.beats = ecgLabReportReason(e);
  end
  %===========================================================================
  try
    analysis.quality = ecglab.quality(recording);
  catch e
    reasons.quality = ecgLabReportReason(e);
  end
  %===========================================================================
  if ~isempty(beats)
    try
      analysis.waves = ecglab.delineate(recording, 'Beats', beats);
    catch e
      reasons.waves = ecgLabReportReason(e);
    end
    try
      analysis.classes = ecglab.classify(recording, 'Beats', beats);
    catch e
      reasons.classes = ecgLabReportReason(e);
    end
    try
      analysis.rhythm = ecglab.rhythm(recording, 'Beats', beats);
    catch e
      reasons.rhythm = ecgLabReportReason(e);
    end
    try
      analysis.hrv = ecglab.hrv(recording, 'Beats', beats);
    catch e
      reasons.hrv = ecgLabReportReason(e);
    end
    try
      analysis.leads = ecglab.leads(recording, 'Beats', beats);
    catch e
      reasons.leads = ecgLabReportReason(e);
    end
  else
    % With no beats there is nothing to delineate, classify or measure.
    reasons.waves = reasons.beats;
    reasons.classes = reasons.beats;
    reasons.rhythm = reasons.beats;
    reasons.hrv = reasons.beats;
    reasons.leads = reasons.beats;
  end
  analysis.reasons = reasons;
end
%=============================================================================
function text = ecgLabReportReason(e)
  % The error message a failed analysis raised, with a default when it is empty.
  text = strtrim(e.message);
  if isempty(text)
    text = 'the measurement could not be made.';
  end
end
%=============================================================================
