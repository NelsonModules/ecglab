%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function agreement = ecgLabValidateEpisodes(test, reference, options)
  % The 'episodes' basis of ecglab.validate: measure a rhythm detection against
  % a reference the way EC57 epicmp does (survey 5.1). TEST is an ecglab.rhythm;
  % REFERENCE is an ecglab.rhythm or a recording with rhythm marks. The scored
  % rhythm is fixed to AFIB (see the label helper).
  %
  % Reported: episode sensitivity and predictivity (episodes that overlap one
  % on the other side), duration sensitivity and predictivity (the rhythm time
  % covered), plus per-second sensitivity and specificity and Cohen's kappa.
  label = ecgLabValidateEpisodesLabel(options);
  [testAF, testSpan] = ecgLabValidateEpisodesIntervals(test, label);
  [refAF, refSpan] = ecgLabValidateEpisodesIntervals(reference, label);
  % Compare over the span both sides saw: a detection cannot be scored where it
  % had no beats, nor a reference where it had no marks.
  span = [max(testSpan(1), refSpan(1)), min(testSpan(2), refSpan(2))];
  if span(2) <= span(1)
    error('ecglab:emptyReferenceDetectionReferenceDoNot', 'The detection and the reference do not overlap in time.');
  end
  refAF = ecgLabValidateEpisodesClip(refAF, span);
  testAF = ecgLabValidateEpisodesClip(testAF, span);
  %===========================================================================
  % Episode figures: an episode counts if it overlaps at least one on the other
  % side, whatever the overlap length.
  refHit = ecgLabValidateEpisodesHits(refAF, testAF);
  detHit = ecgLabValidateEpisodesHits(testAF, refAF);
  nRef = size(refAF, 1);
  nDet = size(testAF, 1);
  episodeSe = ecgLabValidateEpisodesRatio(sum(refHit), nRef);
  episodePpv = ecgLabValidateEpisodesRatio(sum(detHit), nDet);
  %===========================================================================
  % Duration figures: the time of the reference rhythm the detection covers,
  % and the time of the detected rhythm the reference supports.
  refTime = sum(refAF(:, 2) - refAF(:, 1));
  detTime = sum(testAF(:, 2) - testAF(:, 1));
  covered = ecgLabValidateEpisodesOverlapTime(refAF, testAF);
  durationSe = ecgLabValidateEpisodesRatio(covered, refTime);
  durationPpv = ecgLabValidateEpisodesRatio(covered, detTime);
  %===========================================================================
  % Per-second agreement: the yes-or-no label sampled once a second over the
  % span, one vectorised test per interval.
  grid = (span(1) + 0.5):1:span(2);
  refMask = ecgLabValidateEpisodesMask(refAF, grid);
  testMask = ecgLabValidateEpisodesMask(testAF, grid);
  tp = sum(refMask & testMask);
  fn = sum(refMask & ~testMask);
  fp = sum(~refMask & testMask);
  tn = sum(~refMask & ~testMask);
  secondSe = ecgLabValidateEpisodesRatio(tp, tp + fn);
  secondSp = ecgLabValidateEpisodesRatio(tn, tn + fp);
  kappa = ecgLabValidateEpisodesKappa(tp, fn, fp, tn);
  %===========================================================================
  agreement = struct();
  agreement.kind = 'ecglab.agreement';
  agreement.basis = 'episodes';
  agreement.record = char(ecgLabValidateEpisodesRecord(options));
  agreement.label = label;
  agreement.refEpisodes = nRef;
  agreement.detEpisodes = nDet;
  agreement.refEpisodesHit = sum(refHit);
  agreement.detEpisodesHit = sum(detHit);
  agreement.episodeSe = episodeSe;
  agreement.episodePpv = episodePpv;
  agreement.refTime = refTime;
  agreement.detTime = detTime;
  agreement.coveredTime = covered;
  agreement.durationSe = durationSe;
  agreement.durationPpv = durationPpv;
  agreement.tp = tp;
  agreement.fn = fn;
  agreement.fp = fp;
  agreement.tn = tn;
  agreement.secondSe = secondSe;
  agreement.secondSp = secondSp;
  agreement.kappa = kappa;
  agreement.seconds = span(2) - span(1);
  agreement.span = span;
