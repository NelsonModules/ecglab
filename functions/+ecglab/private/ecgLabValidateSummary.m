%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function summary = ecgLabValidateSummary(agreements, given)
  % Pool per-record agreements into one. EC57 reports two figures: GROSS pools
  % every beat then takes the rate (long records weigh more), AVERAGE takes
  % each record's rate then the mean (every record weighs the same).
  options = ecgLabOptions(struct('ExcludePaced', true), given);
  excludePaced = logical(options.ExcludePaced);
  if isempty(agreements)
    error('ecglab:emptyAgreements', 'There are no agreements to summarise.');
  end
  count = numel(agreements);
  basis = agreements{1}.basis;
  % The waves basis pools differently (per-fiducial errors, not beat counts),
  % so it is delegated to the function that owns it.
  if strcmp(basis, 'waves')
    summary = ecgLabValidateWaves(agreements, [], struct());
    return;
  end
  for index = 2:count
    if ~strcmp(agreements{index}.basis, basis)
      error('ecglab:mixedBasis', 'The agreements to summarise are not of one basis.');
    end
  end
  %===========================================================================
  % Gather the columns once. The class figures may exclude paced records (the
  % standard does not score a class on a paced rhythm); the QRS figures keep
  % every record.
  records = cell(count, 1);
  tp = zeros(count, 1);
  fp = zeros(count, 1);
  fn = zeros(count, 1);
  se = zeros(count, 1);
  ppv = zeros(count, 1);
  vebSe = zeros(count, 1);
  vebPpv = zeros(count, 1);
  svebSe = zeros(count, 1);
  svebPpv = zeros(count, 1);
  rrError = zeros(count, 1);
  runtime = nan(count, 1);
  paced = false(count, 1);
  vebTp = zeros(count, 1);
  vebFn = zeros(count, 1);
  vebFp = zeros(count, 1);
  svebTp = zeros(count, 1);
  svebFn = zeros(count, 1);
  svebFp = zeros(count, 1);
  for index = 1:count
    one = agreements{index};
    records{index} = char(ecgLabValidateField(one, 'record', ''));
    tp(index) = ecgLabValidateField(one, 'tp', 0);
    fp(index) = ecgLabValidateField(one, 'fp', 0);
    fn(index) = ecgLabValidateField(one, 'fn', 0);
    se(index) = ecgLabValidateField(one, 'se', NaN);
    ppv(index) = ecgLabValidateField(one, 'ppv', NaN);
    vebSe(index) = ecgLabValidateField(one, 'vebSe', NaN);
    vebPpv(index) = ecgLabValidateField(one, 'vebPpv', NaN);
    svebSe(index) = ecgLabValidateField(one, 'svebSe', NaN);
    svebPpv(index) = ecgLabValidateField(one, 'svebPpv', NaN);
    rrError(index) = ecgLabValidateField(one, 'rrError', NaN);
    runtime(index) = ecgLabValidateField(one, 'runtime', NaN);
    paced(index) = logical(ecgLabValidateField(one, 'paced', false));
    veb = ecgLabValidateField(one, 'veb', []);
    if ~isempty(veb)
      vebTp(index) = veb.tp;
      vebFn(index) = veb.fn;
      vebFp(index) = veb.fp;
    end
    sveb = ecgLabValidateField(one, 'sveb', []);
    if ~isempty(sveb)
      svebTp(index) = sveb.tp;
      svebFn(index) = sveb.fn;
      svebFp(index) = sveb.fp;
    end
  end
  keepClass = true(count, 1);
  if excludePaced
    keepClass = ~paced;
  end
  %===========================================================================
  gross = struct();
  gross.tp = sum(tp);
  gross.fp = sum(fp);
  gross.fn = sum(fn);
  gross.se = ecgLabValidateSumRatio(sum(tp), sum(tp) + sum(fn));
  gross.ppv = ecgLabValidateSumRatio(sum(tp), sum(tp) + sum(fp));
  gross.vebSe = ecgLabValidateSumRatio(sum(vebTp(keepClass)), ...
  sum(vebTp(keepClass)) + sum(vebFn(keepClass)));
  gross.vebPpv = ecgLabValidateSumRatio(sum(vebTp(keepClass)), ...
  sum(vebTp(keepClass)) + sum(vebFp(keepClass)));
  gross.svebSe = ecgLabValidateSumRatio(sum(svebTp(keepClass)), ...
  sum(svebTp(keepClass)) + sum(svebFn(keepClass)));
  gross.svebPpv = ecgLabValidateSumRatio(sum(svebTp(keepClass)), ...
  sum(svebTp(keepClass)) + sum(svebFp(keepClass)));
  %===========================================================================
  % The average is the mean over records where the figure is defined; a record
  % with no beat of a class is skipped, not counted as zero.
  average = struct();
  average.se = ecgLabValidateMean(se, true(count, 1));
  average.ppv = ecgLabValidateMean(ppv, true(count, 1));
  average.vebSe = ecgLabValidateMean(vebSe, keepClass);
  average.vebPpv = ecgLabValidateMean(vebPpv, keepClass);
  average.svebSe = ecgLabValidateMean(svebSe, keepClass);
  average.svebPpv = ecgLabValidateMean(svebPpv, keepClass);
  %===========================================================================
  table = struct();
  table.record = records;
  table.tp = tp;
  table.fp = fp;
  table.fn = fn;
  table.se = se;
  table.ppv = ppv;
  table.vebSe = vebSe;
  table.vebPpv = vebPpv;
  table.svebSe = svebSe;
  table.svebPpv = svebPpv;
  table.rrError = rrError;
  table.runtime = runtime;
  summary = struct();
  summary.kind = 'ecglab.agreement';
  summary.basis = 'summary';
  summary.of = basis;
  summary.records = records;
  summary.excludePaced = excludePaced;
  summary.window = ecgLabValidateField(agreements{1}, 'window', NaN);
  summary.learning = ecgLabValidateField(agreements{1}, 'learning', NaN);
  summary.gross = gross;
  summary.average = average;
  summary.table = table;
  summary.markdown = ecgLabValidateTable(summary);
end
%=============================================================================
function value = ecgLabValidateField(s, name, fallback)
  if isstruct(s) && isfield(s, name)
    value = s.(name);
  else
    value = fallback;
  end
end
%=============================================================================
function value = ecgLabValidateSumRatio(numerator, denominator)
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
function value = ecgLabValidateMean(column, keep)
  use = keep & ~isnan(column);
  if any(use)
    value = mean(column(use));
  else
    value = NaN;
  end
end
%=============================================================================
