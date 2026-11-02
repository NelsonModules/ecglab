%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function agreement = ecgLabValidateBeats(test, reference, options)
  % The EC57 beat-by-beat comparator. Each side becomes a sorted list of times
  % in seconds (with native samples kept), the learning period is dropped, and
  % the two lists are walked once with two indices.
  window = double(options.Window);
  learning = double(options.Learning);
  [testTime, testSample, testLabel, shutdown] = ...
  ecgLabValidateParse(test, options, false);
  [refTime, refSample, refClass, pacedAuto] = ...
  ecgLabValidateParse(reference, options, true);
  if isempty(refTime)
    error('ecglab:emptyReferenceReferenceCarriesNoBeats', 'The reference carries no beats.');
  end
  % Measure the span before removing the learning period, so it is what the
  % comparison could have seen.
  span = max([0; testTime; refTime]) - learning;
  if span < 0
    span = 0;
  end
  % The learning period silences the first minutes on both sides: beats there
  % are neither extras nor misses, as the comparison has not begun.
  keepTest = testTime >= learning;
  keepRef = refTime >= learning;
  testTime = testTime(keepTest);
  testSample = testSample(keepTest);
  if ~isempty(testLabel)
    testLabel = testLabel(keepTest);
  end
  refTime = refTime(keepRef);
  refSample = refSample(keepRef);
  if ~isempty(refClass)
    refClass = refClass(keepRef);
  end
  [pairs, missedRef, extraTest] = ecgLabValidateMatch(testTime, refTime, ...
  window);
  %===========================================================================
  % A reference beat missed inside a declared shutdown is not a false negative;
  % these are counted apart so they do not inflate the error.
  inShutdown = ecgLabValidateInWindows(refTime(missedRef), shutdown);
  shutdownMissed = sum(inShutdown);
  missedRef = missedRef(~inShutdown);
  tp = size(pairs, 1);
  fn = numel(missedRef);
  fp = numel(extraTest);
  agreement = struct();
  agreement.kind = 'ecglab.agreement';
  agreement.basis = 'beats';
  agreement.record = char(options.Record);
  agreement.window = window;
  agreement.learning = learning;
  agreement.tp = tp;
  agreement.fp = fp;
  agreement.fn = fn;
  agreement.se = ecgLabValidateRatio(tp, tp + fn);
  agreement.ppv = ecgLabValidateRatio(tp, tp + fp);
  if tp > 0
    agreement.matched = [testSample(pairs(:, 1)), refSample(pairs(:, 2))];
  else
    agreement.matched = zeros(0, 2);
  end
  agreement.missed = refSample(missedRef);
  agreement.extra = testSample(extraTest);
  %===========================================================================
  % Timing error of the matched pairs, test minus reference, in ms.
  if tp > 0
    delta = (testTime(pairs(:, 1)) - refTime(pairs(:, 2))) * 1000;
    agreement.timingMean = mean(delta);
    agreement.timingSd = std(delta);
  else
    agreement.timingMean = NaN;
    agreement.timingSd = NaN;
  end
  % The standard's RMS error is on the RR intervals, not the marks: each
  % matched test interval against the reference interval it spans. A constant
  % offset cancels and reports zero.
  if tp > 1
    rrTest = diff(testTime(pairs(:, 1)));
    rrRef = diff(refTime(pairs(:, 2)));
    agreement.rrError = sqrt(mean((rrTest - rrRef) .^ 2)) * 1000;
  else
    agreement.rrError = NaN;
  end
  %===========================================================================
  % Counts per reference class of what was matched and what was missed, so a
  % report can say which beats the detector loses. Shutdown beats are excluded.
  classes = 'NSVFQ';
  matchedClass = repmat(' ', tp, 1);
  if tp > 0 && ~isempty(refClass)
    matchedClass = refClass(pairs(:, 2));
  end
  missedClass = repmat(' ', fn, 1);
  if fn > 0 && ~isempty(refClass)
    missedClass = refClass(missedRef);
  end
  agreement.classMatched = ecgLabValidateCount(matchedClass, classes);
  agreement.classMissed = ecgLabValidateCount(missedClass, classes);
  %===========================================================================
  % The class matrix and the VEB and SVEB statistics also need a test-side
  % class, which only a labelled test carries. Without it they are empty while
  % the counts above stand.
  haveMatrix = ~isempty(testLabel) && ~isempty(refClass);
  if haveMatrix
    [agreement.matrix, agreement.veb, agreement.sveb] = ...
    ecgLabValidateMatrix(matchedClass, testLabel(pairs(:, 1)), ...
    missedClass, testLabel(extraTest), classes);
  else
    agreement.matrix = [];
    agreement.veb = ecgLabValidateEmptyClass();
    agreement.sveb = ecgLabValidateEmptyClass();
  end
  agreement.matrixRows = {'N', 'S', 'V', 'F', 'Q', 'X'};
  agreement.matrixCols = {'N', 'S', 'V', 'F', 'Q', 'O'};
  agreement.vebSe = agreement.veb.se;
  agreement.vebPpv = agreement.veb.ppv;
  agreement.svebSe = agreement.sveb.se;
  agreement.svebPpv = agreement.sveb.ppv;
  agreement.shutdownMissed = shutdownMissed;
  if isempty(options.Paced)
    agreement.paced = pacedAuto;
  else
    agreement.paced = logical(options.Paced);
  end
  agreement.seconds = span;
