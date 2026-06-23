function data = b777_aero_read_crm_clean_grid_csv(csvFile)
%B777_AERO_READ_CRM_CLEAN_GRID_CSV Read a curated CRM clean aero grid.
%
% The expected CSV columns are:
% source_id, run, Mach, Re_million, alpha_deg, CL, CD, Cm
%
% The returned coefficient matrices are arranged as alpha rows by Mach
% columns, matching MATLAB interp2(X, Y, V, xq, yq) with X = Mach and
% Y = alpha_rad.

if nargin < 1 || ~(ischar(csvFile) || isstring(csvFile)) || strlength(csvFile) == 0
    error('b777_aero_read_crm_clean_grid_csv:InvalidPath', ...
        'csvFile must be a non-empty character vector or string scalar.');
end

csvFile = char(csvFile);
fid = fopen(csvFile, 'r');
if fid < 0
    error('b777_aero_read_crm_clean_grid_csv:OpenFailed', ...
        'Unable to open CRM clean grid CSV file: %s', csvFile);
end

cleaner = onCleanup(@() fclose(fid));
raw = textscan(fid, '%s%s%f%f%f%f%f%f', ...
    'Delimiter', ',', ...
    'HeaderLines', 1, ...
    'CollectOutput', false);

sourceId = string(raw{1});
runId = string(raw{2});
numeric = [raw{3}, raw{4}, raw{5}, raw{6}, raw{7}, raw{8}];

if isempty(numeric)
    error('b777_aero_read_crm_clean_grid_csv:EmptyTable', ...
        'CRM clean grid CSV file contains no numeric rows: %s', csvFile);
end

finiteRows = all(isfinite(numeric), 2);
sourceId = sourceId(finiteRows);
runId = runId(finiteRows);
numeric = numeric(finiteRows, :);

data = struct();
data.source_file = string(csvFile);
data.source_id_sample = sourceId;
data.source_id = unique(sourceId, 'stable');
data.run_id = runId;
data.Mach_sample = numeric(:, 1);
data.Re_million_sample = numeric(:, 2);
data.alpha_deg_sample = numeric(:, 3);
data.alpha_rad_sample = deg2rad_local(data.alpha_deg_sample);
data.CL_sample = numeric(:, 4);
data.CD_sample = numeric(:, 5);
data.Cm_sample = numeric(:, 6);

data.Mach = unique(data.Mach_sample, 'stable');
data.alpha_deg = unique(data.alpha_deg_sample, 'stable');
data.alpha_rad = deg2rad_local(data.alpha_deg);
data.Re_million_by_Mach = zeros(size(data.Mach));
data.run_id_by_Mach = strings(size(data.Mach));

nAlpha = numel(data.alpha_rad);
nMach = numel(data.Mach);
data.CL = nan(nAlpha, nMach);
data.CD = nan(nAlpha, nMach);
data.Cm = nan(nAlpha, nMach);

for j = 1:nMach
    machRows = abs(data.Mach_sample - data.Mach(j)) < 1e-10;
    alphaAtMach = data.alpha_deg_sample(machRows);
    [alphaAtMach, order] = sort(alphaAtMach);
    rowIndex = find_alpha_rows(data.alpha_deg, alphaAtMach);

    clSamples = data.CL_sample(machRows);
    cdSamples = data.CD_sample(machRows);
    cmSamples = data.Cm_sample(machRows);
    data.CL(rowIndex, j) = clSamples(order);
    data.CD(rowIndex, j) = cdSamples(order);
    data.Cm(rowIndex, j) = cmSamples(order);

    data.Re_million_by_Mach(j) = mean(data.Re_million_sample(machRows));
    runIds = unique(data.run_id(machRows), 'stable');
    data.run_id_by_Mach(j) = runIds(1);
end

validate_grid(data);
end

function rowIndex = find_alpha_rows(alphaGrid, alphaValues)
rowIndex = zeros(size(alphaValues));
for k = 1:numel(alphaValues)
    idx = find(abs(alphaGrid - alphaValues(k)) < 1e-10, 1);
    if isempty(idx)
        error('b777_aero_read_crm_clean_grid_csv:AlphaMismatch', ...
            'Alpha sample %.8g is not present in the grid.', alphaValues(k));
    end
    rowIndex(k) = idx;
end
end

function validate_grid(data)
assert(numel(data.Mach) >= 2, 'Clean grid must contain at least two Mach stations.');
assert(numel(data.alpha_rad) >= 2, 'Clean grid must contain at least two alpha stations.');
assert(all(diff(data.Mach) > 0.0), 'Mach stations must be strictly increasing.');
assert(all(diff(data.alpha_rad) > 0.0), ...
    'Angle-of-attack stations must be strictly increasing.');
assert(~any(isnan(data.CL(:))), 'CL grid contains missing samples.');
assert(~any(isnan(data.CD(:))), 'CD grid contains missing samples.');
assert(~any(isnan(data.Cm(:))), 'Cm grid contains missing samples.');
assert(numel(data.source_id) == 1, ...
    'Clean grid must contain exactly one source identifier.');
assert(all(data.CD(:) > 0.0), 'Drag coefficients must be positive.');
assert(all(data.Re_million_by_Mach > 0.0), ...
    'Reynolds-number metadata must be positive.');
end

function rad = deg2rad_local(deg)
rad = deg * pi / 180.0;
end