end
%=============================================================================
function label = ecgLabValidateEpisodesLabel(~)
  % The compared rhythm is fixed to 'AFIB'. validate.m owns the option set and
  % has no 'Label' field, so no caller can pass another rhythm. AFIB is what the
  % AF Database scores and ecglab.rhythm labels.
  label = 'AFIB';
end
%=============================================================================
function record = ecgLabValidateEpisodesRecord(options)
  if isstruct(options) && isfield(options, 'Record')
    record = options.Record;
  else
    record = '';
  end
end
%=============================================================================
function [afIntervals, span] = ecgLabValidateEpisodesIntervals(side, label)
  % The intervals of the named rhythm and the analysed span of one side, from a
  % rhythm struct directly or from a recording's rhythm annotations.
  if ~isstruct(side)
    error('ecglab:validateInputRhythmSideEcglabRhythm', 'A rhythm side must be an ecglab.rhythm struct or a recording.');
  end
  if isfield(side, 'kind') && strcmp(side.kind, 'ecglab.recording')
    episodes = ecgLabValidateEpisodesFromRecording(side);
  elseif isfield(side, 'episodes')
    episodes = side.episodes;
  else
    error('ecglab:validateInputRhythmSideCarryEpisodes', 'A rhythm side must carry episodes or be a recording with annotations.');
  end
  onset = double(episodes.onset(:));
  offset = double(episodes.offset(:));
  labels = episodes.label(:);
  if isempty(onset)
    error('ecglab:emptyReferenceRhythmSideHasNo', 'A rhythm side has no episodes.');
  end
  span = [min(onset), max(offset)];
  isNamed = strcmp(labels, label);
  afIntervals = [onset(isNamed), offset(isNamed)];
  afIntervals = ecgLabValidateEpisodesMerge(afIntervals);
end
%=============================================================================
function episodes = ecgLabValidateEpisodesFromRecording(recording)
  % Read a recording's rhythm marks: a WFDB '+' mark carries the rhythm it
  % opens in its aux ('(AFIB', '(AFL', '(N', ...), running until the next mark
  % or the record end. Turned into episodes that tile the record, with anything
  % but the named rhythms folded into 'other'.
  annotations = recording.annotations;
  if isempty(annotations) || ~isfield(annotations, 'symbol') || ...
    isempty(annotations.symbol)
    error('ecglab:emptyReferenceRecordingCarriesNoRhythm', 'The recording carries no rhythm annotations.');
  end
  symbol = reshape(char(annotations.symbol), [], 1);
  time = double(annotations.time(:));
  aux = annotations.aux(:);
  isRhythm = symbol == '+';
  marks = time(isRhythm);
  auxMarks = aux(isRhythm);
  [marks, order] = sort(marks);
  auxMarks = auxMarks(order);
  if isempty(marks)
    error('ecglab:emptyReferenceRecordingCarriesNoRhythm2', 'The recording carries no rhythm-change marks.');
  end
  recordEnd = ecgLabValidateEpisodesRecordEnd(recording, time);
  count = numel(marks);
  onset = marks;
  offset = [marks(2:end); recordEnd];
  labelText = cell(count, 1);
  for k = 1:count
    labelText{k} = ecgLabValidateEpisodesMapLabel(auxMarks{k});
  end
  % A first mark after time zero leaves the opening stretch unlabelled; give it
  % the first mark's label so the timeline has no hole.
  if onset(1) > 0
    onset = [0; onset];
    offset = [onset(2); offset];
    labelText = [labelText(1); labelText];
  end
  episodes = struct('onset', onset, 'offset', offset, 'label', {labelText});
