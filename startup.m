%% B777 NMPC Flight Simulator - startup
% Run this file from the project root to add all project folders to MATLAB path.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('B777 NMPC project loaded from: %s', projectRoot);