end
%=============================================================================
function [times, samples, tags, aux] = ecgLabValidateParse(side, options, ...
  isReference)
  % Reduce a side to sorted times (seconds) and native samples. For the
  % reference, TAGS is the AAMI class and AUX the paced flag; for the test,
  % TAGS is the per-beat label and AUX the shutdown windows.
  tags = [];
  aux = [];
  if isstruct(side)
    [times, samples, symbol, label] = ecgLabValidateFromStruct(side, options);
    if isReference
      [times, samples, tags, aux] = ecgLabValidateReference(times, ...
      samples, symbol, options);
    else
      [times, samples, tags, aux] = ecgLabValidateTest(times, samples, ...
      symbol, label, side, options);
    end
  elseif isnumeric(side) || islogical(side)
    [times, samples] = ecgLabValidateFromVector(side, options);
    if isReference
      aux = false;
    else
      aux = zeros(0, 2);
    end
  else
    error('ecglab:validateInputTestReferenceStructNumeric', 'A test or a reference must be a struct or a numeric vector.');
  end
  [times, order] = sort(times);
  samples = samples(order);
  if ~isempty(tags)
    tags = tags(order);
  end
end
%=============================================================================
function [times, samples, symbol, label] = ecgLabValidateFromStruct(side, ...
  options)
  % A beats, annotations or classes struct: each has a sample field, and a time
  % or rate. The symbol tells a beat from a noise mark; the label, when there,
  % is the test's own class.
  if ~isfield(side, 'sample')
    error('ecglab:validateInputStructInputCarrySample', 'A struct input must carry a sample field.');
  end
  samples = double(side.sample(:));
  if isfield(side, 'time') && numel(side.time) == numel(samples)
    times = double(side.time(:));
  else
    rate = ecgLabValidateRate(side, options);
    times = (samples - 1) / rate;
  end
  symbol = [];
  if isfield(side, 'symbol') && ~isempty(side.symbol)
    symbol = reshape(char(side.symbol), [], 1);
  end
  label = [];
  if isfield(side, 'label') && ~isempty(side.label)
    label = reshape(char(side.label), [], 1);
  end
end
%=============================================================================
function [times, samples] = ecgLabValidateFromVector(side, options)
  values = double(side(:));
  unit = lower(char(options.Unit));
  rate = options.Rate;
  if isempty(rate)
    % Without a rate a bare vector cannot be placed against a window in
    % seconds.
    error('ecglab:rateNeededSamplingRateNeededCompare', 'A sampling rate is needed to compare samples to a time window.');
  end
  rate = double(rate);
  switch unit
    case 'samples'
      samples = values;
      times = (values - 1) / rate;
    case 'seconds'
      times = values;
      samples = round(values * rate) + 1;
    otherwise
      error('ecglab:badUnitUnitSamplesSeconds', 'Unit must be samples or seconds.');
  end
end
%=============================================================================
function rate = ecgLabValidateRate(side, options)
  if isfield(side, 'rate') && ~isempty(side.rate) && ~isnan(side.rate)
    rate = double(side.rate);
  elseif ~isempty(options.Rate)
    rate = double(options.Rate);
  else
    error('ecglab:rateNeededSamplingRateNeededCompare', 'A sampling rate is needed to compare samples to a time window.');
  end
end
%=============================================================================
function [times, samples, class, paced] = ecgLabValidateReference(times, ...
  samples, symbol, options)
  % Only the beat symbols are compared. The paced flag is read here (a record
  % is paced if it carries a paced beat) as paced records are left out of the
  % class statistics.
  if isempty(symbol)
    class = [];
    paced = false;
    return;
  end
  paced = any(ismember(symbol, '/f'));
  isBeat = ismember(symbol, 'NLRBAaJSVrFejnE/fQ?');
  times = times(isBeat);
  samples = samples(isBeat);
  class = ecgLabAami(symbol(isBeat), options.Table);
