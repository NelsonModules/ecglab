%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% <--ADV-CLI MODE-->
%=============================================================================
% External module: each test loads it in its own process.
if ~ismodule('ecglab')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% ecglab.strip draws the twelve-lead ECG on calibrated grid paper at 25 mm/s
% and 10 mm/mV. The test checks that calibration in data units of millimetres,
% including the exported SVG size. Every figure is drawn invisible and closed.
tmp = tempdir();
%=============================================================================
% A simulated twelve-lead record, twelve seconds so the 3x4 window and the
% rhythm strip both have data.
rec = ecglab.simulate('Seconds', 12, 'Rate', 360, 'Leads', 12, 'Seed', 1);
%=============================================================================
% The default 3x4 page draws without error and returns a figure handle.
h = ecglab.strip(rec, 'Visible', 'off');
assert_istrue(isgraphics(h, 'figure'));
plan = get(h, 'UserData');
%=============================================================================
% The page axis and every panel axis exist, found by their tag.
assert_isequal(numel(findobj(h, 'Tag', 'ecglab.strip')), 1);
leadTags = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', ...
'V4', 'V5', 'V6'};
for k = 1:numel(leadTags)
  ax = findobj(h, 'Tag', ['ecglab.strip.', leadTags{k}]);
  assert_isequal(numel(ax), 1, ['missing panel axis for ', leadTags{k}]);
end
assert_isequal(numel(findobj(h, 'Tag', 'ecglab.strip.rhythm')), 1);
%=============================================================================
% A panel trace has one point per sample, spanning PanelSeconds * Speed mm.
% Lead II, column 1 of the 3x4, shows [0, 2.5] s.
speed = plan.speed;
gain = plan.gain;
axII = findobj(h, 'Tag', 'ecglab.strip.II');
lnII = findobj(axII, 'Type', 'line');
xII = get(lnII, 'XData');
rate = rec.rate;
panelSeconds = 2.5;
first = max(1, floor(0 * rate) + 1);
last = min(size(rec.samples, 1), floor(panelSeconds * rate));
expected = last - first + 1;
fprintf('II panel: %d points (expect %d)\n', numel(xII), expected);
assert_isequal(numel(xII), expected);
xExtent = max(xII) - min(xII);
fprintf('II x-extent %.3f mm (expect %.3f = %g s * %g mm/s)\n', xExtent, ...
panelSeconds * speed, panelSeconds, speed);
assert_istrue(abs(xExtent - panelSeconds * speed) <= 2 * speed / rate);
%=============================================================================
% A 1 mV calibration deflection is Gain mm tall. Each pulse is a line tagged
% 'ecglab.strip.calibration' spanning Gain in y.
cal = findobj(h, 'Tag', 'ecglab.strip.calibration');
assert_istrue(numel(cal) >= 1);
for index = 1:numel(cal)
  y = get(cal(index), 'YData');
  height = max(y) - min(y);
  assert_istrue(abs(height - gain) < 1e-6);
end
fprintf('calibration pulse height %.4f mm (expect %g)\n', ...
max(get(cal(1), 'YData')) - min(get(cal(1), 'YData')), gain);
close(h);
%=============================================================================
% Saving to PNG and SVG each produces a file; the SVG declares its size in the
% page's millimetres (plan.Wmm by plan.Hmm).
pngFile = [tmp, '/test_ecglab_strip.png'];
svgFile = [tmp, '/test_ecglab_strip.svg'];
if isfile(pngFile)
  delete(pngFile);
end
if isfile(svgFile)
  delete(svgFile);
