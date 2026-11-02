%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function normal = ecgLabLeadsNormal(pr, qrs, qtcBazett, axis, sex)
  % AHA/ACC/HRS normal ranges beside each measurement, with an in-range flag
  % (survey 5.4). Reference ranges, not a diagnosis. PR 120 to 200 ms; QRS
  % under 120 ms; QTc under 450 ms (men) or 460 (women) by Bazett; frontal axis
  % normal -30 to +90.
  limit = ecgLabLeadsQtcLimit(sex);
  normal = struct();
  normal.pr = struct('low', 120, 'high', 200, 'value', pr, ...
  'inRange', pr >= 120 && pr <= 200);
  normal.qrs = struct('high', 120, 'value', qrs, 'inRange', qrs < 120);
  normal.qtc = struct('limit', limit, 'sex', ecgLabLeadsSex(sex), ...
  'value', qtcBazett, 'inRange', qtcBazett < limit);
  normal.axis = struct('low', -30, 'high', 90, 'value', axis.degrees, ...
  'inRange', strcmp(axis.label, 'normal'));
end
%=============================================================================
function limit = ecgLabLeadsQtcLimit(sex)
  % The QTc upper normal limit: 450 ms for men, 460 for women (survey 5.4).
  if strcmp(ecgLabLeadsSex(sex), 'female')
    limit = 460;
  else
    limit = 450;
  end
end
%=============================================================================
function name = ecgLabLeadsSex(sex)
  % The sex the QTc limit is chosen for. Anything but female is treated as
  % male, the stricter limit.
  sex = lower(char(sex));
  if any(strcmp(sex, {'female', 'f', 'woman', 'w'}))
    name = 'female';
  else
    name = 'male';
  end
end
%=============================================================================
