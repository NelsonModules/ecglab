%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% AGREEMENT = ecglab.validate(TEST, REFERENCE)
% AGREEMENT = ecglab.validate(TEST, REFERENCE, NAME, VALUE, ...)
% AGREEMENT = ecglab.validate(AGREEMENTS)
%
%   Measure a detector against the truth the way ANSI/AAMI EC57 prescribes,
%   and summarise the measurement over a database.
%
%   The first form compares one record. TEST is a beats struct from
%   ecglab.detect, an annotations struct, or a vector of sample indices (or
%   times with 'Unit' 'seconds'). REFERENCE is the truth as an annotations
%   struct (only the beat symbols 'NLRBAaJSVrFejnE/fQ?' are compared) or a
%   vector. A test beat is paired with a reference beat within the matching
%   window; the counts, sensitivity tp / (tp + fn), positive predictivity
%   tp / (tp + fp), timing error and class statistics follow.
%
%   The second form takes a cell array of agreements and returns the summary
%   over the records: the gross figures (pooled counts), the average figures
%   (mean of the per-record rates), the per-record table and its markdown.
%
%   Options (name and value, case insensitive)
%     'Kind'      what is compared: 'beats' (the default). The other kinds
%                 (waves, classes, rhythms) are added as private functions
%                 ecgLabValidate<Kind> and dispatched here by name.
%     'Window'    the matching window in seconds (default 0.15, the EC57
%                 window).
%     'Learning'  the learning period in seconds (default 300): no annotation
%                 before it counts, on either side, because the beat by beat
%                 comparison starts five minutes into the record.
%     'Rate'      the sampling rate in hertz, needed to place a vector of
%                 samples or times against a window measured in seconds.
%     'Unit'      'samples' (the default) or 'seconds' for a vector input.
%     'Table'     the class table passed to ecgLabAami (default 'bxb').
%     'Record'    a name kept in the result.
%     'Paced'     whether the record is one the standard leaves out of the
%                 class statistics. Read from the reference when not given: a
%                 record carrying a paced beat '/' or 'f' is paced.
%     'Shutdown'  true (the default): a test NOISE mark '~' whose subtype has
%                 bits 16 and 32 set opens a shutdown that the next '~'
%                 closes, and reference beats inside it are counted apart.
%
%   Example
%     recording = ecglab.readwfdb('100');
%     beats = ecglab.detect(recording);
%     agreement = ecglab.validate(beats, recording.annotations, 'Record', '100');
%     fprintf('Se %.4f  PPV %.4f\n', agreement.se, agreement.ppv);
%
%   See also ecglab.detect, ecglab.readwfdb.
function agreement = validate(varargin)
  narginchk(1, inf);
  nargoutchk(0, 1);
  % A cell array is per-record agreements to summarise; anything else is a
  % single test-against-reference comparison.
  if iscell(varargin{1})
    agreement = ecgLabValidateSummary(varargin{1}, varargin(2:end));
    return;
  end
  if nargin < 2
    error('ecglab:validateArguments', 'A test and a reference are needed.');
  end
  test = varargin{1};
  reference = varargin{2};
  defaults = struct('Kind', 'beats', 'Window', 0.15, 'Learning', 300, ...
  'Rate', [], 'Unit', 'samples', 'Table', 'bxb', 'Record', '', ...
  'Paced', [], 'Shutdown', true);
  options = ecgLabOptions(defaults, varargin(3:end));
  kind = lower(char(options.Kind));
  switch kind
    case 'beats'
      agreement = ecgLabValidateBeats(test, reference, options);
    otherwise
      % Each kind is a private function ecgLabValidate<Kind>. An undefined one
      % is reported as a kind not yet implemented; other faults pass through.
      name = ['ecgLabValidate', upper(kind(1)), kind(2:end)];
      handler = str2func(name);
      try
        agreement = handler(test, reference, options);
      catch reason
        if strcmp(reason.identifier, 'Nelson:UndefinedFunction')
          error('ecglab:validateKind', 'The kind %s is not implemented yet.', options.Kind);
        end
        rethrow(reason);
      end
  end
end
%=============================================================================