end
h = ecglab.strip(rec, 'Visible', 'off', 'OutputImage', pngFile);
close(h);
assert_istrue(isfile(pngFile));
h = ecglab.strip(rec, 'Visible', 'off', 'OutputImage', svgFile);
plan = get(h, 'UserData');
close(h);
assert_istrue(isfile(svgFile));
svg = fileread(svgFile);
% The width and height of the ROOT <svg> element, the first tag of the file.
openAt = strfind(svg, '<svg');
head = svg(openAt(1):end);
closeAt = strfind(head, '>');
head = head(1:closeAt(1) - 1);
widthMm = localStripAttrMm(head, 'width');
heightMm = localStripAttrMm(head, 'height');
fprintf('SVG width %.2f mm (page %.2f), height %.2f mm (page %.2f)\n', ...
widthMm, plan.Wmm, heightMm, plan.Hmm);
assert_istrue(abs(widthMm - plan.Wmm) < 0.6);
assert_istrue(abs(heightMm - plan.Hmm) < 0.6);
% Millimetres per viewBox pixel must be positive and finite, and the page must
% be at least the four 2.5 s columns imply at 25 mm/s.
box = localStripViewBox(head);
mmPerPixel = widthMm / box(3);
fprintf('mm per viewBox pixel %.5f; page width %.1f mm\n', mmPerPixel, widthMm);
assert_istrue(mmPerPixel > 0 && isfinite(mmPerPixel));
assert_istrue(widthMm > 4 * panelSeconds * speed);
%=============================================================================
% The other layouts each draw and return a figure.
for layout = {'12x1', '6x2', '1'}
  h = ecglab.strip(rec, 'Visible', 'off', 'Layout', layout{1});
  assert_istrue(isgraphics(h, 'figure'));
  p = get(h, 'UserData');
  fprintf('layout %s: %d panels, %.1f x %.1f mm\n', layout{1}, ...
  numel(p.panels), p.Wmm, p.Hmm);
  close(h);
end
%=============================================================================
% A single-lead signal vector with its rate draws.
h = ecglab.strip(rec.samples(:, 2), 'Rate', rec.rate, 'Layout', '1', ...
'Visible', 'off');
assert_istrue(isgraphics(h, 'figure'));
close(h);
%=============================================================================
% The other styles draw, sharing the page code.
h = ecglab.strip(rec, 'Visible', 'off', 'Style', 'monitor');
assert_istrue(isgraphics(h, 'figure'));
close(h);
h = ecglab.strip(rec, 'Visible', 'off', 'Style', 'bw');
assert_istrue(isgraphics(h, 'figure'));
close(h);
%=============================================================================
% Errors: no lead, bad layout, bad style, bad option, and a vector with no
% rate, each refused with its own identifier.
recNoLeads = localStripNoLeads();
vector = rec.samples(:, 1);
assert_istrue(startsWith(localStripError(@() ecglab.strip(recNoLeads)), 'ecglab:noLeads'));
assert_istrue(startsWith(localStripError(@() ecglab.strip(rec, 'Layout', '9x9')), 'ecglab:badLayout'));
assert_istrue(startsWith(localStripError(@() ecglab.strip(rec, 'Style', 'neon')), 'ecglab:unknownStyle'));
assert_istrue(startsWith(localStripError(@() ecglab.strip(rec, 'NoSuchOption', 1)), 'ecglab:unknownOption'));
assert_istrue(startsWith(localStripError(@() ecglab.strip(vector)), 'ecglab:rateRequired'));
%=============================================================================
% The draw time of a ten second twelve-lead page, stated for the record.
recTen = ecglab.simulate('Seconds', 10, 'Rate', 500, 'Leads', 12, 'Seed', 2);
tic;
h = ecglab.strip(recTen, 'Visible', 'off');
elapsed = toc;
close(h);
fprintf('drew a 10 s twelve-lead page in %.3f s\n', elapsed);
assert_istrue(elapsed < 5);
%=============================================================================
function value = localStripAttrMm(head, name)
  % The millimetre value of attribute NAME in the SVG root tag, e.g. width="264mm".
  token = [name, '="'];
  at = strfind(head, token);
  from = at(1) + numel(token);
  rest = head(from:end);
  stop = strfind(rest, '"');
  text = rest(1:stop(1) - 1);
  text = strrep(text, 'mm', '');
  value = str2double(text);
end
%=============================================================================
function box = localStripViewBox(head)
  % The four numbers of the SVG viewBox attribute.
  token = 'viewBox="';
  at = strfind(head, token);
  from = at(1) + numel(token);
  rest = head(from:end);
  stop = strfind(rest, '"');
  box = sscanf(rest(1:stop(1) - 1), '%f')';
end
%=============================================================================
function rec = localStripNoLeads()
  % A recording that carries no lead, to prove the page refuses it.
  rec = struct('kind', 'ecglab.recording', 'rate', 360, ...
  'samples', zeros(360, 0), 'leads', {{}}, 'units', {{}}, 'seconds', 1, ...
  'info', struct('name', '', 'source', '', 'format', 'simulated'), ...
  'annotations', []);
end
%=============================================================================
function id = localStripError(thunk)
  % The identifier of the error a call raises, or empty when it raises none.
  id = '';
  try
    thunk();
  catch e
    id = e.identifier;
  end
end
%=============================================================================
