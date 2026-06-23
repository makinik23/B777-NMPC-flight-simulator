function results = run_feature_tests()
%RUN_FEATURE_TESTS Run all feature-oriented MATLAB checks.

testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);

addpath(genpath(fullfile(projectRoot, 'data')));
addpath(genpath(fullfile(projectRoot, 'plant')));

results = runtests(fullfile(testDir, 'features'));
assertSuccess(results);
end
