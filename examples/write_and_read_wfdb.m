%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Write a recording and its beats as a WFDB record, and read it back.
%
% WFDB is the format the open databases use. ecglab.writewfdb writes the
% header, signal and annotation files; ecglab.readwfdb reads them back into a
% recording struct. The round trip matches the original within the format's
% quantisation step.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: write a WFDB record and read it back ===');

% The simulated recording already carries beat annotations, so the round trip
% writes and reads an annotation file as well as the signal.
recording = ecglab.simulate('Seconds', 20, 'Rate', 360, 'HeartRate', 72, ...
'Leads', 2, 'Seed', 6);
fprintf('Simulated %d leads with %d annotations.\n', numel(recording.leads), ...
numel(recording.annotations.sample));

name = [tempdir(), 'ecglab_example_record'];
ecglab.writewfdb(name, recording);
fprintf('Wrote %s.hea, .dat and .atr.\n', name);

back = ecglab.readwfdb(name);
signalError = max(abs(back.samples(:) - recording.samples(:)));
fprintf('Read back %d leads, %d samples; largest signal error %.4f mV.\n', ...
numel(back.leads), size(back.samples, 1), signalError);
fprintf('Annotations returned: %d.\n', numel(back.annotations.sample));

% Clean up the temporary files.
for ext = {'.hea', '.dat', '.atr'}
  f = [name, ext{1}];
  if isfile(f)
    delete(f);
  end
end
disp('=== done ===');
%=============================================================================
