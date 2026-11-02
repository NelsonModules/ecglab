%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
%=============================================================================
% Load the module; each test runs in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
root = fileparts(fileparts(nfilename('fullpath')));
%=============================================================================
% Every public function appears exactly once in the README API table and has
% an English help page, a French help page and a test.
readme = fileread([root, '/README.md']);
public = dir([root, '/functions/+ecglab/*.m']);
for index = 1:numel(public)
  name = public(index).name(1:end - 2);
  row = ['| `ecglab.', name, '` |'];
  assert_isequal(numel(strfind(readme, row)), 1, ...
  ['README API table must name ecglab.', name, ' exactly once']);
  assert_istrue(isfile([root, '/help/en_US/xml/', name, '.xml']), ...
  ['no English help page for ecglab.', name]);
  assert_istrue(isfile([root, '/help/fr_FR/xml/', name, '.xml']), ...
  ['no French help page for ecglab.', name]);
  assert_istrue(isfile([root, '/tests/test_ecglab_', name, '.m']), ...
  ['no test for ecglab.', name]);
end
%=============================================================================
% Every module file is plain ASCII.
folders = {'/functions', '/tests', '/help', '/examples', '/data', '/docs'};
for f = 1:numel(folders)
  files = ecglabTestFiles([root, folders{f}]);
  for index = 1:numel(files)
    text = fileread(files{index});
    bad = text(text > 126 | (text < 32 & text ~= 10 & text ~= 13 & text ~= 9));
    assert_istrue(isempty(bad), ['non ASCII character in ', files{index}]);
  end
end
%=============================================================================
% module.json and ecglab_version must report the same version.
described = jsondecode(fileread([root, '/module.json']));
assert_isequal(ecglab_version(), described.version);
%=============================================================================
function files = ecglabTestFiles(folder)
  % Every regular file under FOLDER at any depth, as full paths; an absent
  % folder gives an empty list.
  files = {};
  if ~isdir(folder)
    return;
  end
  listing = dir(folder);
  for index = 1:numel(listing)
    name = listing(index).name;
    if strcmp(name, '.') || strcmp(name, '..')
      continue;
    end
    path = [folder, '/', name];
    if listing(index).isdir
      files = [files, ecglabTestFiles(path)];
    elseif ~any(strcmp(name, {'.nhz'})) && isempty(strfind(name, '.nhz')) ...
      && isempty(strfind(name, '.mat')) && isempty(strfind(name, '.edf')) ...
      && isempty(strfind(name, '.dat')) && isempty(strfind(name, '.png'))
      files{end + 1} = path;
    end
  end
end
%=============================================================================
