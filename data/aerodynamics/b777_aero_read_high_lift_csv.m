function data = b777_aero_read_high_lift_csv(csvFile)
%B777_AERO_READ_HIGH_LIFT_CSV Read a traceable high-lift increment table.
%
% Expected CSV columns:
% source_id, config, primary_source_id, current_source_id, status, confidence,
% flap_deg, slat_deployed, gear_down, delta_CL0, delta_CD0, delta_Cm0,
% induced_drag_delta, CLmax_estimate, validity_alpha_min_deg,
% validity_alpha_max_deg, notes

if nargin < 1 || ~(ischar(csvFile) || isstring(csvFile)) || strlength(csvFile) == 0
    error('b777_aero_read_high_lift_csv:InvalidPath', ...
        'csvFile must be a non-empty character vector or string scalar.');
end

csvFile = char(csvFile);
fid = fopen(csvFile, 'r');
if fid < 0
    error('b777_aero_read_high_lift_csv:OpenFailed', ...
        'Unable to open high-lift CSV file: %s', csvFile);
end

cleanup = onCleanup(@() fclose(fid));
raw = textscan(fid, '%s%s%s%s%s%f%f%s%s%f%f%f%f%f%f%f%s', ...
    'Delimiter', ',', ...
    'HeaderLines', 1, ...
    'Whitespace', '', ...
    'CollectOutput', false);

sourceId = string(raw{1});
configName = string(raw{2});
primarySourceId = string(raw{3});
currentSourceId = string(raw{4});
status = string(raw{5});
confidence = raw{6};
flapDeg = raw{7};
slatDeployed = parse_logical(raw{8}, 'slat_deployed');
gearDown = parse_logical(raw{9}, 'gear_down');
numeric = [raw{10}, raw{11}, raw{12}, raw{13}, raw{14}, raw{15}, raw{16}];
notes = string(raw{17});

finiteRows = isfinite(confidence) & isfinite(flapDeg) ...
    & all(isfinite(numeric), 2);
sourceId = sourceId(finiteRows);
configName = configName(finiteRows);
primarySourceId = primarySourceId(finiteRows);
currentSourceId = currentSourceId(finiteRows);
status = status(finiteRows);
confidence = confidence(finiteRows);
flapDeg = flapDeg(finiteRows);
slatDeployed = slatDeployed(finiteRows);
gearDown = gearDown(finiteRows);
numeric = numeric(finiteRows, :);
notes = notes(finiteRows);

if isempty(configName)
    error('b777_aero_read_high_lift_csv:EmptyTable', ...
        'High-lift CSV file contains no finite numeric rows: %s', csvFile);
end

data = struct();
data.source_file = string(csvFile);
data.source_id_sample = sourceId;
data.source_id = unique(sourceId, 'stable');
data.config_name = configName;
data.primary_source_id_sample = primarySourceId;
data.current_source_id_sample = currentSourceId;
data.status_sample = status;
data.confidence_sample = confidence;
data.confidence = min(confidence);
data.flap_deg_sample = flapDeg;
data.slat_deployed_sample = slatDeployed;
data.gear_down_sample = gearDown;
data.notes_sample = notes;

nConfig = numel(configName);
data.configs = repmat(empty_high_lift_config(), 1, nConfig);
for k = 1:nConfig
    cfg = empty_high_lift_config();
    cfg.name = configName(k);
    cfg.primary_source_id = primarySourceId(k);
    cfg.current_source_id = currentSourceId(k);
    cfg.status = status(k);
    cfg.confidence = confidence(k);
    cfg.flap_deg = flapDeg(k);
    cfg.slat_deployed = slatDeployed(k);
    cfg.gear_down = gearDown(k);
    cfg.CLmax_estimate = numeric(k, 5);
    cfg.validity.alpha_deg = [numeric(k, 6), numeric(k, 7)];
    cfg.validity.alpha_rad = deg2rad_local(cfg.validity.alpha_deg);
    cfg.notes = notes(k);
    cfg.increments.CL0 = numeric(k, 1);
    cfg.increments.CD0 = numeric(k, 2);
    cfg.increments.Cm0 = numeric(k, 3);
    cfg.increments.induced_drag_delta = numeric(k, 4);

    data.configs(k) = cfg;
