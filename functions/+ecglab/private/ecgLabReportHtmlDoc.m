%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function html = ecgLabReportHtmlDoc(analysis, textReport, images, language)
  % Assemble the self-contained HTML report from the page images (base64 data
  % URIs in IMAGES) and the plain-text report, styled for screen and print.
  L = ecgLabReportHtmlLabels(language);
  summary = ecgLabReportSummary(analysis);
  info = analysis.recording.info;
  subject = ecgLabReportHtmlField(info, 'subject', L.unknown);
  source = ecgLabReportHtmlField(info, 'source', L.unknown);
  format = ecgLabReportHtmlField(info, 'format', '');
  detector = summary.provenance.detector;
  nelson = summary.provenance.nelson;
  seconds = analysis.recording.seconds;
  rate = analysis.recording.rate;
  nLeads = numel(analysis.recording.leads);
  metaLine = sprintf(L.meta, ecgLabReportHtmlEscape(subject), ...
  ecgLabReportHtmlEscape(source), ecgLabReportHtmlEscape(format), seconds, ...
  rate, nLeads, ecgLabReportHtmlEscape(detector));
  %===========================================================================
  lines = {};
  lines{end + 1} = '<!DOCTYPE html>';
  lines{end + 1} = sprintf('<html lang="%s">', language);
  lines{end + 1} = '<head>';
  lines{end + 1} = '<meta charset="utf-8">';
  lines{end + 1} = '<meta name="viewport" content="width=device-width, initial-scale=1">';
  lines{end + 1} = sprintf('<title>%s</title>', ecgLabReportHtmlEscape(L.title));
  lines{end + 1} = '<style>';
  lines{end + 1} = ecgLabReportHtmlStyle();
  lines{end + 1} = '</style>';
  lines{end + 1} = '</head>';
  lines{end + 1} = '<body>';
  lines{end + 1} = sprintf('<div class="banner"><strong>%s</strong> %s</div>', ...
  ecgLabReportHtmlEscape(L.disclaimerLead), ...
  ecgLabReportHtmlEscape(L.disclaimerRest));
  lines{end + 1} = '<main>';
  lines{end + 1} = '<header>';
  lines{end + 1} = sprintf('<h1>%s</h1>', ecgLabReportHtmlEscape(L.title));
  lines{end + 1} = sprintf('<p class="meta">%s</p>', metaLine);
  lines{end + 1} = '</header>';
  %===========================================================================
  % The three pages, each in its own card; missing pages are left out.
  lines = ecgLabReportHtmlFigure(lines, L.chartTitle, L.chartNote, ...
  ecgLabReportHtmlValue(images, 'chart'));
  lines = ecgLabReportHtmlFigure(lines, L.stripTitle, L.stripNote, ...
  ecgLabReportHtmlValue(images, 'strip'));
  lines = ecgLabReportHtmlFigure(lines, L.beatTitle, L.beatNote, ...
  ecgLabReportHtmlValue(images, 'beat'));
  %===========================================================================
  lines{end + 1} = '<section class="card">';
  lines{end + 1} = sprintf('<h2>%s</h2>', ecgLabReportHtmlEscape(L.reportTitle));
  lines{end + 1} = sprintf('<pre class="report">%s</pre>', ...
  ecgLabReportHtmlEscape(textReport));
  lines{end + 1} = '</section>';
  lines{end + 1} = '</main>';
  lines{end + 1} = '<footer>';
  lines{end + 1} = sprintf('<p>%s</p>', ecgLabReportHtmlEscape(L.footerDisclaimer));
  lines{end + 1} = sprintf('<p class="prov">%s</p>', ...
  ecgLabReportHtmlEscape(sprintf(L.prov, detector, nelson)));
  lines{end + 1} = '</footer>';
  lines{end + 1} = '</body>';
  lines{end + 1} = '</html>';
  html = strjoin(lines, sprintf('\n'));
end
%=============================================================================
function lines = ecgLabReportHtmlFigure(lines, title, note, uri)
  % One page card, skipped entirely when the page has no image.
  if isempty(uri)
    return;
  end
  lines{end + 1} = '<section class="card">';
  lines{end + 1} = sprintf('<h2>%s</h2>', ecgLabReportHtmlEscape(title));
  lines{end + 1} = sprintf('<img class="page" alt="%s" src="%s">', ...
  ecgLabReportHtmlEscape(title), uri);
  if ~isempty(note)
    lines{end + 1} = sprintf('<p class="note">%s</p>', ...
    ecgLabReportHtmlEscape(note));
  end
  lines{end + 1} = '</section>';
end
%=============================================================================
function value = ecgLabReportHtmlValue(s, field)
  if isstruct(s) && isfield(s, field) && ischar(s.(field))
    value = s.(field);
  else
    value = '';
  end
end
%=============================================================================
function value = ecgLabReportHtmlField(info, field, fallback)
  if isfield(info, field) && ischar(info.(field)) && ~isempty(info.(field))
    value = info.(field);
  else
    value = fallback;
  end
