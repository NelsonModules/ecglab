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
%=============================================================================
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ISHNE is a Holter recorder format. Every file here is written by this test.
%=============================================================================
folder = tempname();
mkdir(folder);
%=============================================================================
% Two leads, a non-empty variable block, and raw values crossing zero across
% the full sixteen bit range.
path = [folder, '/two.ecg'];
rawI = [-32768; -1; 0; 32767];
rawII = [100; -100; 2000; -2000];
resolution = [1000, 5000];
interleaved = reshape([rawI, rawII].', [], 1);
header = ecgTestIshneHeader(2, [5, 6], resolution, 200, ...
'Jane', 'Doe', 'SUBJ-7', [15, 6, 2026], [21, 30, 45], 'a comment block');
ecgTestWriteIshne(path, header, 'a comment block', interleaved);
recording = ecglab.readishne(path);
assert_isequal(recording.kind, 'ecglab.recording');
assert_isequal(recording.rate, 200);
assert_isequal(recording.info.format, 'ishne');
assert_isequal(recording.leads, {'I', 'II'});
assert_isequal(recording.units, {'mV', 'mV'});
assert_isequal(size(recording.samples), [4, 2]);
% Physical equals raw times resolution in nanovolts divided by a million.
assert_isapprox(recording.samples(:, 1), rawI * 1000 / 1e6, 1e-12);
assert_isapprox(recording.samples(:, 2), rawII * 5000 / 1e6, 1e-12);
% The name comes from the two name fields, the date and clock from the record.
assert_isequal(recording.info.subject, 'Jane Doe');
assert_isequal(recording.info.startDate, '15/06/2026');
assert_isequal(recording.info.startTime, '21.30.45');
assert_istrue(recording.info.startTimeKnown);
% The variable block is free text, kept as a comment.
assert_isequal(recording.info.comments, {'a comment block'});
%=============================================================================
% Three leads, an empty variable block, values crossing zero. The data begins
% right after the fixed header.
path = [folder, '/three.ecg'];
rawX = [1; -1; 10];
rawY = [-5; 5; -50];
rawZ = [0; 1000; -1000];
resolution3 = [2000, 2000, 2000];
interleaved = reshape([rawX, rawY, rawZ].', [], 1);
header = ecgTestIshneHeader(3, [2, 3, 4], resolution3, 250, ...
'', '', '', [1, 1, 2020], [0, 0, 0], '');
ecgTestWriteIshne(path, header, '', interleaved);
three = ecglab.readishne(path);
assert_isequal(three.rate, 250);
assert_isequal(three.leads, {'X', 'Y', 'Z'});
assert_isequal(size(three.samples), [3, 3]);
assert_isapprox(three.samples(:, 1), rawX * 2000 / 1e6, 1e-12);
assert_isapprox(three.samples(:, 3), rawZ * 2000 / 1e6, 1e-12);
% No names, so the subject is empty; an all-zero start time is the placeholder,
% so startTimeKnown is false.
assert_isequal(three.info.subject, '');
assert_isfalse(three.info.startTimeKnown);
assert_isequal(three.info.comments, {});
%=============================================================================
% A file without the magic bytes is not an ISHNE file.
path = [folder, '/bad.ecg'];
fid = fopen(path, 'wb');
fwrite(fid, double('NOTISHNE'), 'uint8');
fwrite(fid, zeros(1, 600), 'uint8');
fclose(fid);
assert_checkerror(['ecglab.readishne(''', strrep(path, char(92), '/'), ''')'], ...
'The file is not an ISHNE recording; the magic ISHNE1.0 is missing.');
%=============================================================================
assert_checkerror('ecglab.readishne(42)', 'The file name must be text.');
assert_checkerror(['ecglab.readishne(''', strrep([folder, '/none.ecg'], ...
char(92), '/'), ''')'], ...
['The file ', strrep([folder, '/none.ecg'], char(92), '/'), ...
' is not on disk.']);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function header = ecgTestIshneHeader(nLeads, leadSpec, resolution, rate, ...
  firstName, lastName, id, recordDate, startTime, variableBlock)
  % Build the 512 byte fixed header as the standard lays it out. Offsets are
  % one based inside the block, which begins at file byte 11.
  header = zeros(1, 512);
  blockSize = numel(variableBlock);
  header = ecgTestSetInt32(header, 1, blockSize);
  header = ecgTestSetInt32(header, 5, 0);
  header = ecgTestSetInt32(header, 9, 522);
  header = ecgTestSetInt32(header, 13, 522 + blockSize);
  header = ecgTestSetInt16(header, 17, 10);
  header = ecgTestSetChar(header, 19, firstName, 40);
  header = ecgTestSetChar(header, 59, lastName, 40);
  header = ecgTestSetChar(header, 99, id, 20);
  header = ecgTestSetInt16(header, 119, 0);
  header = ecgTestSetInt16(header, 121, 0);
  header = ecgTestSetInt16(header, 123, [1, 1, 1970]);
  header = ecgTestSetInt16(header, 129, recordDate);
  header = ecgTestSetInt16(header, 135, [1, 1, 1970]);
  header = ecgTestSetInt16(header, 141, startTime);
  header = ecgTestSetInt16(header, 147, nLeads);
  spec = zeros(1, 12);
  spec(1:numel(leadSpec)) = leadSpec;
  header = ecgTestSetInt16(header, 149, spec);
  header = ecgTestSetInt16(header, 173, zeros(1, 12));
  res = zeros(1, 12);
  res(1:numel(resolution)) = resolution;
  header = ecgTestSetInt16(header, 197, res);
  header = ecgTestSetInt16(header, 221, 0);
  header = ecgTestSetChar(header, 223, 'test recorder', 40);
  header = ecgTestSetInt16(header, 263, rate);
  header = ecgTestSetChar(header, 265, '', 80);
  header = ecgTestSetChar(header, 345, '', 80);
  header = ecgTestSetChar(header, 425, '', 88);
end
%=============================================================================
function header = ecgTestSetInt32(header, pos, values)
  for index = 1:numel(values)
    value = mod(values(index), 4294967296);
    base = pos + 4 * (index - 1);
    header(base) = mod(value, 256);
    header(base + 1) = mod(floor(value / 256), 256);
    header(base + 2) = mod(floor(value / 65536), 256);
    header(base + 3) = mod(floor(value / 16777216), 256);
  end
end
%=============================================================================
function header = ecgTestSetInt16(header, pos, values)
  for index = 1:numel(values)
    value = mod(values(index), 65536);
    base = pos + 2 * (index - 1);
    header(base) = mod(value, 256);
    header(base + 1) = floor(value / 256);
  end
end
%=============================================================================
function header = ecgTestSetChar(header, pos, text, width)
  text = double(text);
  keep = min(numel(text), width);
  header(pos:pos + keep - 1) = text(1:keep);
end
%=============================================================================
function ecgTestWriteIshne(path, header, variableBlock, samples)
  fid = fopen(path, 'wb');
  fwrite(fid, double('ISHNE1.0'), 'uint8');
  fwrite(fid, [0, 0], 'uint8');
  fwrite(fid, header, 'uint8');
  if ~isempty(variableBlock)
    fwrite(fid, double(variableBlock), 'uint8');
  end
  bytes = zeros(1, 2 * numel(samples));
  for index = 1:numel(samples)
    value = mod(samples(index), 65536);
    bytes(2 * index - 1) = mod(value, 256);
    bytes(2 * index) = floor(value / 256);
  end
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
