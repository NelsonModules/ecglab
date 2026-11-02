%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function qtc = ecgLabLeadsQtc(qt, rr)
  % The four rate corrections of the global QT, with RR in seconds, QT in
  % milliseconds, HR = 60/RR. No single formula is right across the rate range
  % (survey 5.4): Bazett QT/sqrt(RR), Fridericia QT/RR^(1/3), Framingham
  % QT + 154(1 - RR), Hodges QT + 1.75(HR-60).
  hr = 60 / rr;
  qtc = struct();
  qtc.bazett = qt / sqrt(rr);
  qtc.fridericia = qt / rr ^ (1 / 3);
  qtc.framingham = qt + 154 * (1 - rr);
  qtc.hodges = qt + 1.75 * (hr - 60);
end
%=============================================================================
