%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function ecgLabStripSave(figureHandle, filename, plan)
  % Save the page, and for SVG set its declared physical size to the page's
  % millimetres so the calibration lands on a ruler.
  %
  % saveas ignores PaperSize and PaperPosition on this build, so the page is
  % drawn in a full-bleed axis whose units are millimetres and the exported
  % picture already covers Wmm by Hmm. For SVG the viewBox is correct and only
  % the root width and height, written in pixels, are rewritten to millimetres.
  % A PNG has no honoured physical size and is written as is.
  saveas(figureHandle, filename);
  if ecgLabStripIsSvg(filename)
    ecgLabStripSvgMillimetres(filename, plan.Wmm, plan.Hmm);
  end
end
%=============================================================================
function tf = ecgLabStripIsSvg(filename)
  name = lower(char(filename));
  tf = numel(name) >= 4 && strcmp(name(end - 3:end), '.svg');
end
%=============================================================================
function ecgLabStripSvgMillimetres(filename, Wmm, Hmm)
  % Rewrite the first (root) width and height of the saved SVG from pixels to
  % millimetres, leaving the viewBox alone. Only the first occurrence: a width
  % or height deeper in the file belongs to a child.
  text = fileread(filename);
  open = strfind(text, '<svg');
  if isempty(open)
    return;
  end
  start = open(1);
  stop = start + strfind(text(start:end), '>');
  stop = stop(1) - 1;
  head = text(start:stop);
  head = ecgLabStripReplaceAttr(head, 'width', sprintf('%.4gmm', Wmm));
  head = ecgLabStripReplaceAttr(head, 'height', sprintf('%.4gmm', Hmm));
  text = [text(1:start - 1), head, text(stop + 1:end)];
  ecgLabStripWrite(filename, text);
end
%=============================================================================
function head = ecgLabStripReplaceAttr(head, name, value)
  % Replace the value of attribute NAME (of the form name="...") inside the
  % element's opening tag with VALUE.
  token = [name, '="'];
  at = strfind(head, token);
  if isempty(at)
    return;
  end
  from = at(1) + numel(token);
  rest = head(from:end);
  quote = strfind(rest, '"');
  quote = quote(1);
  head = [head(1:from - 1), value, rest(quote:end)];
end
%=============================================================================
function ecgLabStripWrite(filename, text)
  fid = fopen(filename, 'w');
  if fid < 0
    error('ecglab:writeFailed', 'Could not write the file %s.', filename);
  end
  fwrite(fid, text, 'char');
  fclose(fid);
end
%=============================================================================
