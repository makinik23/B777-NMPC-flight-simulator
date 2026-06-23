function highLift = b777_aero_high_lift_seed()
%B777_AERO_HIGH_LIFT_SEED Return CRM-HL/DATCOM-ready high-lift increments.
%
% These increments are intentionally low-confidence placeholders. They are
% stored in a source-oriented CSV table so CRM-HL or DATCOM-derived
% high-lift data can replace them without changing the plant interface.

dataDir = fileparts(mfilename('fullpath'));
rawFile = fullfile(dataDir, 'raw', 'high_lift', ...
    'b777_like_high_lift_seed.csv');
raw = b777_aero_read_high_lift_csv(rawFile);

highLift = raw;
highLift.id = raw.source_id;
highLift.primary_source_id = "NASA_CRM_HL";
highLift.secondary_source_id = "USAF_DATCOM";
highLift.current_source_id = raw.source_id;
highLift.status = "crmhl-datcom-ready-seed-active";
highLift.raw_status = unique(raw.status_sample, 'stable');
highLift.confidence = raw.confidence;
highLift.units.angle = "deg";
highLift.units.coefficient = "-";
highLift.source.local_raw_file = ...
    "data/aerodynamics/raw/high_lift/b777_like_high_lift_seed.csv";
highLift.source.kind = ...
    "CRM-HL/DATCOM-ready engineering high-lift increment seed";
highLift.source.primary_reference = "NASA CRM-HL";
highLift.source.secondary_reference = "USAF Stability and Control Digital DATCOM";
highLift.notes = ...
    "Low-confidence high-lift increments for trim bring-up; replace with CRM-HL or DATCOM-derived data.";

validate_high_lift(highLift);
end

function validate_high_lift(highLift)
configs = highLift.configs;

assert(highLift.id == "CRMHL_DATCOM_HIGH_LIFT_SEED_B777_LIKE_V0", ...
    'Unexpected high-lift seed table identifier.');
assert(configs(2).increments.CL0 > configs(1).increments.CL0, ...
    'Approach configuration must increase lift relative to clean.');
assert(configs(3).increments.CL0 > configs(2).increments.CL0, ...
    'Landing configuration must increase lift relative to approach.');
assert(configs(2).increments.CD0 > configs(1).increments.CD0, ...
    'Approach configuration must increase drag relative to clean.');
assert(configs(3).increments.CD0 > configs(2).increments.CD0, ...
    'Landing configuration must increase drag relative to approach.');
assert(configs(2).CLmax_estimate > configs(1).CLmax_estimate, ...
    'Approach CLmax estimate must exceed clean CLmax estimate.');
assert(configs(3).CLmax_estimate > configs(2).CLmax_estimate, ...
    'Landing CLmax estimate must exceed approach CLmax estimate.');
assert(configs(3).gear_down, ...
    'Landing seed configuration must include gear-down drag effects.');
end
