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
% ecglab.leads derives the missing standard leads from I and II, measures the
% frontal axis and global intervals, corrects the QT four ways and flags each
% against the normal range. The derivations are exact algebra, asserted to the
% sample; the axis is checked on scaled copies of one beat, where the angle is
% known in closed form.
rate = 500;
%=============================================================================
% A clean one-lead beat train, the template each constructed lead is a scaled
% copy of: scaling a lead scales its net QRS area, so atan2 of two such areas
% is atan2 of the two constants, a known frontal axis.
sim = ecglab.simulate('Seconds', 20, 'Rate', rate, 'HeartRate', 72, 'Seed', 3);
s = sim.samples(:, 1);
N = numel(s);
%=============================================================================
% The derived leads are exact from I and II: III = II - I, aVR = -(I + II) / 2,
% aVL = I - II / 2, aVF = II - I / 2. I and II are two different scaled copies
% so the four derivations are distinct.
I0 = 0.6 * s;
II0 = 1.0 * s;
recLimb = localLeadsRec({'I', 'II'}, [I0, II0], rate);
res = ecglab.leads(recLimb);
assert_isequal(res.kind, 'ecglab.leads');
der = res.derived;
assert_isequal(der.kind, 'ecglab.recording');
% The six limb leads are all present and in the standard order, I and II first
% and unchanged, the other four the exact combinations.
assert_isequal(der.leads(1:6), {'I', 'II', 'III', 'aVR', 'aVL', 'aVF'});
col = @(name) der.samples(:, find(strcmpi(name, der.leads), 1));
assert_istrue(max(abs(col('I') - I0)) == 0);
assert_istrue(max(abs(col('II') - II0)) == 0);
assert_istrue(max(abs(col('III') - (II0 - I0))) < 1e-12);
assert_istrue(max(abs(col('aVR') - (-(I0 + II0) / 2))) < 1e-12);
assert_istrue(max(abs(col('aVL') - (I0 - II0 / 2))) < 1e-12);
assert_istrue(max(abs(col('aVF') - (II0 - I0 / 2))) < 1e-12);
%=============================================================================
% Given all twelve leads, the derivation leaves every present lead unchanged,
% never recomputing one. Twelve different scaled copies, each surviving to the
% sample.
allNames = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
'V4', 'V5', 'V6'};
gains = [0.6, 1.0, 0.4, -0.8, 0.1, 0.7, -0.5, 0.4, 0.6, 0.8, 1.0, 1.2];
X12 = s * gains;
rec12 = localLeadsRec(allNames, X12, rate);
res12 = ecglab.leads(rec12);
assert_isequal(res12.derived.leads, allNames);
for c = 1:12
  assert_istrue(max(abs(res12.derived.samples(:, c) - X12(:, c))) == 0);
end
%=============================================================================
% The frontal axis from the net QRS area. On leads cI * s and cF * s the axis
% is atan2d(cF, cI) exactly, with aVF given directly. cI = cF = 1 gives
% +45 degrees.
rec45 = localLeadsRec({'I', 'II', 'aVF'}, [1.0 * s, 1.0 * s, 1.0 * s], rate);
a45 = ecglab.leads(rec45).axis;
fprintf('Axis cI=cF=1: %.4f deg (expect 45)\n', a45.degrees);
assert_istrue(abs(a45.degrees - 45) < 0.5);
assert_isequal(a45.label, 'normal');
% A positive lead I and a zero-area aVF gives 0 degrees.
rec0 = localLeadsRec({'I', 'II', 'aVF'}, [1.0 * s, 1.0 * s, 0 * s], rate);
a0 = ecglab.leads(rec0).axis;
fprintf('Axis cI=1 cF=0: %.4f deg (expect 0)\n', a0.degrees);
assert_istrue(abs(a0.degrees - 0) < 0.5);
assert_isequal(a0.label, 'normal');
%=============================================================================
% The labels fire at the boundaries. Normal is -30 to +90 inclusive, left
% below -30 (to -90), right above +90 (to +180), extreme beyond -90. A point
% on the unit circle sets each target angle, just inside and just outside.
cases = { ...
  -30, 'normal'; ...
  -31, 'left'; ...
  -45, 'left'; ...
  -90, 'left'; ...
  -91, 'extreme'; ...
  -135, 'extreme'; ...
  45, 'normal'; ...
  90, 'normal'; ...
  91, 'right'; ...
  135, 'right'};