end
%=============================================================================
function [times, samples, label, windows] = ecgLabValidateTest(times, ...
  samples, symbol, label, side, options)
  % Keep the test's beats; turn its NOISE marks into shutdown windows. A '~'
  % with subtype bits 16 and 32 set opens a window and the next '~' closes it.
  windows = zeros(0, 2);
  if isempty(symbol)
    return;
  end
  isNoise = symbol == '~';
  if options.Shutdown && any(isNoise)
    subtype = zeros(numel(symbol), 1);
    if isfield(side, 'subtype') && numel(side.subtype) == numel(symbol)
      subtype = double(side.subtype(:));
    end
    noiseTimes = times(isNoise);
    noiseSub = subtype(isNoise);
    [noiseTimes, order] = sort(noiseTimes);
    noiseSub = noiseSub(order);
    windows = ecgLabValidateShutdown(noiseTimes, noiseSub);
  end
  isBeat = ismember(symbol, 'NLRBAaJSVrFejnE/fQ?');
  times = times(isBeat);
  samples = samples(isBeat);
  if ~isempty(label)
    if numel(label) == numel(isBeat)
      label = label(isBeat);
    elseif numel(label) ~= sum(isBeat)
      % A label matching neither the whole list nor its beats cannot be
      % aligned, so it is dropped.
      label = [];
    end
  end
end
%=============================================================================
function windows = ecgLabValidateShutdown(noiseTimes, noiseSub)
  windows = zeros(0, 2);
  open = bitand(round(noiseSub), 16) ~= 0 & bitand(round(noiseSub), 32) ~= 0;
  inside = false;
  start = 0;
  for index = 1:numel(noiseTimes)
    if ~inside
      if open(index)
        start = noiseTimes(index);
        inside = true;
      end
    else
      windows(end + 1, :) = [start, noiseTimes(index)];
      inside = false;
      % A close that is also an opening mark starts the next window.
      if open(index)
        start = noiseTimes(index);
        inside = true;
      end
    end
  end
  if inside
    % A shutdown still open at the last mark runs to the end of the record.
    windows(end + 1, :) = [start, Inf];
  end
end
%=============================================================================
function mask = ecgLabValidateInWindows(times, windows)
  mask = false(numel(times), 1);
  if isempty(windows) || isempty(times)
    return;
  end
  for index = 1:size(windows, 1)
    mask = mask | (times >= windows(index, 1) & times <= windows(index, 2));
  end
end
%=============================================================================
function [pairs, missedRef, extraTest] = ecgLabValidateMatch(testTime, ...
  refTime, window)
  % The matching rule, walked over both sorted lists with two indices i (test)
  % and j (reference):
  %
  %   Beats within the window are candidates. If the next test beat is strictly
  %   closer to the same reference, the current one is let go as an extra so the
  %   closer one pairs. The steal is refused when it would strand a neighbouring
  %   reference: when the current test beat is also in the previous reference's
  %   window, or when the next test beat has its own reference within window.
  %
  %   Otherwise the two pair and both indices advance. When not within the
  %   window, the earlier advances alone: an unmatched reference is a miss, an
  %   unmatched test an extra.
  nTest = numel(testTime);
  nRef = numel(refTime);
  % Preallocate the outputs to their largest size and trim at the end; growing
  % with end + 1 in the loop would be quadratic.
  pairs = zeros(min(nTest, nRef), 2);
  missedRef = zeros(nRef, 1);
  extraTest = zeros(nTest, 1);
  nPairs = 0;
  nMissed = 0;
  nExtra = 0;
  i = 1;
  j = 1;
  while i <= nTest && j <= nRef
    gap = testTime(i) - refTime(j);
    if abs(gap) <= window
      closerAhead = i < nTest && ...
      abs(testTime(i + 1) - refTime(j)) < abs(gap);
      strandsPrevious = j > 1 && abs(testTime(i) - refTime(j - 1)) <= window;
      % The next test beat has its own reference (ref j+1 in window); stealing
      % ref j would leave ref j+1 a false miss.
      stealStrandsNext = i < nTest && j < nRef && ...
      abs(testTime(i + 1) - refTime(j + 1)) <= window;
      if closerAhead && ~strandsPrevious && ~stealStrandsNext
        nExtra = nExtra + 1;
        extraTest(nExtra) = i;
        i = i + 1;
      else
        nPairs = nPairs + 1;
        pairs(nPairs, :) = [i, j];
        i = i + 1;
        j = j + 1;
      end
    elseif testTime(i) < refTime(j)
      nExtra = nExtra + 1;
      extraTest(nExtra) = i;
      i = i + 1;
    else
      nMissed = nMissed + 1;
      missedRef(nMissed) = j;
      j = j + 1;
    end
  end
  % Whatever is left when one list runs out is a miss or an extra, assigned as
  % a range.
  if i <= nTest
    extraTest(nExtra + (1:(nTest - i + 1))) = (i:nTest)';
    nExtra = nExtra + (nTest - i + 1);
  end
  if j <= nRef
    missedRef(nMissed + (1:(nRef - j + 1))) = (j:nRef)';
    nMissed = nMissed + (nRef - j + 1);
  end
  pairs = pairs(1:nPairs, :);
  missedRef = missedRef(1:nMissed);
  extraTest = extraTest(1:nExtra);
