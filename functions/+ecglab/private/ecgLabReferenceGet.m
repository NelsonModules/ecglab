%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function fetched = ecgLabReferenceGet(url, destination, optional)
  % Download one file to DESTINATION via a .part file renamed only once complete.
  % Returns true on success, false when absent and optional, errors otherwise.
  ecgLabReferenceMkdir(ecgLabReferenceParent(destination));
  part = [destination, '.part'];
  if isfile(part)
    % A .part from an interrupted run is stale: delete it.
    delete(part);
  end
  try
    websave(part, url, weboptions('Timeout', 900));
  catch err
    if isfile(part)
      delete(part);
    end
    if ecgLabReferenceNotFound(err)
      if optional
        % Optional file absent: report "not there" and let the caller decide.
        fetched = false;
        return;
      end
      error('ecglab:downloadFailedFileSNotServer', 'The file %s is not on the server (%s).', destination, url);
    end
    error('ecglab:downloadFailedFileSCouldNot', 'The file %s could not be downloaded from %s (%s).', destination, url, err.message);
  end
  % Complete: move it onto the final name.
  movefile(part, destination);
  fetched = true;
end
%=============================================================================
function tf = ecgLabReferenceNotFound(err)
  % True when the error is a 404, so an absent file is told from a broken link.
  text = lower([err.identifier, ' ', err.message]);
  tf = ~isempty(strfind(text, '404')) || ~isempty(strfind(text, 'not found'));
end
%=============================================================================
function parent = ecgLabReferenceParent(path)
  % The directory part of a path, splitting on forward slashes.
  path = strrep(path, char(92), '/');
  cut = strfind(path, '/');
  if isempty(cut)
    parent = '';
    return;
  end
  parent = path(1:cut(end) - 1);
end
%=============================================================================
function ecgLabReferenceMkdir(folder)
  % Create a folder and every parent it needs.
  if isempty(folder) || isfolder(folder)
    return;
  end
  parent = ecgLabReferenceParent(folder);
  if ~isempty(parent) && ~strcmp(parent, folder)
    ecgLabReferenceMkdir(parent);
  end
  if ~isfolder(folder)
    mkdir(folder);
  end
end
%=============================================================================
