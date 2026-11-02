%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function intervals = ecgLabDelineateIntervals(sample, rate, rr, qtcWanted)
  % Clinical intervals from the wave samples, in ms, one row per beat. PR is P
  % onset to QRS onset, QRS is onset to offset, QT is QRS onset to T offset; a
  % missing boundary gives NaN. Corrected QT uses RR in seconds and HR = 60/RR.
  toMs = 1000 / rate;
  pr = (sample(:, 4) - sample(:, 1)) * toMs;
  qrs = (sample(:, 8) - sample(:, 4)) * toMs;
  qt = (sample(:, 12) - sample(:, 4)) * toMs;
  rr = rr(:);
  hr = 60 ./ rr;
  qtc = struct();
  % The four standard QTc formulas, each computed only where requested.
  all = {'bazett', 'fridericia', 'framingham', 'hodges'};
  wanted = ecgLabDelineateQtcList(qtcWanted, all);
  if any(strcmp('bazett', wanted))
    qtc.bazett = qt ./ sqrt(rr);
  end
  if any(strcmp('fridericia', wanted))
    qtc.fridericia = qt ./ rr .^ (1 / 3);
  end
  if any(strcmp('framingham', wanted))
    qtc.framingham = qt + 154 * (1 - rr);
  end
  if any(strcmp('hodges', wanted))
    qtc.hodges = qt + 1.75 * (hr - 60);
  end
  intervals = struct('pr', pr, 'qrs', qrs, 'qt', qt, 'qtc', qtc);
end
%=============================================================================
function wanted = ecgLabDelineateQtcList(qtcWanted, all)
  % Which corrections to compute. Empty or 'all' means every one; otherwise a
  % name or a list of names, matched case insensitively.
  if isempty(qtcWanted)
    wanted = all;
    return;
  end
  if (ischar(qtcWanted) || isStringScalar(qtcWanted)) && ...
    strcmpi(char(qtcWanted), 'all')
    wanted = all;
    return;
  end
  if ischar(qtcWanted) || isStringScalar(qtcWanted)
    qtcWanted = {char(qtcWanted)};
  end
  if ~iscell(qtcWanted)
    error('ecglab:badQtcQtcAllFormulaName', 'Qtc must be all, a formula name, or a list of names.');
  end
  wanted = cell(1, numel(qtcWanted));
  for index = 1:numel(qtcWanted)
    name = lower(char(qtcWanted{index}));
    if ~any(strcmp(name, all))
      error('ecglab:badQtcUnknownQtcFormulaS', 'Unknown QTc formula: %s.', name);
    end
    wanted{index} = name;
  end
end
%=============================================================================
