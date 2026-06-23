function data = b777_aero_read_mach_derivative_csv(csvFile)
%B777_AERO_READ_MACH_DERIVATIVE_CSV Read Mach-dependent derivative candidates.
%
% Expected CSV columns:
% source_id, mach, case_id, case_source_id, group, coefficient, basis, value,
% units, status, confidence, interpolation_policy, notes

if nargin < 1 || ~(ischar(csvFile) || isstring(csvFile)) || strlength(csvFile) == 0
    error('b777_aero_read_mach_derivative_csv:InvalidPath', ...
        'csvFile must be a non-empty character vector or string scalar.');
end

csvFile = char(csvFile);
fid = fopen(csvFile, 'r');
if fid < 0
    error('b777_aero_read_mach_derivative_csv:OpenFailed', ...
        'Unable to open Mach derivative CSV file: %s', csvFile);
end

cleanup = onCleanup(@() fclose(fid));
raw = textscan(fid, '%s%f%s%s%s%s%s%f%s%s%f%s%s', ...
    'Delimiter', ',', ...
    'HeaderLines', 1, ...
    'Whitespace', '', ...
    'CollectOutput', false);

sourceId = string(raw{1});
mach = raw{2};
caseId = string(raw{3});
caseSourceId = string(raw{4});
group = string(raw{5});
coefficient = string(raw{6});
basis = string(raw{7});
value = raw{8};
units = string(raw{9});
status = string(raw{10});
confidence = raw{11};
interpolationPolicy = string(raw{12});
notes = string(raw{13});

finiteRows = isfinite(mach) & isfinite(value) & isfinite(confidence);
sourceId = sourceId(finiteRows);
mach = mach(finiteRows);
caseId = caseId(finiteRows);
caseSourceId = caseSourceId(finiteRows);
group = group(finiteRows);
coefficient = coefficient(finiteRows);
basis = basis(finiteRows);
value = value(finiteRows);
units = units(finiteRows);
status = status(finiteRows);
confidence = confidence(finiteRows);
interpolationPolicy = interpolationPolicy(finiteRows);
notes = notes(finiteRows);

if isempty(value)
    error('b777_aero_read_mach_derivative_csv:EmptyTable', ...
        'Mach derivative CSV file contains no finite numeric rows: %s', csvFile);
end

data = struct();
data.source_file = string(csvFile);
data.source_id_sample = sourceId;
data.source_id = unique(sourceId, 'stable');
data.Mach_sample = mach;
data.case_id_sample = caseId;
data.case_source_id_sample = caseSourceId;
data.group_sample = group;
data.coefficient_sample = coefficient;
data.basis_sample = basis;
data.value_sample = value;
data.units_sample = units;
data.status_sample = status;
data.status = unique(status, 'stable');
data.confidence_sample = confidence;
data.confidence = min(confidence);
data.interpolation_policy_sample = interpolationPolicy;
data.interpolation_policy = unique(interpolationPolicy, 'stable');
data.notes_sample = notes;

data.Mach = unique(mach, 'stable');
data.coefficients = unique(coefficient, 'stable');
data.grid = struct();
data.grid.Mach = data.Mach;
data.grid.value = nan(numel(data.Mach), numel(data.coefficients));
data.grid.group = strings(1, numel(data.coefficients));
data.grid.basis = strings(1, numel(data.coefficients));
data.grid.units = strings(1, numel(data.coefficients));

for j = 1:numel(data.coefficients)
    coefficientName = data.coefficients(j);
    coeffRows = coefficient == coefficientName;
    [machAtCoeff, order] = sort(mach(coeffRows));
    rowIndex = find_mach_rows(data.Mach, machAtCoeff);
    valuesAtCoeff = value(coeffRows);
    groupsAtCoeff = unique(group(coeffRows), 'stable');
    basesAtCoeff = unique(basis(coeffRows), 'stable');
    unitsAtCoeff = unique(units(coeffRows), 'stable');

    assert(numel(groupsAtCoeff) == 1, ...
        'Coefficient %s must use one derivative group.', coefficientName);
    assert(numel(basesAtCoeff) == 1, ...
        'Coefficient %s must use one basis variable.', coefficientName);
    assert(numel(unitsAtCoeff) == 1, ...
        'Coefficient %s must use one units token.', coefficientName);

    data.grid.value(rowIndex, j) = valuesAtCoeff(order);
    data.grid.group(j) = groupsAtCoeff(1);
    data.grid.basis(j) = basesAtCoeff(1);
    data.grid.units(j) = unitsAtCoeff(1);

    fieldGroup = char(groupsAtCoeff(1));
    fieldCoefficient = char(coefficientName);
    if ~isvarname(fieldGroup) || ~isvarname(fieldCoefficient)
        error('b777_aero_read_mach_derivative_csv:InvalidName', ...
            'Invalid derivative group or coefficient name: %s.%s', ...
            fieldGroup, fieldCoefficient);
    end
    data.(fieldGroup).(fieldCoefficient) = data.grid.value(:, j);
end

validate_mach_derivative_table(data);
end

function rowIndex = find_mach_rows(machGrid, machValues)
rowIndex = zeros(size(machValues));
for k = 1:numel(machValues)
    idx = find(abs(machGrid - machValues(k)) < 1e-10, 1);
    if isempty(idx)
        error('b777_aero_read_mach_derivative_csv:MachMismatch', ...
            'Mach sample %.8g is not present in the grid.', machValues(k));
    end
    rowIndex(k) = idx;
end
end

function validate_mach_derivative_table(data)
assert(numel(data.source_id) == 1, ...
    'Mach derivative table must contain exactly one source identifier.');
assert(data.source_id == "DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0", ...
    'Unexpected Mach derivative source identifier.');
assert(numel(data.status) == 1 && data.status == "candidate-pending-review", ...
    'Mach derivative values must remain candidate-pending-review.');
assert(numel(data.interpolation_policy) == 1, ...
    'Mach derivative table must contain one interpolation policy.');
assert(numel(data.Mach) >= 2, ...
    'Mach derivative table must contain at least two Mach stations.');
assert(all(diff(data.Mach) > 0.0), ...
    'Mach derivative stations must be strictly increasing.');
assert(~any(isnan(data.grid.value(:))), ...
    'Mach derivative grid contains missing samples.');
assert(all(data.confidence_sample >= 0.0 & data.confidence_sample <= 1.0), ...
    'Mach derivative confidence values must be inside [0, 1].');
assert(numel(data.coefficients) == 10, ...
    'Mach derivative table should contain ten extracted coefficients.');
assert(all(data.static.CY_beta < 0.0), ...
    'CY_beta should be negative throughout the Mach derivative grid.');
assert(all(data.static.Cl_beta < 0.0), ...
    'Cl_beta should be negative throughout the Mach derivative grid.');
assert(all(data.static.Cn_beta > 0.0), ...
    'Cn_beta should be positive throughout the Mach derivative grid.');
assert(all(data.dynamic.Cl_p < 0.0), ...
    'Cl_p should be negative throughout the Mach derivative grid.');
assert(all(data.dynamic.Cm_q < 0.0), ...
    'Cm_q should be negative throughout the Mach derivative grid.');
assert(all(data.dynamic.Cn_r < 0.0), ...
    'Cn_r should be negative throughout the Mach derivative grid.');
end
