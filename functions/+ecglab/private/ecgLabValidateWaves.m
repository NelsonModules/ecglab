%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function agreement = ecgLabValidateWaves(test, reference, options)
  % The 'waves' basis of ecglab.validate: measure a delineation against a
  % reference, wave by wave, as the QT Database evaluation does. A cell array is
  % pooled into a summary; otherwise TEST is an ecglab.delineate output and
  % REFERENCE a waves struct or a recording with wave marks.
  %
  % Each reference beat is matched to a delineated one by the QRS peak within
  % the window; for each fiducial both sides mark, the signed error (delineated
  % minus reference) in ms is accumulated. Per fiducial the result carries the
  % error mean and SD, the both-marked count, sensitivity, predictivity, and
  % the CSE tolerance.
  if iscell(test)
    agreement = ecgLabValidateWavesPool(test);
    return;
  end
  if ~isstruct(test) || ~isfield(test, 'kind') || ...
    ~strcmp(test.kind, 'ecglab.waves')
    error('ecglab:validateInputTestEcglabWavesStruct', 'The test must be an ecglab.waves struct from ecglab.delineate.');
  end
  window = ecgLabValidateWavesWindow(options);
  [refSample, refTime, rate] = ecgLabValidateWavesReference(reference, options);
  if isempty(refSample)
    error('ecglab:emptyReferenceReferenceCarriesNoBeats', 'The reference carries no beats.');
  end
  [delSample, delTime] = ecgLabValidateWavesFromWaves(test, rate);
  %===========================================================================
  % Match the sparse reference beats to the delineated beats by QRS peak,
  % nearest within the window. The key is R, or the QRS onset when R is absent.
  refKey = ecgLabValidateWavesKey(refTime);
  delKey = ecgLabValidateWavesKey(delTime);
  pairs = ecgLabValidateWavesMatch(delKey, refKey, window);
  %===========================================================================
  columns = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', ...
  'QRSoff', 'J', 'Ton', 'Tpeak', 'Toff'};
  cse = ecgLabValidateWavesCse();
  fiducials = struct();
  for c = 1:12
    name = columns{c};
    if isempty(pairs)
      fiducials.(name) = ecgLabValidateWavesFiducial([], 0, 0);
      continue;
    end
    de = delTime(pairs(:, 1), c);
    re = refTime(pairs(:, 2), c);
    both = isfinite(de) & isfinite(re);
    errors = (de(both) - re(both)) * 1000;
    fiducials.(name) = ecgLabValidateWavesFiducial(errors, ...
    sum(isfinite(re)), sum(isfinite(de)));
  end
  %===========================================================================
  agreement = struct();
  agreement.kind = 'ecglab.agreement';
  agreement.basis = 'waves';
  agreement.record = char(ecgLabValidateWavesRecord(options));
  agreement.window = window;
  agreement.columns = columns;
  agreement.fiducials = fiducials;
  agreement.cse = cse;
  agreement.matchedBeats = size(pairs, 1);
  agreement.seconds = ecgLabValidateWavesSpan(delTime, refTime);
end
%=============================================================================
function window = ecgLabValidateWavesWindow(options)
  % The matching window in seconds; defaults to 0.15 s (the EC57 window) when
  % the field is missing, as in the pool form.
  if isstruct(options) && isfield(options, 'Window') && ~isempty(options.Window)
    window = double(options.Window);
  else
    window = 0.15;
  end
end
%=============================================================================
function record = ecgLabValidateWavesRecord(options)
  if isstruct(options) && isfield(options, 'Record')
    record = options.Record;
  else
    record = '';
  end
end
%=============================================================================
function [sample, time, rate] = ecgLabValidateWavesReference(reference, options)
  % The reference waves, from a waves struct or a recording's annotations. The
  % wave marks are WFDB ( ) p t and the beat symbol.
  rate = [];
  if ~isstruct(reference)
    error('ecglab:validateInputReferenceEcglabWavesStruct', 'The reference must be an ecglab.waves struct or a recording.');
  end
  if isfield(reference, 'kind') && strcmp(reference.kind, 'ecglab.waves')
    [sample, time] = ecgLabValidateWavesFromWaves(reference, []);
    return;
  end
  if isfield(reference, 'kind') && strcmp(reference.kind, 'ecglab.recording')
    rate = double(reference.rate);
    [sample, time] = ecgLabValidateWavesFromAnnotations(reference.annotations, ...
    rate);
    return;
  end
  if isfield(reference, 'kind') && strcmp(reference.kind, 'ecglab.annotations')
    rate = double(reference.rate);
    [sample, time] = ecgLabValidateWavesFromAnnotations(reference, rate);
    return;
  end
  error('ecglab:validateInputReferenceEcglabWavesStruct', 'The reference must be an ecglab.waves struct or a recording.');
