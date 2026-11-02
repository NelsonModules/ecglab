%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabSimulateCheck(options)
  % Validate the options: positive rate, positive length, positive heart rate,
  % ectopic fraction in [0, 1], and a non-negative integer seed.
  if ~isnumeric(options.Rate) || ~isscalar(options.Rate) || ...
    ~(options.Rate > 0)
    error('ecglab:badRateRateOnePositiveNumber', 'The rate must be one positive number of hertz.');
  end
  if ~isnumeric(options.Seconds) || ~isscalar(options.Seconds) || ...
    ~(options.Seconds > 0)
    error('ecglab:badSecondsLengthPositiveNumberSeconds', 'The length must be a positive number of seconds.');
  end
  if ~isnumeric(options.HeartRate) || ~isscalar(options.HeartRate) || ...
    ~(options.HeartRate > 0)
    error('ecglab:badHeartRate', 'The heart rate must be a positive number of beats a minute.');
  end
  if ~isnumeric(options.Ectopic) || ~isscalar(options.Ectopic) || ...
    options.Ectopic < 0 || options.Ectopic > 1
    error('ecglab:badEctopicEctopicFractionBetweenZero', 'The ectopic fraction must be between zero and one.');
  end
  if ~isempty(options.Seed) && (~isnumeric(options.Seed) || ...
    ~isscalar(options.Seed) || options.Seed < 0 || ...
    options.Seed ~= round(options.Seed))
    error('ecglab:badSeedSeedNonNegativeInteger', 'The seed must be a non-negative integer.');
  end
end
%=============================================================================
