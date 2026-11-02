%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function summary = ecgLabAnalyzeSummary(analysis, detector)
  % The flat set of headline numbers a report prints, read from the analyses
  % that ran. A number an analysis did not produce is NaN (empty for the axis),
  % so a missing measurement is distinct from a measured zero.
  summary = struct();
  summary.heartRate = ecgLabAnalyzeHeartRate(analysis.beats);
  summary.rhythm = ecgLabAnalyzeRhythm(analysis.rhythm);
  summary.intervals = ecgLabAnalyzeIntervals(analysis.leads, analysis.waves);
  summary.axis = ecgLabAnalyzeAxis(analysis.leads);
  summary.counts = ecgLabAnalyzeCounts(analysis.classes);
  summary.hrv = ecgLabAnalyzeHrv(analysis.hrv);
  summary.quality = ecgLabAnalyzeQuality(analysis.quality);
  summary.provenance = ecgLabAnalyzeProvenance(analysis.recording, detector);
end
%=============================================================================
function hr = ecgLabAnalyzeHeartRate(beats)
  % Mean heart rate and range from the RR series. The first RR is NaN and left
  % out; min and max are the slowest and fastest instantaneous rate.
  hr = struct('mean', NaN, 'min', NaN, 'max', NaN);
  if isempty(beats)
    return;
  end
  rr = beats.rr(isfinite(beats.rr));
  if isempty(rr)
    return;
  end
  hr.mean = 60 / mean(rr);
  instant = 60 ./ rr;
  hr.min = min(instant);
  hr.max = max(instant);
end
%=============================================================================
function out = ecgLabAnalyzeRhythm(rhythm)
  % The dominant rhythm label (the one most beats carry) and the AF burden,
  % carried through from ecglab.rhythm unchanged.
  out = struct('label', '', 'afBurden', NaN);
  if isempty(rhythm)
    return;
  end
  out.afBurden = rhythm.afBurden;
  out.label = ecgLabAnalyzeDominant(rhythm.perBeat);
end
%=============================================================================
function label = ecgLabAnalyzeDominant(perBeat)
  % The most frequent label among the per-beat labels (their mode).
  label = '';
  if isempty(perBeat)
    return;
  end
  if ~iscell(perBeat)
    perBeat = cellstr(perBeat);
  end
  distinct = unique(perBeat);
  best = 0;
  for index = 1:numel(distinct)
    count = sum(strcmp(distinct{index}, perBeat));
    if count > best
      best = count;
      label = distinct{index};
    end
  end
end
%=============================================================================
function intervals = ecgLabAnalyzeIntervals(leads, waves)
  % Global PR, QRS, QT and the four corrected QTs. Taken from the twelve-lead
  % leads() measurement when it ran, else the median over the single-lead
  % delineation so a one-lead record still reports an interval.
  intervals = struct('pr', NaN, 'qrs', NaN, 'qt', NaN, ...
  'qtc', ecgLabAnalyzeQtcEmpty());
  if ~isempty(leads)
    intervals.pr = leads.intervals.pr;
    intervals.qrs = leads.intervals.qrs;
    intervals.qt = leads.intervals.qt;
    intervals.qtc = ecgLabAnalyzeQtc(leads.qtc.bazett, ...
    leads.qtc.fridericia, leads.qtc.framingham, leads.qtc.hodges);
    return;
  end
  if ~isempty(waves)
    intervals.pr = median(waves.intervals.pr, 'omitnan');
    intervals.qrs = median(waves.intervals.qrs, 'omitnan');
    intervals.qt = median(waves.intervals.qt, 'omitnan');
    intervals.qtc = ecgLabAnalyzeQtc( ...
    median(waves.intervals.qtc.bazett, 'omitnan'), ...
    median(waves.intervals.qtc.fridericia, 'omitnan'), ...
    median(waves.intervals.qtc.framingham, 'omitnan'), ...
    median(waves.intervals.qtc.hodges, 'omitnan'));
  end
end
%=============================================================================
function qtc = ecgLabAnalyzeQtc(bazett, fridericia, framingham, hodges)
  qtc = struct('bazett', bazett, 'fridericia', fridericia, ...
  'framingham', framingham, 'hodges', hodges);
end
%=============================================================================
function qtc = ecgLabAnalyzeQtcEmpty()
  qtc = ecgLabAnalyzeQtc(NaN, NaN, NaN, NaN);
end
%=============================================================================
function axis = ecgLabAnalyzeAxis(leads)
  % The frontal axis, only when the twelve-lead measurement ran; empty
  % otherwise, since a single lead has no frontal plane.
  if isempty(leads)
    axis = [];
    return;
  end
  axis = struct('degrees', leads.axis.degrees, 'label', leads.axis.label);
end
%=============================================================================
function counts = ecgLabAnalyzeCounts(classes)
  % Beats per AAMI class in the order N S V F Q. A class with no beats is zero;
  % every count is NaN when no classification ran.
  names = {'N', 'S', 'V', 'F', 'Q'};
  counts = struct();
  if isempty(classes)
    for index = 1:numel(names)
      counts.(names{index}) = NaN;
    end
    return;
  end
  label = classes.label;
  for index = 1:numel(names)
    counts.(names{index}) = sum(label == names{index});
  end
end
%=============================================================================
function out = ecgLabAnalyzeHrv(hrv)
  % The four headline variability numbers: SDNN, RMSSD and pNN50 from the time
  % domain, and the LF/HF ratio from the frequency domain.
  out = struct('sdnn', NaN, 'rmssd', NaN, 'pnn50', NaN, 'lfhf', NaN);
  if isempty(hrv)
    return;
  end
  out.sdnn = hrv.time.sdnn;
  out.rmssd = hrv.time.rmssd;
  out.pnn50 = hrv.time.pnn50;
  out.lfhf = hrv.frequency.lfhf;
end
%=============================================================================
function out = ecgLabAnalyzeQuality(quality)
  % The usable fraction of the record, the one quality number a report prints.
  out = struct('usableFraction', NaN);
  if isempty(quality)
    return;
  end
  out.usableFraction = quality.usableFraction;
end
%=============================================================================
function out = ecgLabAnalyzeProvenance(recording, detector)
  % Provenance: the record's name and source, the detector, and the Nelson
  % build, so the measurement can be reproduced.
  info = recording.info;
  name = '';
  if isfield(info, 'name')
    name = info.name;
  end
  source = '';
  if isfield(info, 'source')
    source = info.source;
  end
  out = struct('name', name, 'source', source, 'detector', detector, ...
  'nelson', version());
end
%=============================================================================
