function data = b777_aero_read_crm_force_moment_csv(csvFile)
%B777_AERO_READ_CRM_FORCE_MOMENT_CSV Read a NASA CRM force/moment CSV table.
%
% Expected CSV columns:
%   Mach, "Rec, million", alpha, CL, CD, CM

if ~(ischar(csvFile) || isstring(csvFile))
    error('b777_aero_read_crm_force_moment_csv:InvalidPath', ...
        'csvFile must be a character vector or string scalar.');
end

csvFile = char(csvFile);
fid = fopen(csvFile, 'r');
if fid < 0
    error('b777_aero_read_crm_force_moment_csv:OpenFailed', ...
        'Unable to open CRM CSV file: %s', csvFile);
end

cleanup = onCleanup(@() fclose(fid));
columns = textscan(fid, '%f%f%f%f%f%f', ...
    'Delimiter', ',', ...
    'HeaderLines', 1, ...
    'CollectOutput', true);

values = columns{1};
values = values(all(isfinite(values), 2), :);

if isempty(values)
    error('b777_aero_read_crm_force_moment_csv:EmptyTable', ...
        'CRM CSV file does not contain finite numeric rows: %s', csvFile);
end

data = struct();
data.source_file = string(csvFile);
data.Mach = values(:, 1).';
data.Re_million = values(:, 2).';
data.alpha_deg = values(:, 3).';
data.alpha_rad = deg2rad_local(data.alpha_deg);
data.CL = values(:, 4).';
data.CD = values(:, 5).';
data.Cm = values(:, 6).';

validate_data(data);
end

function validate_data(data)
assert(numel(data.alpha_rad) == numel(data.CL), 'CL vector length mismatch.');
assert(numel(data.alpha_rad) == numel(data.CD), 'CD vector length mismatch.');
assert(numel(data.alpha_rad) == numel(data.Cm), 'Cm vector length mismatch.');
assert(all(diff(data.alpha_rad) > 0.0), ...
    'Angle-of-attack samples must be strictly increasing.');
assert(all(data.CD > 0.0), 'Drag coefficients must be positive.');
assert(numel(unique(data.Mach)) == 1, ...
    'Current CRM CSV reader expects one Mach value per file.');
assert(numel(unique(data.Re_million)) == 1, ...
    'Current CRM CSV reader expects one Reynolds number per file.');
end

function rad = deg2rad_local(deg)
rad = deg * pi / 180.0;
end
