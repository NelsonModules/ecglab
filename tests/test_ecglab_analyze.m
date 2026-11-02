%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ecglab.analyze runs the whole analysis chain in one call and returns one
% struct with a summary. Checks the links, the summary numbers against the
% underlying functions, the Do option, broken links, file dispatch and errors.
rate = 360;
%=============================================================================
% A simulated twelve-lead record so every analysis applies, including the
% twelve-lead leads() measurement.
rec12 = ecglab.simulate('Seconds', 60, 'Rate', rate, 'HeartRate', 72, ...
'Ectopic', 0.1, 'Leads', 12, 'Seed', 7);
analysis = ecglab.analyze(rec12);
assert_isequal(analysis.kind, 'ecglab.analysis');
assert_isequal(analysis.recording.kind, 'ecglab.recording');
assert_isequal(analysis.quality.kind, 'ecglab.quality');
assert_isequal(analysis.beats.kind, 'ecglab.beats');
assert_isequal(analysis.waves.kind, 'ecglab.waves');
assert_isequal(analysis.classes.kind, 'ecglab.classes');
assert_isequal(analysis.rhythm.kind, 'ecglab.rhythm');
assert_isequal(analysis.hrv.kind, 'ecglab.hrv');
assert_isequal(analysis.leads.kind, 'ecglab.leads');
assert_istrue(isstruct(analysis.summary));
% The Prior option passes through to classify: default is empirical, uniform
% reaches classify, and a bad Prior is a hard error.
assert_isequal(analysis.classes.prior, 'empirical');
uniformAnalysis = ecglab.analyze(rec12, 'Prior', 'uniform');
assert_isequal(uniformAnalysis.classes.prior, 'uniform');
badPriorAnalyze = false;
try
  ecglab.analyze(rec12, 'Prior', 'whatever');
catch e
  badPriorAnalyze = startsWith(e.identifier, 'ecglab:badPrior');
end
assert_istrue(badPriorAnalyze, 'a bad Prior is a hard error in analyze');
%=============================================================================
% Clean is true by default, so the cleaned recording keeps its cleaning record.
assert_istrue(isfield(analysis.recording.info, 'cleaning'));
% Clean false keeps the raw recording, so no cleaning record is attached.
rawAnalysis = ecglab.analyze(rec12, 'Clean', false);
assert_isfalse(isfield(rawAnalysis.recording.info, 'cleaning'));
%=============================================================================
% The summary numbers equal the underlying functions called directly on the
% same beats. Detect once and feed the same beats to each function.
cleaned = ecglab.clean(rec12);
beats = ecglab.detect(cleaned, 'Method', 'pantompkins');
meanHr = 60 / mean(beats.rr, 'omitnan');
fprintf('summary HR %.3f bpm, direct %.3f bpm\n', ...
analysis.summary.heartRate.mean, meanHr);
assert_istrue(abs(analysis.summary.heartRate.mean - meanHr) < 1);
% The class counts equal ecglab.classify's, class by class.
classes = ecglab.classify(cleaned, 'Beats', beats);
for c = 'NSVFQ'
  direct = sum(classes.label == c);
  fprintf('count %s: summary %d direct %d\n', c, ...
  analysis.summary.counts.(c), direct);
  assert_isequal(analysis.summary.counts.(c), direct);
