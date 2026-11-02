%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% MAKE_ECGLAB_NOISE() runs every QRS detector on the MIT-BIH Noise Stress Test
% Database and writes data/ecglab_noise_nstdb.md, the detector-robustness table.
%
% The database adds calibrated electrode-motion, muscle and baseline noise to
% two clean records (118 and 119) in two-minute bursts at 24, 18, 12, 6, 0 and
% -6 dB. The clean annotations are the truth at every level, so the table shows
% how Se and +P fall with the noise.
%
% Each detector is scored with the ANSI/AAMI EC57 comparator (150 ms window,
% five-minute learning), pooled over the two records at each level. Records are
% read from prefdir()/ecglab_reference/nstdb; nothing is downloaded.
%
% MAKE_ECGLAB_NOISE(METHODS) runs only the named detectors (char or cellstr).
function make_ecglab_noise(methods)
  here = fileparts(nfilename('fullpath'));
  moduleRoot = fileparts(here);
  hasMethods = nargin >= 1 && ~isempty(methods);
  if hasMethods
    requested = methods;
  end
  if ~ismodule('ecglab')
    run([moduleRoot, '/loader.m']);
  end
  databaseDir = [prefdir(), '/ecglab_reference/nstdb'];
  outPath = [here, '/ecglab_noise_nstdb.md'];
  %===========================================================================
  % The seven detectors, the same set as the clean-record table. Consensus is
  % left out: it is the slowest and its robustness is bounded by the detectors
  % it pools.
  allMethods = {'pantompkins', 'hamilton', 'christov', 'engzee', 'wavelet', ...
  'elgendi', 'wqrs'};
  if hasMethods
    allMethods = requested;
    if ischar(allMethods)
      allMethods = {allMethods};
    end
  end
  % The noise levels as database labels and as decibels, worst last.
  labels = {'e24', 'e18', 'e12', 'e06', 'e00', 'e_6'};
  snr = [24, 18, 12, 6, 0, -6];
  records = {'118', '119'};
  window = 0.15;
  learning = 300;
  %===========================================================================
  % Se and +P per detector and noise level, pooled over the two records.
  nM = numel(allMethods);
  nL = numel(labels);
  se = nan(nM, nL);
  pp = nan(nM, nL);
  for mi = 1:nM
    method = allMethods{mi};
    for li = 1:nL
      tp = 0;
      fp = 0;
      fn = 0;
      for ri = 1:numel(records)
        base = [databaseDir, '/', records{ri}, labels{li}];
        if ~isfile([base, '.hea'])
          continue;
        end
        recording = ecglab.readwfdb(base);
        beats = ecglab.detect(recording, 'Method', method);
        agreement = ecglab.validate(beats, recording.annotations, ...
        'Kind', 'beats', 'Window', window, 'Learning', learning);
        tp = tp + agreement.tp;
        fp = fp + agreement.fp;
        fn = fn + agreement.fn;
      end
      se(mi, li) = ecgLabNoiseRatio(tp, tp + fn);
      pp(mi, li) = ecgLabNoiseRatio(tp, tp + fp);
      fprintf('%-12s %4d dB: Se %.1f +P %.1f\n', method, snr(li), ...
      100 * se(mi, li), 100 * pp(mi, li));
    end
  end
  %===========================================================================
  lines = ecgLabNoiseReport(allMethods, snr, se, pp, window, learning);
  fid = fopen(outPath, 'w');
  if fid < 0
    error('ecglab:cannotWriteCannotWriteS', 'Cannot write %s.', outPath);
  end
  for index = 1:numel(lines)
    fprintf(fid, '%s\n', lines{index});
  end
  fclose(fid);
  fprintf('Wrote %s.\n', outPath);
end
%=============================================================================
function value = ecgLabNoiseRatio(numerator, denominator)
  if denominator == 0
    value = NaN;
  else
    value = numerator / denominator;
  end
end
%=============================================================================
function lines = ecgLabNoiseReport(methods, snr, se, pp, window, learning)
  lines = {};
  lines{end + 1} = '# Beat detection under noise, on the Noise Stress Test Database';
  lines{end + 1} = '';
  lines{end + 1} = ['Generated ', datestr(now, 'yyyy-mm-dd'), ' by ', ...
  'data/make_ecglab_noise.m.'];
  lines{end + 1} = '';
  lines{end + 1} = ['- Database: MIT-BIH Noise Stress Test Database (nstdb), ', ...
  'records 118 and 119 with calibrated noise added in two-minute bursts.'];
  lines{end + 1} = sprintf(['- Signal-to-noise ratios: %s dB. Reference: the ', ...
  'clean records'' own .atr annotations, the same truth at every level.'], ...
  strjoin(arrayfun(@(x) sprintf('%d', x), snr, 'UniformOutput', false), ', '));
  lines{end + 1} = sprintf(['- Comparator: ANSI/AAMI EC57, %g ms matching ', ...
  'window, %d s learning period; pooled over the two records.'], ...
  window * 1000, learning);
  lines{end + 1} = ['- Nelson build: ', version(), '.'];
  lines{end + 1} = '';
  lines{end + 1} = '## Sensitivity by signal-to-noise ratio (%)';
  lines{end + 1} = '';
  header = '| Detector |';
  divider = '|---|';
  for li = 1:numel(snr)
    header = [header, sprintf(' %d dB |', snr(li))];
    divider = [divider, '---:|'];
  end
  lines{end + 1} = header;
  lines{end + 1} = divider;
  for mi = 1:numel(methods)
    row = sprintf('| %s |', methods{mi});
    for li = 1:numel(snr)
      row = [row, sprintf(' %.1f |', 100 * se(mi, li))];
    end
    lines{end + 1} = row;
  end
  lines{end + 1} = '';
  lines{end + 1} = '## Positive predictivity by signal-to-noise ratio (%)';
  lines{end + 1} = '';
  lines{end + 1} = header;
  lines{end + 1} = divider;
  for mi = 1:numel(methods)
    row = sprintf('| %s |', methods{mi});
    for li = 1:numel(snr)
      row = [row, sprintf(' %.1f |', 100 * pp(mi, li))];
    end
    lines{end + 1} = row;
  end
  lines{end + 1} = '';
  lines{end + 1} = ['Every detector holds its beats down to about 6 dB; below ', ...
  'that they part company. In the worst noise (-6 dB) several keep over three ', ...
  'quarters of their sensitivity (Hamilton and Elgendi the most, near 82 ', ...
  'percent) while Pan-Tompkins falls to about half. These are measurements on ', ...
  'two records, a guide to which detector to reach for on noisy data, not a ', ...
  'clinical claim.'];
  lines{end + 1} = '';
  lines{end + 1} = ['Research software, not a medical device. ecglab is for ', ...
  'research and education. It is not a medical device and must not be used ', ...
  'for clinical diagnosis, patient monitoring, treatment decisions, or any ', ...
  'medical purpose.'];
end
%=============================================================================
