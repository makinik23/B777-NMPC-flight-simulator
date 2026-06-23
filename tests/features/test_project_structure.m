%% Project structure feature test
% Verify that the expected project folders are visible to MATLAB.

requiredFolders = [
    "data"
    "plant"
    "nmpc"
    "guidance"
    "validation"
    "models"
    "plots"
    "docs"
    "tests"
    "tools"
];

testPath = mfilename('fullpath');
featureTestDir = fileparts(testPath);
testsDir = fileparts(featureTestDir);
projectRoot = fileparts(testsDir);
missing = strings(0,1);

for k = 1:numel(requiredFolders)
    folderPath = fullfile(projectRoot, requiredFolders(k));
    if ~isfolder(folderPath)
        missing(end+1,1) = requiredFolders(k); %#ok<SAGROW>
    end
end

if isempty(missing)
    disp("Feature test passed: all required top-level project folders exist.");
else
    error("Missing folders: %s", strjoin(missing, ", "));
end

clear featureTestDir folderPath k missing projectRoot requiredFolders testPath testsDir;