end

validate_high_lift_table(data);
end

function cfg = empty_high_lift_config()
cfg = struct();
cfg.name = "";
cfg.primary_source_id = "";
cfg.current_source_id = "";
cfg.status = "";
cfg.confidence = NaN;
cfg.flap_deg = NaN;
cfg.slat_deployed = false;
cfg.gear_down = false;
cfg.CLmax_estimate = NaN;
cfg.validity = struct();
cfg.validity.alpha_deg = [NaN, NaN];
cfg.validity.alpha_rad = [NaN, NaN];
cfg.notes = "";
cfg.increments = struct();
cfg.increments.CL0 = NaN;
cfg.increments.CD0 = NaN;
cfg.increments.Cm0 = NaN;
cfg.increments.induced_drag_delta = NaN;
end

function values = parse_logical(rawValues, label)
rawValues = lower(strtrim(string(rawValues)));
values = false(size(rawValues));
for k = 1:numel(rawValues)
    token = rawValues(k);
    if token == "true" || token == "1" || token == "yes"
        values(k) = true;
    elseif token == "false" || token == "0" || token == "no"
        values(k) = false;
    else
        error('b777_aero_read_high_lift_csv:InvalidLogical', ...
            '%s must contain true/false values. Invalid token: %s', ...
            label, char(token));
    end
end
end

function validate_high_lift_table(data)
assert(numel(data.source_id) == 1, ...
    'High-lift table must contain exactly one source identifier.');
assert(numel(data.configs) == 3, ...
    'High-lift table must contain clean, approach and landing configs.');

clean = find_config(data.configs, "clean");
approach = find_config(data.configs, "approach");
landing = find_config(data.configs, "landing");

assert(clean.flap_deg == 0.0, ...
    'Clean high-lift configuration must have zero flap deflection.');
assert(approach.flap_deg > clean.flap_deg, ...
    'Approach flap deflection must exceed clean flap deflection.');
assert(landing.flap_deg > approach.flap_deg, ...
    'Landing flap deflection must exceed approach flap deflection.');
assert(~clean.slat_deployed && approach.slat_deployed && landing.slat_deployed, ...
    'Approach and landing configurations must deploy slats in the seed table.');
assert(~clean.gear_down && ~approach.gear_down && landing.gear_down, ...
    'Only landing configuration should include gear-down drag in this seed table.');
assert(approach.increments.CL0 > clean.increments.CL0, ...
    'Approach configuration must increase CL0 relative to clean.');
assert(landing.increments.CL0 > approach.increments.CL0, ...
    'Landing configuration must increase CL0 relative to approach.');
assert(approach.increments.CD0 > clean.increments.CD0, ...
    'Approach configuration must increase CD0 relative to clean.');
assert(landing.increments.CD0 > approach.increments.CD0, ...
    'Landing configuration must increase CD0 relative to approach.');
assert(approach.CLmax_estimate > clean.CLmax_estimate, ...
    'Approach CLmax estimate must exceed clean CLmax estimate.');
assert(landing.CLmax_estimate > approach.CLmax_estimate, ...
    'Landing CLmax estimate must exceed approach CLmax estimate.');
assert(all(data.confidence_sample >= 0.0 & data.confidence_sample <= 1.0), ...
    'High-lift confidence values must be inside [0, 1].');
end

function cfg = find_config(configs, configName)
for k = 1:numel(configs)
    if configs(k).name == configName
        cfg = configs(k);
        return;
    end
end

error('b777_aero_read_high_lift_csv:MissingConfig', ...
    'Missing high-lift configuration: %s', char(configName));
end

function rad = deg2rad_local(deg)
rad = deg * pi / 180.0;
end
