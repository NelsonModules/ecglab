%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% ANALYSIS = ECGLAB.ANALYZE(X) runs the whole analysis chain on X in one call.
% ANALYSIS = ECGLAB.ANALYZE(X, 'Name', value, ...) sets the options.
%
%   X is an ecglab.recording, a file path, a 'database/record' name, or a
%   numeric matrix (one column per lead, 'Rate' in hertz given). A path is read
%   by extension: .hea/.dat (readwfdb), .edf (readedf), .csv/.txt (readcsv),
%   .ecg (readishne); a bare name is fetched with ecglab.reference.
%
%   The recording is read once and passed through the whole analysis chain.
%   ANALYSIS is one struct: kind 'ecglab.analysis'; recording (cleaned when
%   'Clean' is true, with info.cleaning kept); quality (ecglab.quality); beats
%   (ecglab.detect); waves (ecglab.delineate); classes (ecglab.classify); rhythm
%   (ecglab.rhythm); hrv (ecglab.hrv); leads (ecglab.leads, only when the limb
%   leads are present); summary (a flat struct of the headline numbers); and
%   notes (one line per analysis that did not run and why).
%
%   Each analysis is wrapped: one that cannot run leaves its field empty and
%   writes a one-line reason into ANALYSIS.notes, instead of aborting the call.
%   The only failure that stops the call is a recording that cannot be read.
%
%   ANALYZE only measures. Drawing is done by ecglab.report and the views.
%
%   The summary is a flat set of numbers: heartRate (mean, min, max in bpm);
%   rhythm (dominant per-beat label and AF burden); intervals (global PR, QRS,
%   QT in ms and QTc by the four formulas, from leads() when the limb leads are
%   present, else from the analysis lead); axis (degrees and label, only when
%   leads() ran); counts (beats per AAMI class N S V F Q); hrv (SDNN, RMSSD,
%   pNN50, LF/HF); quality (usable fraction); and provenance (recording name and
%   source, detector method, Nelson build). A value not produced is NaN (empty
%   for axis).
%
%   Options (name and value, matched without regard to case):
%     'Clean'     true (default) cleans the recording with ecglab.clean before
%                 analysing and keeps info.cleaning; false analyses it as read.
%     'Detector'  the QRS detector (default 'pantompkins'), passed to
%                 ecglab.detect as its 'Method'.
%     'Prior'     the classifier's class prior (default 'empirical', or
%                 'uniform'), passed to ecglab.classify; 'uniform' lifts the
%                 minority-class sensitivity at the cost of overall accuracy.
%     'Lead'      the lead the single-lead analyses read, a name or a column
%                 index; the default is the detector's own (MLII, II, I, V5, or
%                 the first lead).
%     'Do'        a cellstr selecting which analyses to run: any of 'quality',
%                 'detect', 'delineate', 'classify', 'rhythm', 'hrv', 'leads'.
%                 The default runs every one that applies; an analysis left out
%                 is empty with the note 'Not selected by Do.'.
%     'Rate'      the sampling rate in hertz, required when X is a numeric
%                 matrix or a CSV file with no time column.
%
%   Research software, not a medical device. ecglab is for research and
%   education. It is not a medical device and must not be used for clinical
%   diagnosis, patient monitoring, treatment decisions, or any medical purpose.
%
%   Example:
%     recording = ecglab.simulate('Seconds', 60, 'Leads', 12, 'Seed', 1);
%     analysis = ecglab.analyze(recording);
%     analysis.summary.heartRate.mean
%
%   See also ecglab.report, ecglab.detect, ecglab.delineate, ecglab.hrv.
function analysis = analyze(X, varargin)
  nargoutchk(0, 1);
  defaults = struct('Clean', true, 'Detector', 'pantompkins', 'Lead', [], ...
  'Do', [], 'Rate', [], 'Prior', 'empirical');
  options = ecgLabOptions(defaults, varargin);
  %===========================================================================
  % Read the recording. This is the one step whose failure stops the call.
  recording = ecgLabAnalyzeInput(X, options);
  steps = ecgLabAnalyzeDo(options.Do);
  detector = ecgLabAnalyzeDetector(options.Detector);
  % Validate Prior up front, so a bad value is a hard error, not a note.
  prior = ecgLabAnalyzePrior(options.Prior);
  leadArg = ecgLabAnalyzeLeadArg(options.Lead);
  %===========================================================================
  % Clean once here so every downstream analysis reads the same trace.
  % info.cleaning records what was removed.
  if ecgLabAnalyzeFlag(options.Clean, 'Clean')
    recording = ecglab.clean(recording, leadArg{:});
  end
  %===========================================================================
  analysis = struct();
  analysis.kind = 'ecglab.analysis';
  analysis.recording = recording;
  analysis.quality = [];
  analysis.beats = [];
  analysis.waves = [];
  analysis.classes = [];
  analysis.rhythm = [];
  analysis.hrv = [];
  analysis.leads = [];
  analysis.summary = struct();
  analysis.notes = struct();
  %===========================================================================
  % Detect beats once and share them: delineate, classify, rhythm and hrv all
  % need them. Detected whenever any such step runs, even if 'detect' is not
  % selected. A dead lead yields no beats; the reason is carried forward.
  needBeats = steps.detect || steps.delineate || steps.classify || ...
  steps.rhythm || steps.hrv;
  beats = [];
  beatsNote = '';
  if needBeats
    [beats, beatsNote] = ecgLabAnalyzeBeats(recording, detector, options.Lead);
  end
  %===========================================================================
  % Run each analysis when selected; otherwise leave it empty with a note. A
  % selected one that cannot run is also left empty with its reason.
  if steps.detect
    if isempty(beats)
      analysis.notes.beats = beatsNote;
    else
      analysis.beats = beats;
    end
  else
    analysis.notes.beats = 'Not selected by Do.';
  end

  if steps.quality
    try
      analysis.quality = ecglab.quality(recording, leadArg{:});
    catch err
      analysis.notes.quality = ecgLabAnalyzeReason(err);
    end
  else
    analysis.notes.quality = 'Not selected by Do.';
  end

  if steps.delineate
    if isempty(beats)
      analysis.notes.waves = ecgLabAnalyzeNoBeats(beatsNote, 'delineated');
    else
      try
        analysis.waves = ecglab.delineate(recording, 'Beats', beats, ...
        leadArg{:});
      catch err
        analysis.notes.waves = ecgLabAnalyzeReason(err);
      end
    end
  else
    analysis.notes.waves = 'Not selected by Do.';
  end

  if steps.classify
    if isempty(beats)
      analysis.notes.classes = ecgLabAnalyzeNoBeats(beatsNote, 'classified');
    else
      try
        analysis.classes = ecglab.classify(recording, 'Beats', beats, ...
        'Prior', prior, leadArg{:});
      catch err
        analysis.notes.classes = ecgLabAnalyzeReason(err);
      end
    end
  else
    analysis.notes.classes = 'Not selected by Do.';
  end

  if steps.rhythm
    if isempty(beats)
      analysis.notes.rhythm = ecgLabAnalyzeNoBeats(beatsNote, 'labelled');
    else
      try
        analysis.rhythm = ecglab.rhythm(recording, 'Beats', beats);
      catch err
        analysis.notes.rhythm = ecgLabAnalyzeReason(err);
      end
    end
  else
    analysis.notes.rhythm = 'Not selected by Do.';
  end

  if steps.hrv
    if isempty(beats)
      analysis.notes.hrv = ecgLabAnalyzeNoBeats(beatsNote, 'measured');
    else
      try
        analysis.hrv = ecglab.hrv(recording, 'Beats', beats);
      catch err
        analysis.notes.hrv = ecgLabAnalyzeReason(err);
      end
    end
  else
    analysis.notes.hrv = 'Not selected by Do.';
  end

  if steps.leads
    if ~ecgLabAnalyzeHasLimbLeads(recording)
      analysis.notes.leads = ...
      'The recording does not carry the limb leads I and II.';
    else
      try
        if isempty(beats)
          analysis.leads = ecglab.leads(recording);
        else
          analysis.leads = ecglab.leads(recording, 'Beats', beats);
        end
      catch err
        analysis.notes.leads = ecgLabAnalyzeReason(err);
      end
    end
  else
    analysis.notes.leads = 'Not selected by Do.';
  end
  %===========================================================================
  analysis.summary = ecgLabAnalyzeSummary(analysis, detector);