end
%=============================================================================
function [sample, time] = ecgLabValidateWavesFromWaves(waves, rate)
  % A waves struct carries sample and time (K x 12). Time is preferred; sample
  % fills in only when a hand-built struct omitted time.
  sample = double(waves.sample);
  if isfield(waves, 'time') && isequal(size(waves.time), size(sample))
    time = double(waves.time);
  elseif ~isempty(rate)
    time = (sample - 1) / rate;
  elseif isempty(sample)
    time = reshape([], size(sample));
  else
    error('ecglab:validateInputWavesStructNeedsTime', 'A waves struct needs a time field or a rate to place its marks.');
  end
end
%=============================================================================
function [sample, time] = ecgLabValidateWavesFromAnnotations(annotations, rate)
  % Group one annotator's WFDB wave marks into beats, one row per QRS, in the
  % twelve-column order. '(' is a wave onset, ')' a wave end, num the wave
  % (0 P, 1 QRS, 2 T); 'p' and 't' are the P and T peaks, a beat symbol the QRS.
  % Q, S and J are unmarked by the QT Database, so those columns stay NaN. Each
  % mark joins the beat whose QRS is nearest on the correct side: P marks and
  % the QRS onset precede their QRS, the QRS end and T marks follow it.
  if isempty(annotations) || ~isfield(annotations, 'symbol') || ...
    isempty(annotations.symbol)
    sample = zeros(0, 12);
    time = zeros(0, 12);
    return;
  end
  symbol = reshape(char(annotations.symbol), [], 1);
  annSample = double(annotations.sample(:));
  if isfield(annotations, 'num') && numel(annotations.num) == numel(symbol)
    num = double(annotations.num(:));
  else
    num = zeros(numel(symbol), 1);
  end
  % Sort the stream by sample so a boundary's adjacency to its peak is read
  % correctly whatever order the file listed the marks in.
  [annSample, order] = sort(annSample);
  symbol = symbol(order);
  num = num(order);
  beatSet = 'NLRBAaJSVrFejnE/fQ?';
  isQRS = ismember(symbol, beatSet);
  qrsSample = sort(annSample(isQRS));
  K = numel(qrsSample);
  sample = nan(K, 12);
  if K == 0
    time = zeros(0, 12);
    return;
  end
  sample(:, 6) = qrsSample;
  % Route each non-QRS mark to a column and side. Two boundary conventions
  % occur: the QT Database tags '(' and ')' with num (0 P, 1 QRS, 2 T), while
  % Lobachevsky leaves num 0 and identifies the wave by the adjacent peak. Use
  % num when it distinguishes the waves, otherwise the adjacency.
  boundary = symbol == '(' | symbol == ')';
  if any(num(boundary) ~= 0)
    isPon = symbol == '(' & num == 0;
    isPoff = symbol == ')' & num == 0;
    isQRSon = symbol == '(' & num == 1;
    isQRSoff = symbol == ')' & num == 1;
    isTon = symbol == '(' & num == 2;
    isToff = symbol == ')' & num == 2;
  else
    nextSym = [symbol(2:end); ' '];
    prevSym = [' '; symbol(1:end - 1)];
    nextQRS = ismember(nextSym, beatSet);
    prevQRS = ismember(prevSym, beatSet);
    isPon = symbol == '(' & nextSym == 'p';
    isPoff = symbol == ')' & prevSym == 'p';
    isQRSon = symbol == '(' & nextQRS;
    isQRSoff = symbol == ')' & prevQRS;
    isTon = symbol == '(' & nextSym == 't';
    isToff = symbol == ')' & prevSym == 't';
  end
  isPpeak = symbol == 'p';
  isTpeak = symbol == 't';
  sample = ecgLabValidateWavesAssign(sample, 1, annSample(isPon), ...
  qrsSample, true);
  sample = ecgLabValidateWavesAssign(sample, 2, annSample(isPpeak), ...
  qrsSample, true);
  sample = ecgLabValidateWavesAssign(sample, 3, annSample(isPoff), ...
  qrsSample, true);
  sample = ecgLabValidateWavesAssign(sample, 4, annSample(isQRSon), ...
  qrsSample, true);
  sample = ecgLabValidateWavesAssign(sample, 8, annSample(isQRSoff), ...
  qrsSample, false);
  sample = ecgLabValidateWavesAssign(sample, 10, annSample(isTon), ...
  qrsSample, false);
  sample = ecgLabValidateWavesAssign(sample, 11, annSample(isTpeak), ...
  qrsSample, false);
  sample = ecgLabValidateWavesAssign(sample, 12, annSample(isToff), ...
  qrsSample, false);
  time = (sample - 1) / rate;