end
% The AF burden equals ecglab.rhythm's exactly.
rhythm = ecglab.rhythm(cleaned, 'Beats', beats);
fprintf('AF burden: summary %.6f direct %.6f\n', ...
analysis.summary.rhythm.afBurden, rhythm.afBurden);
assert_isequal(analysis.summary.rhythm.afBurden, rhythm.afBurden);
% The global intervals and axis come from leads() on a twelve-lead record.
leadsResult = ecglab.leads(cleaned, 'Beats', beats);
assert_istrue(abs(analysis.summary.intervals.qt - leadsResult.intervals.qt) < 1e-6);
assert_istrue(abs(analysis.summary.intervals.qtc.bazett - ...
leadsResult.qtc.bazett) < 1e-6);
assert_istrue(abs(analysis.summary.axis.degrees - leadsResult.axis.degrees) < 1e-6);
% The HRV headline numbers are the Task Force ones.
hrv = ecglab.hrv(cleaned, 'Beats', beats);
assert_istrue(abs(analysis.summary.hrv.sdnn - hrv.time.sdnn) < 1e-9);
assert_istrue(abs(analysis.summary.hrv.rmssd - hrv.time.rmssd) < 1e-9);
% The usable fraction is the quality's.
q = ecglab.quality(cleaned);
assert_istrue(abs(analysis.summary.quality.usableFraction - ...
q.usableFraction) < 1e-9);
% The provenance carries the detector and the Nelson build.
assert_isequal(analysis.summary.provenance.detector, 'pantompkins');
assert_isequal(analysis.summary.provenance.nelson, version());
%=============================================================================
% 'Do' runs only the named analyses and leaves the rest empty with a note in
% analysis.notes.
partial = ecglab.analyze(rec12, 'Do', {'detect', 'hrv'});
assert_isequal(partial.beats.kind, 'ecglab.beats');
assert_isequal(partial.hrv.kind, 'ecglab.hrv');
assert_istrue(isempty(partial.quality));
assert_istrue(isempty(partial.waves));
assert_istrue(isempty(partial.classes));
assert_istrue(isempty(partial.rhythm));
assert_istrue(isempty(partial.leads));
assert_istrue(ischar(partial.notes.quality));
assert_istrue(ischar(partial.notes.waves));
assert_istrue(ischar(partial.notes.classes));
assert_istrue(ischar(partial.notes.rhythm));
assert_istrue(ischar(partial.notes.leads));
%=============================================================================
% A flat lead leaves beats and waves empty with a note and does not abort the
% call.
flat = struct('kind', 'ecglab.recording', 'rate', rate, ...
'samples', zeros(rate * 20, 1), 'leads', {{'II'}}, 'units', {{'mV'}}, ...
'seconds', 20, 'info', struct('name', 'flat', 'source', '', ...
'format', 'simulated'), 'annotations', []);
flatAnalysis = ecglab.analyze(flat);
assert_isequal(flatAnalysis.kind, 'ecglab.analysis');
assert_istrue(isempty(flatAnalysis.beats));
assert_istrue(isempty(flatAnalysis.waves));
assert_istrue(ischar(flatAnalysis.notes.beats));
assert_istrue(ischar(flatAnalysis.notes.waves));
%=============================================================================
% A single-lead record leaves leads empty with a note (no I and II for the
% frontal plane), while a twelve-lead one fills it.
recOne = ecglab.simulate('Seconds', 30, 'Rate', rate, 'Seed', 2);
oneAnalysis = ecglab.analyze(recOne);
assert_istrue(isempty(oneAnalysis.leads));
assert_istrue(ischar(oneAnalysis.notes.leads));
% Its summary axis is empty, but the intervals still come from the single-lead
% delineation.
assert_istrue(isempty(oneAnalysis.summary.axis));
assert_istrue(isfinite(oneAnalysis.summary.intervals.qt));
%=============================================================================
% Dispatch by a written file: write the record to WFDB, analyze the path, and
% check it was read (format wfdb, beats found).
base = tempname();
ecglab.writewfdb(base, recOne);
fileAnalysis = ecglab.analyze([base, '.hea']);
assert_isequal(fileAnalysis.recording.info.format, 'wfdb');
assert_istrue(~isempty(fileAnalysis.beats) && ...
numel(fileAnalysis.beats.sample) > 10);
% The same path without the extension is dispatched too.
fileAnalysis2 = ecglab.analyze(base);
assert_isequal(fileAnalysis2.recording.info.format, 'wfdb');
% Clean up the files the test wrote.
for ext = {'.hea', '.dat', '.atr'}
  f = [base, ext{1}];
  if isfile(f)
    delete(f);
  end
end
%=============================================================================
% Errors: a missing path, a bad option name, and an unknown name in 'Do' are
% each refused.
failed = false;
try
  ecglab.analyze('Z:/no/such/record.hea');
catch
  failed = true;
end
assert_istrue(failed);
failed = false;
try
  ecglab.analyze(rec12, 'NoSuchOption', 1);
catch
  failed = true;
end
assert_istrue(failed);
failed = false;
try
  ecglab.analyze(rec12, 'Do', {'detect', 'nosuchstep'});
catch
  failed = true;
end
assert_istrue(failed);
%=============================================================================
% Speed: the whole chain on a short record runs under a loose bound.
tic;
ecglab.analyze(recOne);
elapsed = toc;
fprintf('analyze of a 30 s single lead: %.2f s\n', elapsed);
assert_istrue(elapsed < 30);
%=============================================================================
