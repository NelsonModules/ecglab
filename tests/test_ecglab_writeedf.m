%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
% <--ENGLISH IMPOSED-->
%=============================================================================
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% The writer is proved by the reader: a recording written and read back differs
% only by the sixteen bit quantisation. Every file is written by this test.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% A two-lead recording with annotations, its length not a whole number of
% records, so the last record is padded.
rate = 100;
n = 350;
t = (0:n - 1)' / rate;
samples = [sin(2 * pi * t), 0.5 * cos(2 * pi * t)];
info = struct('subject', 'anonymous', 'startDate', '12/06/2026', ...
  'startTime', '21.30.00', 'startTimeKnown', true);
rec = makeRecording(samples, rate, {'I', 'II'}, {'mV', 'mV'}, info);
% A beat, a ventricular beat, and a free-text note kept in aux under the note
% symbol.
rec.annotations = makeAnnotations([50; 150; 250], ['N'; 'V'; '"'], ...
  {''; ''; 'AFIB (note'}, rate);
%=============================================================================
trip = [folder, '/trip.edf'];
written = ecglab.writeedf(trip, rec);
% The writer reports what it laid down, including the padding, without re-reading.
assert_isequal(written.records, 4);
assert_isequal(written.samplesPerRecord, 100);
assert_istrue(written.padded);
assert_isequal(written.padSamples, 50);
%=============================================================================
back = ecglab.readedf(trip);
assert_isequal(back.kind, 'ecglab.recording');
assert_isequal(back.rate, 100);
assert_isequal(back.leads, {'I', 'II'});
assert_isequal(back.units, {'mV', 'mV'});
assert_isequal(back.info.format, 'edf');
% One LSB of the physical range is the most the reconstruction can differ by.
quantum = (written.physicalMax - written.physicalMin) / 65535;
errors = abs(back.samples(1:n, :) - samples);
assert_istrue(all(max(errors, [], 1) <= quantum));
% The partial last record is padded with the digital minimum.
assert_istrue(size(back.samples, 1) == 400);
assert_isapprox(back.samples(end, 1), written.physicalMin(1), 1e-6);
assert_isapprox(back.samples(end, 2), written.physicalMin(2), 1e-6);
%=============================================================================
% The annotations survive the trip in sample, symbol and aux.
assert_isequal(back.annotations.sample, [50; 150; 250]);
assert_isequal(back.annotations.symbol, ['N'; 'V'; '"']);
assert_isequal(back.annotations.aux, {''; ''; 'AFIB (note'});
%=============================================================================
% 'anonymous' is written as the format's 'X X X X' and read back as 'anonymous';
% the clock and date survive.
assert_isequal(back.info.subject, 'anonymous');
assert_isequal(back.info.startDate, '12/06/2026');
assert_isequal(back.info.startTime, '21.30.00');
assert_istrue(back.info.startTimeKnown);
assert_isfalse(back.info.discontinuous);
%=============================================================================
% A named subject with no spaces round trips as itself, not as anonymous.
named = rec;
named.info.subject = 'Subject01';
namedPath = [folder, '/named.edf'];
ecglab.writeedf(namedPath, named);
backNamed = ecglab.readedf(namedPath);
assert_isequal(backNamed.info.subject, 'Subject01');
%=============================================================================
% The record length is an option: two second records halve the record count.
twoSec = [folder, '/twosec.edf'];
infoTwo = ecglab.writeedf(twoSec, rec, 'RecordSeconds', 2);
assert_isequal(infoTwo.records, 2);
assert_isequal(infoTwo.samplesPerRecord, 200);
backTwo = ecglab.readedf(twoSec);
errorsTwo = abs(backTwo.samples(1:n, :) - samples);
assert_istrue(all(max(errorsTwo, [], 1) <= quantum));
assert_isequal(backTwo.annotations.sample, [50; 150; 250]);
%=============================================================================
% A whole-length recording (no partial record) is not reported as padded.
whole = makeRecording(samples(1:300, :), rate, {'I', 'II'}, {'mV', 'mV'}, info);
wholePath = [folder, '/whole.edf'];
infoWhole = ecglab.writeedf(wholePath, whole);
assert_isequal(infoWhole.records, 3);
assert_isfalse(infoWhole.padded);
%=============================================================================
% Errors: the second argument must be a recording.
assert_checkerror('ecglab.writeedf(''x.edf'', 42)', ...
  'The recording must be an ecglab recording struct.');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function r = makeRecording(samples, rate, leads, units, info)
  % The recording struct every reader returns and writeedf consumes, built here
  % without the private helper.
  r = struct();
  r.kind = 'ecglab.recording';
  r.rate = rate;
  r.samples = samples;
  r.leads = leads;
  r.units = units;
  r.seconds = size(samples, 1) / rate;
  r.info = info;
  r.annotations = makeAnnotations([], '', {}, rate);
  r.gain = 200 * ones(1, size(samples, 2));
  r.baseline = zeros(1, size(samples, 2));
end
%=============================================================================
function a = makeAnnotations(sample, symbol, aux, rate)
  a = struct();
  a.kind = 'ecglab.annotations';
  sample = sample(:);
  count = numel(sample);
  a.sample = sample;
  a.time = (sample - 1) / rate;
  if isempty(symbol)
    symbol = repmat('N', count, 1);
  end
  a.symbol = reshape(char(symbol), [], 1);
  a.num = zeros(count, 1);
  a.subtype = zeros(count, 1);
  a.chan = zeros(count, 1);
  if isempty(aux)
    aux = repmat({''}, count, 1);
  end
  a.aux = reshape(aux, [], 1);
  a.rate = rate;
end
%=============================================================================