end
%=============================================================================
function sample = ecgLabValidateWavesAssign(sample, col, marks, qrsSample, ...
  following)
  % Put each mark in its beat's column. FOLLOWING true routes it to the QRS at
  % or after (P mark or QRS onset); false to the QRS at or before (QRS end or
  % T mark). A mark with no QRS on its side is dropped.
  for index = 1:numel(marks)
    m = marks(index);
    if following
      k = find(qrsSample >= m, 1, 'first');
    else
      k = find(qrsSample <= m, 1, 'last');
    end
    if ~isempty(k)
      sample(k, col) = m;
    end
  end
end
%=============================================================================
function key = ecgLabValidateWavesKey(time)
  % The matching key per beat: the R time, or the QRS onset when R is unmarked.
  % Both sides use the same rule.
  key = time(:, 6);
  missing = ~isfinite(key);
  key(missing) = time(missing, 4);
end
%=============================================================================
function pairs = ecgLabValidateWavesMatch(delKey, refKey, window)
  % Pair each reference beat with the nearest unused delineated beat within the
  % window. The reference beats are sparse and well separated, so nearest-first
  % with a used flag cannot mispair; unmatched delineated beats are never
  % chosen. One vectorised distance per reference beat.
  nDel = numel(delKey);
  nRef = numel(refKey);
  pairs = zeros(min(nDel, nRef), 2);
  nPairs = 0;
  used = false(nDel, 1);
  for j = 1:nRef
    if ~isfinite(refKey(j))
      continue;
    end
    distance = abs(delKey - refKey(j));
    distance(used) = Inf;
    distance(~isfinite(delKey)) = Inf;
    [best, i] = min(distance);
    if best <= window
      used(i) = true;
      nPairs = nPairs + 1;
      pairs(nPairs, :) = [i, j];
    end
  end
  pairs = pairs(1:nPairs, :);
end
%=============================================================================
function fiducial = ecgLabValidateWavesFiducial(errors, refN, delN)
  % One fiducial's statistics. N is the both-marked count; sensitivity is the
  % share of reference marks the delineation also placed, predictivity the
  % reverse. Mean and SD are NaN when nothing was both-marked.
  errors = errors(:);
  n = numel(errors);
  fiducial = struct();
  if n == 0
    fiducial.mean = NaN;
    fiducial.sd = NaN;
  else
    fiducial.mean = mean(errors);
    fiducial.sd = std(errors);
  end
  fiducial.n = n;
  fiducial.se = ecgLabValidateWavesRatio(n, refN);
  fiducial.ppv = ecgLabValidateWavesRatio(n, delN);
  fiducial.errors = errors;
  fiducial.refN = refN;
  fiducial.delN = delN;
end
%=============================================================================
function value = ecgLabValidateWavesRatio(numerator, denominator)
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
function cse = ecgLabValidateWavesCse()
  % The CSE accepted standard deviations against the referees' median, in ms
  % (survey 5.3); only five boundaries were set, the rest carry an empty
  % tolerance.
  cse = struct('Pon', 10.2, 'Ppeak', [], 'Poff', 12.7, 'QRSon', 6.5, ...
  'Q', [], 'R', [], 'S', [], 'QRSoff', 11.6, 'J', [], 'Ton', [], ...
  'Tpeak', [], 'Toff', 30.6);
end
%=============================================================================
function span = ecgLabValidateWavesSpan(delTime, refTime)
  all = [delTime(:); refTime(:)];
  all = all(isfinite(all));
  if isempty(all)
    span = 0;
  else
    span = max(all);
  end
