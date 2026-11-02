%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function records = ecgLabReferenceRecords(database)
  % The RECORDS list of a database, as a column cellstr, used to check a record
  % name before fetching. Copied from each database's RECORDS file on
  % 2026-09-12; ptbdb and ptb-xl are fetched and cached instead. afdb omits
  % 00735 and 03665, which carry annotations but no signal.
  switch database
    case 'mitdb'
      records = ecgLabReferenceSplit(['100 101 102 103 104 105 106 107 ', ...
      '108 109 111 112 113 114 115 116 117 118 119 121 122 123 124 200 ', ...
      '201 202 203 205 207 208 209 210 212 213 214 215 217 219 220 221 ', ...
      '222 223 228 230 231 232 233 234']);
    case 'qtdb'
      records = ecgLabReferenceSplit(['sel100 sel102 sel103 sel104 ', ...
      'sel114 sel116 sel117 sel123 sel14046 sel14157 sel14172 sel15814 ', ...
      'sel16265 sel16272 sel16273 sel16420 sel16483 sel16539 sel16773 ', ...
      'sel16786 sel16795 sel17152 sel17453 sel213 sel221 sel223 sel230 ', ...
      'sel231 sel232 sel233 sel30 sel301 sel302 sel306 sel307 sel308 ', ...
      'sel31 sel310 sel32 sel33 sel34 sel35 sel36 sel37 sel38 sel39 ', ...
      'sel40 sel41 sel42 sel43 sel44 sel45 sel46 sel47 sel48 sel49 sel50 ', ...
      'sel51 sel52 sel803 sel808 sel811 sel820 sel821 sel840 sel847 ', ...
      'sel853 sel871 sel872 sel873 sel883 sel891 sele0104 sele0106 ', ...
      'sele0107 sele0110 sele0111 sele0112 sele0114 sele0116 sele0121 ', ...
      'sele0122 sele0124 sele0126 sele0129 sele0133 sele0136 sele0166 ', ...
      'sele0170 sele0203 sele0210 sele0211 sele0303 sele0405 sele0406 ', ...
      'sele0409 sele0411 sele0509 sele0603 sele0604 sele0606 sele0607 ', ...
      'sele0609 sele0612 sele0704']);
    case 'nsrdb'
      records = ecgLabReferenceSplit(['16265 16272 16273 16420 16483 ', ...
      '16539 16773 16786 16795 17052 17453 18177 18184 19088 19090 ', ...
      '19093 19140 19830']);
    case 'afdb'
      records = ecgLabReferenceSplit(['04015 04043 04048 04126 04746 ', ...
      '04908 04936 05091 05121 05261 06426 06453 06995 07162 07859 ', ...
      '07879 07910 08215 08219 08378 08405 08434 08455']);
    case 'nstdb'
      % Twelve ECGs at six noise levels (underscore marks a negative level),
      % plus the three noise records: baseline wander, electrode motion, muscle.
      records = ecgLabReferenceSplit(['118e00 118e06 118e12 118e18 ', ...
      '118e24 118e_6 119e00 119e06 119e12 119e18 119e24 119e_6 bw em ma']);
    case 'ludb'
      % Lobachevsky records are numbered 1 to 200, generated rather than listed.
      records = cell(200, 1);
      for index = 1:200
        records{index} = int2str(index);
      end
    otherwise
      % ptbdb and ptb-xl keep their list on the server; the caller fetches it.
      records = {};
  end
end
%=============================================================================
function records = ecgLabReferenceSplit(text)
  % Split names on single spaces into a column cellstr.
  pieces = strsplit(text, ' ');
  records = {};
  for index = 1:numel(pieces)
    piece = strtrim(pieces{index});
    if ~isempty(piece)
      records{end + 1, 1} = piece;
    end
  end
end
%=============================================================================