end
%=============================================================================
function value = ecgLabValidateEpisodesRecordEnd(recording, time)
  if isfield(recording, 'seconds') && ~isempty(recording.seconds) && ...
    recording.seconds > 0
    value = double(recording.seconds);
  else
    value = max(time);
  end
end
%=============================================================================
function name = ecgLabValidateEpisodesMapLabel(aux)
  % Map a rhythm aux string to a data-model label. Strip the leading '('; AFIB
  % and AFL keep their names, sinus is 'N', everything else is 'other'.
  text = aux;
  while ~isempty(text) && text(1) == '('
    text = text(2:end);
  end
  text = strtrim(text);
  switch upper(text)
    case 'AFIB'
      name = 'AFIB';
    case 'AFL'
      name = 'AFL';
    case {'N', ''}
      name = 'N';
    otherwise
      name = 'other';
  end
end
%=============================================================================
function merged = ecgLabValidateEpisodesMerge(intervals)
  % Merge touching or overlapping intervals so two adjacent episodes of the
  % same label count as one.
  if isempty(intervals)
    merged = zeros(0, 2);
    return;
  end
  [~, order] = sort(intervals(:, 1));
  intervals = intervals(order, :);
  merged = intervals(1, :);
  for k = 2:size(intervals, 1)
    if intervals(k, 1) <= merged(end, 2) + eps(merged(end, 2))
      merged(end, 2) = max(merged(end, 2), intervals(k, 2));
    else
      merged(end + 1, :) = intervals(k, :);
    end
  end
end
%=============================================================================
function clipped = ecgLabValidateEpisodesClip(intervals, span)
  % Keep only the part of each interval inside the analysed span, dropping any
  % that fall wholly outside it.
  if isempty(intervals)
    clipped = zeros(0, 2);
    return;
  end
  lo = max(intervals(:, 1), span(1));
  hi = min(intervals(:, 2), span(2));
  keep = hi > lo;
  clipped = [lo(keep), hi(keep)];
end
%=============================================================================
function hit = ecgLabValidateEpisodesHits(these, others)
  % Per interval of THESE, whether it overlaps any interval of OTHERS by a
  % positive length.
  n = size(these, 1);
  hit = false(n, 1);
  if isempty(others)
    return;
  end
  for k = 1:n
    hit(k) = any(others(:, 1) < these(k, 2) & these(k, 1) < others(:, 2));
  end
end
%=============================================================================
function total = ecgLabValidateEpisodesOverlapTime(a, b)
  % Total overlap time between the intervals of A and B, vectorised over B.
  total = 0;
  if isempty(a) || isempty(b)
    return;
  end
  for k = 1:size(a, 1)
    lo = max(a(k, 1), b(:, 1));
    hi = min(a(k, 2), b(:, 2));
    total = total + sum(max(0, hi - lo));
  end
end
%=============================================================================
function mask = ecgLabValidateEpisodesMask(intervals, grid)
  % Whether each second of the grid falls inside any interval; one vectorised
  % test per interval, no loop over seconds.
  mask = false(size(grid));
  for k = 1:size(intervals, 1)
    mask = mask | (grid >= intervals(k, 1) & grid < intervals(k, 2));
  end
end
%=============================================================================
function kappa = ecgLabValidateEpisodesKappa(tp, fn, fp, tn)
  % Cohen's kappa over the two labels: agreement beyond chance. One when the
  % timelines match, near zero when they agree only by chance.
  n = tp + fn + fp + tn;
  if n == 0
    kappa = NaN;
    return;
  end
  po = (tp + tn) / n;
  pe = ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / (n * n);
  if abs(1 - pe) < eps
    kappa = 1;
  else
    kappa = (po - pe) / (1 - pe);
  end
end
%=============================================================================
function value = ecgLabValidateEpisodesRatio(numerator, denominator)
  % A rate with a zero denominator is undefined, so return NaN rather than zero.
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