for i = 1:size(cases, 1)
  theta = cases{i, 1};
  cI = cosd(theta);
  cF = sind(theta);
  recT = localLeadsRec({'I', 'II', 'aVF'}, [cI * s, 1.0 * s, cF * s], rate);
  aT = ecglab.leads(recT).axis;
  fprintf('Axis target %d: %.2f deg -> %s (expect %s)\n', theta, ...
  aT.degrees, aT.label, cases{i, 2});
  assert_istrue(abs(aT.degrees - theta) < 0.5);
  assert_isequal(aT.label, cases{i, 2});
end
%=============================================================================
% The global QT is at least as long as any single lead's (the AHA
% superimposed-lead rule), checked on a twelve-lead record against each lead's
% median QT on the same beats.
recQt = ecglab.simulate('Seconds', 20, 'Rate', rate, 'HeartRate', 60, ...
'Leads', 12, 'Seed', 5);
beatsQt = ecglab.detect(recQt);
resQt = ecglab.leads(recQt);
globalQt = resQt.intervals.qt;
fprintf('Global QT %.1f ms\n', globalQt);
for c = 1:12
  wl = ecglab.delineate(recQt, 'Lead', recQt.leads{c}, 'Beats', beatsQt);
  single = median(wl.intervals.qt, 'omitnan');
  if isfinite(single)
    fprintf('  lead %s single QT %.1f\n', recQt.leads{c}, single);
    assert_istrue(globalQt >= single - 1e-6);
  end
end
%=============================================================================
% The four QTc formulas match a hand computation from the global QT and the
% representative RR = 60 / heartRate: Bazett QT/sqrt(RR), Fridericia QT/RR^(1/3),
% Framingham QT + 154(1 - RR), Hodges QT + 1.75(HR - 60).
RR = 60 / resQt.heartRate;
HR = resQt.heartRate;
qt = resQt.intervals.qt;
assert_istrue(abs(resQt.qtc.bazett - qt / sqrt(RR)) < 1e-6);
assert_istrue(abs(resQt.qtc.fridericia - qt / RR ^ (1 / 3)) < 1e-6);
assert_istrue(abs(resQt.qtc.framingham - (qt + 154 * (1 - RR))) < 1e-6);
assert_istrue(abs(resQt.qtc.hodges - (qt + 1.75 * (HR - 60))) < 1e-6);
%=============================================================================
% The normal-range flags. On the normal simulated record every interval sits
% in its range and the flags agree with the plain numeric comparison.
nrm = resQt.normal;
assert_isequal(nrm.pr.inRange, resQt.intervals.pr >= nrm.pr.low & ...
resQt.intervals.pr <= nrm.pr.high);
assert_isequal(nrm.qrs.inRange, resQt.intervals.qrs < nrm.qrs.high);
assert_isequal(nrm.axis.inRange, strcmp(resQt.axis.label, 'normal'));
%=============================================================================
% A flag fires on an out-of-range measurement: a left-axis recording (cI = 1,
% cF = -1 gives -45 degrees) is outside the normal band, so the axis flag is
% false and the label 'left'.
recLeft = localLeadsRec({'I', 'II', 'aVF'}, [1.0 * s, 1.0 * s, -1.0 * s], rate);
resLeft = ecglab.leads(recLeft);
assert_isequal(resLeft.axis.label, 'left');
assert_isfalse(resLeft.normal.axis.inRange);
% A QTc flag fires on a fast rhythm, where Bazett over-corrects: at a short RR
% the corrected QT is pushed past the limit.
recFast = ecglab.simulate('Seconds', 20, 'Rate', rate, 'HeartRate', 140, ...
'Leads', 12, 'Seed', 8);
resFast = ecglab.leads(recFast);
fprintf('Fast rhythm: HR %.0f, QTc bazett %.0f ms, limit %.0f, inRange %d\n', ...
resFast.heartRate, resFast.qtc.bazett, resFast.normal.qtc.limit, ...
resFast.normal.qtc.inRange);
assert_istrue(resFast.qtc.bazett > resFast.normal.qtc.limit);
assert_isfalse(resFast.normal.qtc.inRange);
%=============================================================================
% Sokolow-Lyon: S in V1 plus the larger of R in V5 and V6, in mV, and whether
% it clears 3.5 mV. V1 is a downward copy, V5 and V6 upright copies; with the
% ~1 mV template, -2 s in V1 and 2 s in V5 give about 4 mV, over threshold.
peak = max(s);
recSL = localLeadsRec({'I', 'II', 'V1', 'V5', 'V6'}, ...
[0.6 * s, 1.0 * s, -2.0 * s, 2.0 * s, 1.5 * s], rate);
resSL = ecglab.leads(recSL);
assert_istrue(isfield(resSL, 'sokolowLyon'));
sl = resSL.sokolowLyon;
fprintf('Sokolow-Lyon: SV1 %.2f RV5 %.2f RV6 %.2f amp %.2f mV exceeds %d\n', ...
sl.sV1, sl.rV5, sl.rV6, sl.amplitude, sl.exceeds);
% S in V1 is about 2 peak, R in V5 about 2 peak, so the sum is about 4 peak.
assert_istrue(abs(sl.sV1 - 2 * peak) < 0.2 * peak);
assert_istrue(abs(sl.rV5 - 2 * peak) < 0.2 * peak);
assert_istrue(abs(sl.amplitude - (sl.sV1 + max(sl.rV5, sl.rV6))) < 1e-9);
assert_istrue(sl.amplitude > 3.5);
assert_istrue(sl.exceeds);
% A sub-threshold precordial set: V1 and V5 one peak each, about 2 mV total.
recSL2 = localLeadsRec({'I', 'II', 'V1', 'V5', 'V6'}, ...
[0.6 * s, 1.0 * s, -1.0 * s, 1.0 * s, 0.8 * s], rate);
sl2 = ecglab.leads(recSL2).sokolowLyon;
fprintf('Sokolow-Lyon low: amp %.2f mV exceeds %d\n', sl2.amplitude, sl2.exceeds);
assert_istrue(sl2.amplitude < 3.5);
assert_isfalse(sl2.exceeds);
% With no precordials, there is no Sokolow-Lyon field.
assert_isfalse(isfield(ecglab.leads(recLimb), 'sokolowLyon'));
%=============================================================================
% A matrix input with Rate and Leads is read like a recording.
resM = ecglab.leads(X12, 'Rate', rate, 'Leads', allNames);
assert_isequal(resM.kind, 'ecglab.leads');
assert_isequal(resM.derived.leads, allNames);
%=============================================================================
% Errors: a recording without the limb leads, a bad option name, and a matrix
% with no Rate are each refused.
failed = false;
try
  ecglab.leads(localLeadsRec({'V1', 'V2'}, [s, 0.5 * s], rate));