end
%=============================================================================
function out = ecgLabReportHtmlEscape(text)
  % Escape the five characters that must not appear raw in HTML.
  out = char(text);
  out = strrep(out, '&', '&amp;');
  out = strrep(out, '<', '&lt;');
  out = strrep(out, '>', '&gt;');
  out = strrep(out, '"', '&quot;');
  out = strrep(out, '''', '&#39;');
end
%=============================================================================
function css = ecgLabReportHtmlStyle()
  % The embedded stylesheet: a centred column, pages in bordered cards, the
  % disclaimer in a banner, with every colour named for screen and print.
  lines = {
  ':root{--ink:#1a1a1a;--dim:#6b6b6b;--ground:#faf7f3;--card:#ffffff;'
  '--line:#e2ddd6;--accent:#0b6b6b;--warn-bg:#fbeecb;--warn-ink:#7a5200;'
  '--warn-line:#e6c463;}'
  '*{box-sizing:border-box;}'
  'body{margin:0;background:var(--ground);color:var(--ink);'
  'font-family:"IBM Plex Sans",-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;'
  'line-height:1.5;}'
  '.banner{background:var(--warn-bg);color:var(--warn-ink);'
  'border-bottom:2px solid var(--warn-line);padding:12px 20px;font-size:14px;}'
  'main{max-width:960px;margin:0 auto;padding:24px 20px 8px;}'
  'header h1{font-size:24px;margin:8px 0 4px;}'
  '.meta{color:var(--dim);font-size:14px;margin:0 0 16px;}'
  '.card{background:var(--card);border:1px solid var(--line);border-radius:8px;'
  'padding:16px 18px;margin:0 0 20px;box-shadow:0 1px 2px rgba(0,0,0,0.04);}'
  '.card h2{font-size:16px;margin:0 0 12px;color:var(--accent);'
  'letter-spacing:0.02em;}'
  'img.page{width:100%;height:auto;display:block;border:1px solid var(--line);'
  'border-radius:4px;}'
  '.note{color:var(--dim);font-size:13px;margin:8px 0 0;}'
  'pre.report{font-family:"IBM Plex Mono",ui-monospace,Menlo,Consolas,monospace;'
  'font-size:12.5px;line-height:1.45;white-space:pre-wrap;word-wrap:break-word;'
  'margin:0;color:var(--ink);}'
  'footer{max-width:960px;margin:0 auto;padding:8px 20px 32px;'
  'color:var(--dim);font-size:12.5px;}'
  'footer .prov{color:var(--dim);}'
  '@media print{body{background:#fff;}.card{box-shadow:none;'
  'break-inside:avoid;}.banner{position:static;}}'
  };
  css = strjoin(lines, sprintf('\n'));
end
%=============================================================================
function L = ecgLabReportHtmlLabels(language)
  if strcmp(language, 'fr')
    L = struct( ...
    'title', 'Rapport d''etude electrocardiographique', ...
    'unknown', 'inconnu', ...
    'meta', 'Sujet %s | Source %s %s | Duree %.1f s a %g Hz, %d derivations | Detecteur %s', ...
    'chartTitle', 'Synthese', ...
    'chartNote', 'La page de synthese : tuiles, voies sur un axe de temps commun, evidence du detecteur, HRV et Poincare.', ...
    'stripTitle', 'Bande calibree', ...
    'stripNote', 'Papier calibre a 25 mm/s et 10 mm/mV.', ...
    'beatTitle', 'Un battement', ...
    'beatNote', 'Un battement avec ses fiduciaux, l''evidence du detecteur et la carte de classe.', ...
    'reportTitle', 'Rapport detaille', ...
    'disclaimerLead', 'Logiciel de recherche, pas un dispositif medical.', ...
    'disclaimerRest', 'ecglab est destine a la recherche et a l''enseignement. Ce n''est pas un dispositif medical et il ne doit pas servir au diagnostic clinique, a la surveillance des patients, aux decisions de traitement, ni a aucune fin medicale.', ...
    'footerDisclaimer', 'Logiciel de recherche, pas un dispositif medical : pour la recherche et l''enseignement uniquement. Les valeurs sont des mesures, jamais un constat clinique.', ...
    'prov', 'Detecteur %s ; Nelson %s ; genere par ecglab.reporthtml.');
  else
    L = struct( ...
    'title', 'Electrocardiogram Study Report', ...
    'unknown', 'unknown', ...
    'meta', 'Subject %s | Source %s %s | Length %.1f s at %g Hz, %d leads | Detector %s', ...
    'chartTitle', 'Summary', ...
    'chartNote', 'The summary page: the tiles, the lanes on one time axis, the detector evidence, the HRV and the Poincare plot.', ...
    'stripTitle', 'Calibrated strip', ...
    'stripNote', 'Calibrated paper at 25 mm/s and 10 mm/mV.', ...
    'beatTitle', 'One beat', ...
    'beatNote', 'One beat with its fiducials, the detector evidence and the class card.', ...
    'reportTitle', 'Detailed report', ...
    'disclaimerLead', 'Research software, not a medical device.', ...
    'disclaimerRest', 'ecglab is for research and education. It is not a medical device and must not be used for clinical diagnosis, patient monitoring, treatment decisions, or any medical purpose.', ...
    'footerDisclaimer', 'Research software, not a medical device: for research and education only. The values are measurements, never a clinical finding.', ...
    'prov', 'Detector %s; Nelson %s; generated by ecglab.reporthtml.');
  end
end
%=============================================================================
