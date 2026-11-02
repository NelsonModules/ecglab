%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Draw the three reading pages: the calibrated strip, the chart, the beat.
%
% ecglab.strip draws the ECG on calibrated paper (25 mm/s, 10 mm/mV),
% ecglab.chart the one-page record summary, and ecglab.beat one beat. All
% three are drawn and saved to the temporary directory. Needs a figure session
% (advanced CLI or desktop).
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: the three reading pages ===');

recording = ecglab.simulate('Seconds', 12, 'Rate', 360, 'HeartRate', 72, ...
'Ectopic', 0.08, 'Leads', 12, 'Seed', 7);
analysis = ecglab.analyze(recording);

% The calibrated twelve-lead page, the clinical 3x4 layout with a rhythm strip.
stripFile = [tempdir(), 'ecglab_example_strip.png'];
ecglab.strip(recording, 'OutputImage', stripFile);
fprintf('Strip drawn and saved to %s.\n', stripFile);

% The summary page of the whole record: the tiles, the lanes and the evidence.
chartFile = [tempdir(), 'ecglab_example_chart.png'];
ecglab.chart(analysis, 'OutputImage', chartFile);
fprintf('Chart drawn and saved to %s.\n', chartFile);

% One beat, with the detector evidence and the class card. Open on the tenth.
beatFile = [tempdir(), 'ecglab_example_beat.png'];
ecglab.beat(analysis, 'Beat', 10, 'Interactive', false, 'OutputImage', beatFile);
fprintf('Beat drawn and saved to %s.\n', beatFile);
disp('=== done ===');
%=============================================================================