end
%=============================================================================
function detector = ecgLabAnalyzeDetector(given)
  % Keep the detector name as text for ecglab.detect's 'Method'; detect itself
  % refuses an unknown one.
  if ~(ischar(given) || isStringScalar(given))
    error('ecglab:badDetector', 'The detector must be a method name.');
  end
  detector = char(given);
end
%=============================================================================
function prior = ecgLabAnalyzePrior(given)
  % Validate the class prior here so a typo is a hard error; classify holds the
  % same rule.
  if ~(ischar(given) || isStringScalar(given))
    error('ecglab:badPrior', 'The Prior must be ''empirical'' or ''uniform''.');
  end
  prior = lower(char(given));
  if ~any(strcmp(prior, {'empirical', 'uniform'}))
    error('ecglab:badPrior', 'The Prior must be ''empirical'' or ''uniform''.');
  end
end
%=============================================================================
function leadArg = ecgLabAnalyzeLeadArg(lead)
  % Pass the caller's 'Lead' to the single-lead analyses. An empty lead is left
  % out so each analysis uses its own default.
  if isempty(lead)
    leadArg = {};
  else
    leadArg = {'Lead', lead};
  end
end
%=============================================================================
function value = ecgLabAnalyzeFlag(given, name)
  % A true/false option, refused unless it is one scalar.
  if ~((islogical(given) || isnumeric(given)) && isscalar(given))
    error('ecglab:badFlag', '%s must be true or false.', name);
  end
  value = logical(given);
end
%=============================================================================
function reason = ecgLabAnalyzeReason(err)
  % The note for an analysis that errored: the message it raised.
  reason = err.message;
end
%=============================================================================
function note = ecgLabAnalyzeNoBeats(beatsNote, verb)
  % The note for a beat-dependent analysis with no beats. Carry the beats
  % failure reason when there is one, else state the dependence.
  if ~isempty(beatsNote)
    note = beatsNote;
  else
    note = sprintf('No beats were available, so nothing was %s.', verb);
  end
end
%=============================================================================