end
%=============================================================================
function counts = ecgLabValidateCount(values, classes)
  counts = struct();
  for index = 1:numel(classes)
    counts.(classes(index)) = sum(values == classes(index));
  end
end
%=============================================================================
function [matrix, veb, sveb] = ecgLabValidateMatrix(matchedRef, ...
  matchedTest, missedRef, extraTest, classes)
  % The confusion matrix bxb prints: rows N S V F Q then X (test with no
  % reference), columns N S V F Q then O (reference with no test). A pair lands
  % at (reference class, test label), a miss in the O column, an extra in the X
  % row.
  n = numel(classes);
  matrix = zeros(n + 1, n + 1);
  for index = 1:numel(matchedRef)
    r = find(classes == matchedRef(index), 1);
    c = find(classes == matchedTest(index), 1);
    if ~isempty(r) && ~isempty(c)
      matrix(r, c) = matrix(r, c) + 1;
    end
  end
  for index = 1:numel(missedRef)
    r = find(classes == missedRef(index), 1);
    if ~isempty(r)
      matrix(r, n + 1) = matrix(r, n + 1) + 1;
    end
  end
  for index = 1:numel(extraTest)
    c = find(classes == extraTest(index), 1);
    if ~isempty(c)
      matrix(n + 1, c) = matrix(n + 1, c) + 1;
    end
  end
  veb = ecgLabValidateVeb(matrix, classes);
  sveb = ecgLabValidateSveb(matrix, classes);
end
%=============================================================================
function veb = ecgLabValidateVeb(matrix, classes)
  % Ventricular ectopic detection, V against the rest. Fusion beats F are left
  % out on both sides, so the F row and column take no part.
  iN = find(classes == 'N', 1);
  iS = find(classes == 'S', 1);
  iV = find(classes == 'V', 1);
  iQ = find(classes == 'Q', 1);
  other = [iN, iS, iQ];
  last = size(matrix, 1);
  tp = matrix(iV, iV);
  fn = sum(matrix(iV, other)) + matrix(iV, last);
  fp = sum(matrix(other, iV)) + matrix(last, iV);
  veb = ecgLabValidateClass(tp, fn, fp);
end
%=============================================================================
function sveb = ecgLabValidateSveb(matrix, classes)
  % Supraventricular ectopic detection, S against the rest; every other class
  % counts here.
  iS = find(classes == 'S', 1);
  last = size(matrix, 1);
  tp = matrix(iS, iS);
  fn = sum(matrix(iS, :)) - tp;
  fp = sum(matrix(:, iS)) - tp;
  % The O column and X row are already in those sums, so dropped and spurious S
  % are not double-counted.
  sveb = ecgLabValidateClass(tp, fn, fp);
end
%=============================================================================
function class = ecgLabValidateClass(tp, fn, fp)
  class = struct('tp', tp, 'fn', fn, 'fp', fp, ...
  'se', ecgLabValidateRatio(tp, tp + fn), ...
  'ppv', ecgLabValidateRatio(tp, tp + fp));
end
%=============================================================================
function class = ecgLabValidateEmptyClass()
  class = struct('tp', 0, 'fn', 0, 'fp', 0, 'se', NaN, 'ppv', NaN);
end
%=============================================================================
function value = ecgLabValidateRatio(numerator, denominator)
  % A rate with a zero denominator is undefined, so return NaN rather than zero
  % and never mistake silence for a perfect score.
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
