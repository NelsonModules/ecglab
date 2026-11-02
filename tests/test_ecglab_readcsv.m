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
% CSV is a common export format. Every file here is written by this test.
%=============================================================================
folder = tempname();
mkdir(folder);
%=============================================================================
% Named columns, comma separated, no time column, rate given. A non-numeric
% first line is detected as a header and its names become the leads.
path = [folder, '/named.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'I,II,V5\n');
fprintf(fid, '0.10,0.20,0.30\n');
fprintf(fid, '-0.10,-0.20,-0.30\n');
fprintf(fid, '1.00,2.00,3.00\n');
fclose(fid);
recording = ecglab.readcsv(path, 'Rate', 500);
assert_isequal(recording.kind, 'ecglab.recording');
assert_isequal(recording.rate, 500);
assert_isequal(recording.info.format, 'csv');
assert_isequal(recording.leads, {'I', 'II', 'V5'});
assert_isequal(recording.units, {'mV', 'mV', 'mV'});
assert_isequal(size(recording.samples), [3, 3]);
assert_isapprox(recording.samples(:, 1), [0.10; -0.10; 1.00], 1e-9);
assert_isapprox(recording.samples(:, 3), [0.30; -0.30; 3.00], 1e-9);
%=============================================================================
% No header: a numeric first line is data, leads get default names, and the
% delimiter is detected from it.
path = [folder, '/bare.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '0.5,1.5\n-0.5,-1.5\n');
fclose(fid);
bare = ecglab.readcsv(path, 'Rate', 250);
assert_isequal(size(bare.samples), [2, 2]);
assert_isapprox(bare.samples(:, 1), [0.5; -0.5], 1e-9);
assert_isapprox(bare.samples(:, 2), [1.5; -1.5], 1e-9);
%=============================================================================
% Semicolon as the delimiter, detected from the first data line.
path = [folder, '/semi.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'A;B\n1;2\n3;4\n');
fclose(fid);
semi = ecglab.readcsv(path, 'Rate', 100);
assert_isequal(semi.leads, {'A', 'B'});
assert_isapprox(semi.samples, [1, 2; 3, 4], 1e-9);
%=============================================================================
% Tab as the delimiter.
path = [folder, '/tab.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'X\tY\n10\t20\n30\t40\n');
fclose(fid);
tabbed = ecglab.readcsv(path, 'Rate', 100);
assert_isequal(tabbed.leads, {'X', 'Y'});
assert_isapprox(tabbed.samples, [10, 20; 30, 40], 1e-9);
%=============================================================================
% One or more spaces as the delimiter, so runs of spaces split cleanly.
path = [folder, '/spaced.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '0.1   0.2\n0.3   0.4\n');
fclose(fid);
spaced = ecglab.readcsv(path, 'Rate', 100);
assert_isequal(size(spaced.samples), [2, 2]);
assert_isapprox(spaced.samples, [0.1, 0.2; 0.3, 0.4], 1e-9);
%=============================================================================
% A named time column in seconds sets the rate from its median step and is
% dropped from the leads: a 4 ms step is 250 Hz.
path = [folder, '/time_s.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'time,I,II\n');
fprintf(fid, '0.000,0.1,0.2\n');
fprintf(fid, '0.004,0.3,0.4\n');
fprintf(fid, '0.008,0.5,0.6\n');
fprintf(fid, '0.012,0.7,0.8\n');
fclose(fid);
timed = ecglab.readcsv(path);
assert_isapprox(timed.rate, 250, 1e-6);
assert_isequal(timed.leads, {'I', 'II'});
assert_isequal(size(timed.samples), [4, 2]);
assert_isapprox(timed.samples(:, 1), [0.1; 0.3; 0.5; 0.7], 1e-9);
%=============================================================================
% A time column in milliseconds, named so, gives the same 250 Hz rate.
path = [folder, '/time_ms.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'ms,I\n');
fprintf(fid, '0,0.1\n');
fprintf(fid, '4,0.2\n');
fprintf(fid, '8,0.3\n');
fclose(fid);
ms = ecglab.readcsv(path);
assert_isapprox(ms.rate, 250, 1e-6);
assert_isequal(ms.leads, {'I'});
assert_isapprox(ms.samples(:, 1), [0.1; 0.2; 0.3], 1e-9);
%=============================================================================
% A French export: comma decimal mark, so the delimiter must be the semicolon.
path = [folder, '/french.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'I;II\n');
fprintf(fid, '0,10;0,20\n');
fprintf(fid, '-1,50;2,25\n');
fclose(fid);
french = ecglab.readcsv(path, 'Rate', 500, 'Decimal', ',');
assert_isapprox(french.samples, [0.10, 0.20; -1.50, 2.25], 1e-9);
%=============================================================================
% Microvolts are converted to millivolts, so the values are divided by 1000.
path = [folder, '/uv.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '1000,-2000\n500,250\n');
fclose(fid);
uv = ecglab.readcsv(path, 'Rate', 100, 'Units', 'uV');
assert_isequal(uv.units, {'mV', 'mV'});
assert_isapprox(uv.samples, [1.0, -2.0; 0.5, 0.25], 1e-9);
%=============================================================================
% An explicit scale divides the raw values by that number.
path = [folder, '/scaled.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '200,400\n-200,-400\n');
fclose(fid);
scaled = ecglab.readcsv(path, 'Rate', 100, 'Scale', 100);
assert_isapprox(scaled.samples, [2, 4; -2, -4], 1e-9);
%=============================================================================
% The Leads option names the columns, or overrides the names the file carried.
path = [folder, '/bare.csv'];
renamed = ecglab.readcsv(path, 'Rate', 250, 'Leads', {'Ch1', 'Ch2'});
assert_isequal(renamed.leads, {'Ch1', 'Ch2'});
%=============================================================================
% Skip drops leading lines before the data, so header detection sees the real
% first line.
path = [folder, '/banner.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '# exported by the rig\n');
fprintf(fid, '# patient 7\n');
fprintf(fid, 'I,II\n');
fprintf(fid, '0.1,0.2\n0.3,0.4\n');
fclose(fid);
skipped = ecglab.readcsv(path, 'Rate', 250, 'Skip', 2);
assert_isequal(skipped.leads, {'I', 'II'});
assert_isapprox(skipped.samples, [0.1, 0.2; 0.3, 0.4], 1e-9);
%=============================================================================
% TimeColumn forces the first column to be time even without a header saying so.
path = [folder, '/nohdr_time.csv'];
fid = fopen(path, 'wt');
fprintf(fid, '0.00,0.1\n0.01,0.2\n0.02,0.3\n');
fclose(fid);
forced = ecglab.readcsv(path, 'TimeColumn', true);
assert_isapprox(forced.rate, 100, 1e-6);
assert_isequal(size(forced.samples), [3, 1]);
assert_isapprox(forced.samples(:, 1), [0.1; 0.2; 0.3], 1e-9);
%=============================================================================
% With no time column and no rate, the rate is unknown and the error says so.
path = [folder, '/bare.csv'];
assert_checkerror(['ecglab.readcsv(''', strrep(path, char(92), '/'), ''')'], ...
'The sampling rate is unknown; give it with the Rate option.');
%=============================================================================
% An explicit delimiter overrides detection.
path = [folder, '/odd.csv'];
fid = fopen(path, 'wt');
fprintf(fid, 'I|II\n1|2\n3|4\n');
fclose(fid);
odd = ecglab.readcsv(path, 'Rate', 100, 'Delimiter', '|');
assert_isequal(odd.leads, {'I', 'II'});
assert_isapprox(odd.samples, [1, 2; 3, 4], 1e-9);
%=============================================================================
assert_checkerror('ecglab.readcsv(42)', 'The file name must be text.');
assert_checkerror(['ecglab.readcsv(''', strrep([folder, '/absent.csv'], ...
char(92), '/'), ''')'], ...
['The file ', strrep([folder, '/absent.csv'], char(92), '/'), ...
' is not on disk.']);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