catch
  failed = true;
end
assert_istrue(failed);
failed = false;
try
  ecglab.leads(recLimb, 'NoSuchOption', 1);
catch
  failed = true;
end
assert_istrue(failed);
failed = false;
try
  ecglab.leads(X12, 'Leads', allNames);
catch
  failed = true;
end
assert_istrue(failed);
%=============================================================================
% A real twelve-lead record proves the measurements run on measured data. Read
% only if the Lobachevsky database is on disk; the axis and intervals must sit
% in the physiological range (axis -90 to +120 degrees, QRS 60 to 140 ms).
ludbOne = [prefdir(), '/ecglab_reference/ludb/data/1.hea'];
if isfile(ludbOne)
  realRec = ecglab.reference('ludb/1', 'Download', false);
  resReal = ecglab.leads(realRec);
  fprintf('ludb/1 axis %.1f deg (%s), PR %.0f QRS %.0f QT %.0f ms, HR %.0f\n', ...
  resReal.axis.degrees, resReal.axis.label, resReal.intervals.pr, ...
  resReal.intervals.qrs, resReal.intervals.qt, resReal.heartRate);
  fprintf('ludb/1 QTc bazett %.0f fridericia %.0f framingham %.0f hodges %.0f\n', ...
  resReal.qtc.bazett, resReal.qtc.fridericia, resReal.qtc.framingham, ...
  resReal.qtc.hodges);
  assert_istrue(resReal.axis.degrees >= -90 && resReal.axis.degrees <= 120);
  assert_istrue(resReal.intervals.qrs >= 60 && resReal.intervals.qrs <= 140);
else
  disp('Lobachevsky database not on disk: the real-record check is skipped.');
end
%=============================================================================
function rec = localLeadsRec(names, samples, rate)
  % A minimal recording of named leads, built column by column, so a test can
  % check the derivation and measurements against the leads it planted.
  rec = struct('kind', 'ecglab.recording', 'rate', rate, 'samples', samples, ...
  'leads', {names}, 'units', {repmat({'mV'}, 1, numel(names))}, ...
  'seconds', size(samples, 1) / rate, ...
  'info', struct('name', 'syn', 'source', '', 'format', 'simulated'), ...
  'annotations', []);
end
%=============================================================================
