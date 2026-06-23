%TEST_MODELING_CONVENTIONS Validate modelling conventions and state definitions.

scriptPath = mfilename("fullpath");
featureTestDir = fileparts(scriptPath);
testsDir = fileparts(featureTestDir);
projectRoot = fileparts(testsDir);

addpath(fullfile(projectRoot, "data"));

fprintf("Running modelling-conventions feature test...\n\n");

% Check if convention file exists

assert(exist("conventions", "file") == 2, ...
    "Could not find data/conventions.m on MATLAB path.");

conv = conventions();

% Check full 6-DOF state vector

nStateNames = numel(conv.state.full6dof.names);
nStateUnits = numel(conv.state.full6dof.units);
nStateDescriptions = numel(conv.state.full6dof.description);

assert(nStateNames == nStateUnits, ...
    "Full 6-DOF state vector has inconsistent number of names and units.");

assert(nStateNames == nStateDescriptions, ...
    "Full 6-DOF state vector has inconsistent number of names and descriptions.");

assert(nStateNames == 17, ...
    "Expected full 6-DOF state vector to contain 17 states.");

% Check command input vector

nInputNames = numel(conv.input.command.names);
nInputUnits = numel(conv.input.command.units);
nInputDescriptions = numel(conv.input.command.description);

assert(nInputNames == nInputUnits, ...
    "Command input vector has inconsistent number of names and units.");

assert(nInputNames == nInputDescriptions, ...
    "Command input vector has inconsistent number of names and descriptions.");

assert(nInputNames == 5, ...
    "Expected command input vector to contain 5 command inputs.");

% Check reduced NMPC models

assert(numel(conv.state.longitudinalNmpc.names) == 6, ...
    "Expected longitudinal NMPC model to contain 6 states.");

assert(numel(conv.input.longitudinalNmpc.names) == 2, ...
    "Expected longitudinal NMPC model to contain 2 inputs.");

assert(numel(conv.state.lateralNmpc.names) == 6, ...
    "Expected lateral-directional NMPC model to contain 6 states.");

assert(numel(conv.input.lateralNmpc.names) == 2, ...
    "Expected lateral-directional NMPC model to contain 2 inputs.");

% Print summary

fprintf("Project: %s\n", conv.project.aircraftClass);
fprintf("Model type: %s\n\n", conv.project.modelType);

fprintf("Navigation frame: %s\n", conv.frames.navigation.name);
fprintf("Body frame:       %s\n", conv.frames.body.name);
fprintf("Wind frame:       %s\n\n", conv.frames.wind.name);

fprintf("Full 6-DOF state vector:\n");
for i = 1:numel(conv.state.full6dof.names)
    fprintf("  %2d. %-10s [%s] - %s\n", ...
        i, ...
        conv.state.full6dof.names(i), ...
        conv.state.full6dof.units(i), ...
        conv.state.full6dof.description(i));
end

fprintf("\nCommand input vector:\n");
for i = 1:numel(conv.input.command.names)
    fprintf("  %2d. %-14s [%s] - %s\n", ...
        i, ...
        conv.input.command.names(i), ...
        conv.input.command.units(i), ...
        conv.input.command.description(i));
end

fprintf("\nFeature test passed: modelling conventions are defined consistently.\n");
