%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function [names, papers] = ecgLabDetectMethods()
  % List the detectors, discovered from the folder: each ecgLabDetect<Name>.m
  % is a detector named <name>. The 'methods' and 'consensus' files are
  % excluded. Each detector's reference paper is looked up for the help; an
  % unknown name returns an empty paper.
  here = fileparts(nfilename('fullpath'));
  listing = dir([here, '/ecgLabDetect*.m']);
  exclude = {'methods', 'consensus'};
  known = {};
  for index = 1:numel(listing)
    stem = listing(index).name(1:end - 2);
    name = lower(stem(numel('ecgLabDetect') + 1:end));
    if isempty(name) || any(strcmp(name, exclude))
      continue;
    end
    known{end + 1} = name;
  end
  known = sort(known);
  names = known;
  papers = cell(1, numel(names));
  for index = 1:numel(names)
    papers{index} = ecgLabDetectPaper(names{index});
  end
end
%=============================================================================
function paper = ecgLabDetectPaper(name)
  switch name
    case 'pantompkins'
      paper = ['Pan and Tompkins, A real-time QRS detection algorithm, ', ...
      'IEEE Transactions on Biomedical Engineering 32(3):230-236, 1985.'];
    case 'hamilton'
      paper = ['Hamilton, Open source ECG analysis, ', ...
      'Computers in Cardiology 29:101-104, 2002.'];
    case 'christov'
      paper = ['Christov, Real time electrocardiogram QRS detection using ', ...
      'combined adaptive threshold, BioMedical Engineering OnLine 3:28, 2004.'];
    case 'engzee'
      paper = ['Engelse and Zeelenberg, A single scan algorithm for QRS ', ...
      'detection and feature extraction, Computers in Cardiology 6:37-42, ', ...
      '1979, as modified by Lourenco, Silva, Leite, Lourenco and Fred, ', ...
      'Real time electrocardiogram segmentation for finger based ECG ', ...
      'biometrics, BIOSIGNALS 2012.'];
    case 'wavelet'
      paper = ['Kalidas and Tamil, Real-time QRS detector using ', ...
      'stationary wavelet transform for variable low-cost ECG monitoring, ', ...
      'IEEE BIBE 2017.'];
    case 'elgendi'
      paper = ['Elgendi, Fast QRS detection with an optimized ', ...
      'knowledge-based method: evaluation on 11 standard ECG databases, ', ...
      'PLOS ONE 8(9):e73557, 2013.'];
    case 'wqrs'
      paper = ['Zong, Moody and Jiang, A robust open-source algorithm to ', ...
      'detect onset and duration of QRS complexes, ', ...
      'Computers in Cardiology 30:737-740, 2003.'];
    otherwise
      paper = '';
  end
end
%=============================================================================