end
%=============================================================================
function summary = ecgLabValidateWavesPool(agreements)
  % Pool per-record waves agreements. Mean and SD are taken over the raw errors
  % of every matched beat (not per-record means), so a record weighs by its beat
  % count. Sensitivity is pooled the same way. A markdown table prints each
  % fiducial beside its CSE tolerance.
  if isempty(agreements)
    error('ecglab:emptyAgreements', 'There are no agreements to summarise.');
  end
  count = numel(agreements);
  for index = 1:count
    if ~isfield(agreements{index}, 'basis') || ...
      ~strcmp(agreements{index}.basis, 'waves')
      error('ecglab:mixedBasis', 'The agreements to summarise are not of one basis.');
    end
  end
  columns = {'Pon', 'Ppeak', 'Poff', 'QRSon', 'Q', 'R', 'S', ...
  'QRSoff', 'J', 'Ton', 'Tpeak', 'Toff'};
  cse = ecgLabValidateWavesCse();
  records = cell(count, 1);
  for index = 1:count
    records{index} = char(ecgLabValidateWavesField(agreements{index}, ...
    'record', ''));
  end
  fiducials = struct();
  for c = 1:12
    name = columns{c};
    errors = [];
    refN = 0;
    delN = 0;
    for index = 1:count
      f = agreements{index}.fiducials.(name);
      errors = [errors; f.errors(:)];
      refN = refN + f.refN;
      delN = delN + f.delN;
    end
    n = numel(errors);
    one = struct();
    if n == 0
      one.mean = NaN;
      one.sd = NaN;
    else
      one.mean = mean(errors);
      one.sd = std(errors);
    end
    one.n = n;
    one.se = ecgLabValidateWavesRatio(n, refN);
    one.ppv = ecgLabValidateWavesRatio(n, delN);
    one.cse = cse.(name);
    if isempty(one.cse) || n == 0
      one.within = [];
    else
      one.within = one.sd <= one.cse;
    end
    fiducials.(name) = one;
  end
  summary = struct();
  summary.kind = 'ecglab.agreement';
  summary.basis = 'summary';
  summary.of = 'waves';
  summary.records = records;
  summary.columns = columns;
  summary.fiducials = fiducials;
  summary.cse = cse;
  summary.markdown = ecgLabValidateWavesMarkdown(summary);
end
%=============================================================================
function value = ecgLabValidateWavesField(s, name, fallback)
  if isstruct(s) && isfield(s, name)
    value = s.(name);
  else
    value = fallback;
  end
end
%=============================================================================
function text = ecgLabValidateWavesMarkdown(summary)
  % One row per fiducial: pooled mean and SD, count, sensitivity, CSE tolerance
  % and whether the SD stays within it. The caption names the records pooled.
  newline = char(10);
  header = ['| Fiducial | Mean +/- SD (ms) | n | Se (%) | ', ...
  'CSE tol (ms) | SD within CSE |'];
  divider = '|---|---:|---:|---:|---:|:---:|';
  rows = {header; divider};
  columns = summary.columns;
  for c = 1:12
    name = columns{c};
    f = summary.fiducials.(name);
    rows{end + 1, 1} = ecgLabValidateWavesRow(name, f);
  end
  caption = sprintf('_Pooled over %d records, %s._', ...
  numel(summary.records), strjoin(summary.records', ', '));
  rows{end + 1, 1} = '';
  rows{end + 1, 1} = caption;
  text = strjoin(rows', newline);
end
%=============================================================================
function row = ecgLabValidateWavesRow(name, f)
  if f.n == 0
    meanSd = '-';
  else
    meanSd = sprintf('%.2f +/- %.2f', f.mean, f.sd);
  end
  if isnan(f.se)
    se = '-';
  else
    se = sprintf('%.2f', f.se * 100);
  end
  if isempty(f.cse)
    tol = '-';
  else
    tol = sprintf('%.1f', f.cse);
  end
  if isempty(f.within)
    within = '-';
  elseif f.within
    within = 'yes';
  else
    within = 'no';
  end
  row = ['| ', name, ' | ', meanSd, ' | ', sprintf('%d', f.n), ' | ', ...
  se, ' | ', tol, ' | ', within, ' |'];
end
%=============================================================================
