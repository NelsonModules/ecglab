%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function text = ecgLabValidateTable(agreement)
  % Render a summary as the markdown table the README prints: one row per
  % record, then the gross and average rows, with a caption stating the window
  % and learning period.
  if ~isstruct(agreement) || ~isfield(agreement, 'table')
    error('ecglab:validateTable', 'A summary with a table is needed to render.');
  end
  t = agreement.table;
  newline = char(10);
  header = ['| Record | TP | FP | FN | Se | PPV | VEB Se | VEB PPV | ', ...
  'SVEB Se | SVEB PPV | RR RMS (ms) | Runtime (s) |'];
  divider = ['|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|', ...
  '---:|'];
  rows = {header; divider};
  for index = 1:numel(t.record)
    rows{end + 1, 1} = ecgLabValidateRow(t.record{index}, t.tp(index), ...
    t.fp(index), t.fn(index), t.se(index), t.ppv(index), ...
    t.vebSe(index), t.vebPpv(index), t.svebSe(index), t.svebPpv(index), ...
    t.rrError(index), t.runtime(index));
  end
  % The gross row carries pooled counts and their rates; the average row
  % carries only rates, so its count cells are blank.
  g = agreement.gross;
  a = agreement.average;
  rows{end + 1, 1} = ecgLabValidateRow('Gross', g.tp, g.fp, g.fn, g.se, ...
  g.ppv, g.vebSe, g.vebPpv, g.svebSe, g.svebPpv, NaN, NaN);
  rows{end + 1, 1} = ['| Average |  |  |  | ', ...
  ecgLabValidateRate(a.se), ' | ', ecgLabValidateRate(a.ppv), ' | ', ...
  ecgLabValidateRate(a.vebSe), ' | ', ecgLabValidateRate(a.vebPpv), ...
  ' | ', ecgLabValidateRate(a.svebSe), ' | ', ...
  ecgLabValidateRate(a.svebPpv), ' |  |  |'];
  caption = sprintf('_Window %g ms, learning period %g s._', ...
  agreement.window * 1000, agreement.learning);
  rows{end + 1, 1} = '';
  rows{end + 1, 1} = caption;
  text = strjoin(rows', newline);
end
%=============================================================================
function row = ecgLabValidateRow(name, tp, fp, fn, se, ppv, vebSe, vebPpv, ...
  svebSe, svebPpv, rr, runtime)
  row = ['| ', name, ' | ', ecgLabValidateInt(tp), ' | ', ...
  ecgLabValidateInt(fp), ' | ', ecgLabValidateInt(fn), ' | ', ...
  ecgLabValidateRate(se), ' | ', ecgLabValidateRate(ppv), ' | ', ...
  ecgLabValidateRate(vebSe), ' | ', ecgLabValidateRate(vebPpv), ' | ', ...
  ecgLabValidateRate(svebSe), ' | ', ecgLabValidateRate(svebPpv), ' | ', ...
  ecgLabValidateMs(rr), ' | ', ecgLabValidateSecs(runtime), ' |'];
end
%=============================================================================
function text = ecgLabValidateInt(value)
  if isnan(value)
    text = '-';
  else
    text = sprintf('%d', round(value));
  end
end
%=============================================================================
function text = ecgLabValidateRate(value)
  % An undefined rate prints as a dash, not a zero, so an absence of beats is
  % not read as a failed detector.
  if isnan(value)
    text = '-';
  else
    text = sprintf('%.4f', value);
  end
end
%=============================================================================
function text = ecgLabValidateMs(value)
  if isnan(value)
    text = '-';
  else
    text = sprintf('%.1f', value);
  end
end
%=============================================================================
function text = ecgLabValidateSecs(value)
  if isnan(value)
    text = '-';
  else
    text = sprintf('%.2f', value);
  end
end
%=============================================================================
