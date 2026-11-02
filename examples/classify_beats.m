%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the ecglab module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Name each beat in the five AAMI classes and find the ventricular ectopics.
%
% ecglab.classify labels each beat N, S, V, F or Q with a linear discriminant.
% A simulated record plants known ventricular ectopics; the classifier
% recovers them from the signal. Database figures are in
% data/ecglab_classification_mitdb.md.
%=============================================================================
if ~ismodule('ecglab')
  run([fileparts(mfilename('fullpathext')), '/../loader.m']);
end
%=============================================================================
disp('=== ecglab: name the beats and find the ventricular ectopics ===');

% A minute with ventricular ectopy, whose planted beats are the ground truth.
recording = ecglab.simulate('Seconds', 60, 'Rate', 360, 'HeartRate', 75, ...
'Ectopic', 0.15, 'Leads', 2, 'Seed', 9);
beats = ecglab.detect(recording);
classes = ecglab.classify(recording, 'Beats', beats);
plantedV = sum(recording.truth.classes == 'V');
foundV = sum(classes.label == 'V');
fprintf('%d beats named: N %d, S %d, V %d, F %d, Q %d.\n', ...
numel(classes.label), sum(classes.label == 'N'), sum(classes.label == 'S'), ...
foundV, sum(classes.label == 'F'), sum(classes.label == 'Q'));
fprintf('Ventricular ectopics: %d found, %d planted.\n', foundV, plantedV);

% The result carries the decision features, and goes straight to
% ecglab.validate for the confusion matrix.
agreement = ecglab.validate(classes.beats, recording.annotations, ...
'Kind', 'beats', 'Table', 'dechazal', 'Learning', 0, 'Record', 'sim');
fprintf('Against the truth: %d beats matched, confusion matrix in agreement.matrix.\n', ...
agreement.tp);

% The caller chooses the class prior. The default empirical prior gives the
% best overall accuracy; 'uniform' lifts the rare classes.
uniform = ecglab.classify(recording, 'Beats', beats, 'Prior', 'uniform');
fprintf('With the uniform prior: V %d (prior ''%s'').\n', ...
sum(uniform.label == 'V'), uniform.prior);
disp('=== done ===');
%=============================================================================
