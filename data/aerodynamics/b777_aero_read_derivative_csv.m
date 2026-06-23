function data = b777_aero_read_derivative_csv(csvFile)
%B777_AERO_READ_DERIVATIVE_CSV Read a traceable aerodynamic derivative table.
%
% Expected CSV columns:
% source_id, group, coefficient, basis, value, units, status, confidence, notes

if nargin < 1 || ~(ischar(csvFile) || isstring(csvFile)) || strlength(csvFile) == 0
    error('b777_aero_read_derivative_csv:InvalidPath', ...
        'csvFile must be a non-empty character vector or string scalar.');
end

csvFile = char(csvFile);
fid = fopen(csvFile, 'r');
if fid < 0
    error('b777_aero_read_derivative_csv:OpenFailed', ...
        'Unable to open derivative CSV file: %s', csvFile);
end

cleanup = onCleanup(@() fclose(fid));
raw = textscan(fid, '%s%s%s%s%f%s%s%f%s', ...
    'Delimiter', ',', ...
    'HeaderLines', 1, ...
    'Whitespace', '', ...
    'CollectOutput', false);

sourceId = string(raw{1});
group = string(raw{2});
coefficient = string(raw{3});
basis = string(raw{4});
value = raw{5};
units = string(raw{6});
status = string(raw{7});
confidence = raw{8};
notes = string(raw{9});

finiteRows = isfinite(value) & isfinite(confidence);
sourceId = sourceId(finiteRows);
group = group(finiteRows);
coefficient = coefficient(finiteRows);
basis = basis(finiteRows);
value = value(finiteRows);
units = units(finiteRows);
status = status(finiteRows);
confidence = confidence(finiteRows);
notes = notes(finiteRows);

if isempty(value)
    error('b777_aero_read_derivative_csv:EmptyTable', ...
        'Derivative CSV file contains no finite numeric rows: %s', csvFile);
end

data = struct();
data.source_file = string(csvFile);
data.source_id_sample = sourceId;
data.source_id = unique(sourceId, 'stable');
data.group = group;
data.coefficient = coefficient;
data.basis = basis;
data.value = value;
data.units_sample = units;
data.status_sample = status;
data.status = unique(status, 'stable');
data.confidence_sample = confidence;
data.confidence = min(confidence);
data.notes_sample = notes;

for k = 1:numel(value)
    groupName = char(group(k));
    coefficientName = char(coefficient(k));
    if ~isvarname(groupName) || ~isvarname(coefficientName)
        error('b777_aero_read_derivative_csv:InvalidName', ...
            'Invalid derivative group or coefficient name at row %d.', k + 1);
    end

    data.(groupName).(coefficientName) = value(k);
end

validate_derivative_table(data);
end

function validate_derivative_table(data)
assert(numel(data.source_id) == 1, ...
    'Derivative table must contain exactly one source identifier.');
assert(numel(data.status) == 1, ...
    'Derivative table must contain exactly one status.');
assert(all(data.confidence_sample >= 0.0 & data.confidence_sample <= 1.0), ...
    'Derivative confidence values must be inside [0, 1].');
assert(has_derivative(data, 'static', 'CY_beta'), ...
    'Derivative table is missing CY_beta.');
assert(has_derivative(data, 'static', 'Cl_beta'), ...
    'Derivative table is missing Cl_beta.');
assert(has_derivative(data, 'static', 'Cn_beta'), ...
    'Derivative table is missing Cn_beta.');
assert(has_derivative(data, 'dynamic', 'Cm_q'), ...
    'Derivative table is missing Cm_q.');
assert(has_derivative(data, 'dynamic', 'Cl_p'), ...
    'Derivative table is missing Cl_p.');
assert(has_derivative(data, 'dynamic', 'Cn_r'), ...
    'Derivative table is missing Cn_r.');
assert(has_derivative(data, 'control', 'Cm_delta_e'), ...
    'Derivative table is missing Cm_delta_e.');
assert(has_derivative(data, 'control', 'Cl_delta_a'), ...
    'Derivative table is missing Cl_delta_a.');
assert(has_derivative(data, 'control', 'Cn_delta_r'), ...
    'Derivative table is missing Cn_delta_r.');
end

function tf = has_derivative(data, groupName, coefficientName)
tf = isfield(data, groupName) && isfield(data.(groupName), coefficientName);
end
