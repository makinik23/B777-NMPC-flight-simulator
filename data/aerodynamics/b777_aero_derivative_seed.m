function derivatives = b777_aero_derivative_seed()
%B777_AERO_DERIVATIVE_SEED Return traceable seed aerodynamic derivatives.
%
% The current values are engineering seeds arranged in a DATCOM-ready source
% table. They are exposed separately so the database can replace individual
% derivative groups with Digital DATCOM, CRM or validation-tuned data without
% changing the plant interface.

dataDir = fileparts(mfilename('fullpath'));
rawFile = fullfile(dataDir, 'raw', 'datcom', ...
    'b777_like_derivative_seed.csv');
raw = b777_aero_read_derivative_csv(rawFile);

derivatives = raw;
derivatives.id = raw.source_id;
derivatives.primary_source_id = "USAF_DATCOM";
derivatives.current_source_id = raw.source_id;
derivatives.fallback_source_id = "INITIAL_ANALYTIC_SEED";
derivatives.status = "datcom-ready-seed-active";
derivatives.raw_status = raw.status;
derivatives.confidence = raw.confidence;
derivatives.units.angle = "rad";
derivatives.units.rate = "nondimensional p_hat, q_hat, r_hat";
derivatives.units.control = "rad";
derivatives.units.drag_quadratic = "1/rad^2 for squared-angle drag increments";
derivatives.source.local_raw_file = ...
    "data/aerodynamics/raw/datcom/b777_like_derivative_seed.csv";
derivatives.source.kind = "DATCOM-ready engineering derivative seed";
derivatives.source.primary_reference = ...
    "USAF Stability and Control Digital DATCOM";
derivatives.notes = ...
    "Low-confidence derivative seed for plant integration and trim bring-up; replace with a documented Digital DATCOM run.";

validate_derivatives(derivatives);
end

function validate_derivatives(derivatives)
assert(derivatives.id == "DATCOM_DERIVATIVE_SEED_B777_LIKE_V0", ...
    'Unexpected derivative seed table identifier.');
assert(derivatives.control.Cm_delta_e < 0.0, ...
    'Positive elevator must produce negative pitching moment in the seed.');
assert(derivatives.control.Cl_delta_a > 0.0, ...
    'Positive effective aileron must produce positive rolling moment.');
assert(derivatives.control.Cn_delta_r > 0.0, ...
    'Positive rudder must produce positive yawing moment.');
assert(derivatives.dynamic.Cm_q < 0.0, ...
    'Pitch-rate damping derivative should be negative.');
assert(derivatives.dynamic.Cl_p < 0.0, ...
    'Roll-rate damping derivative should be negative.');
assert(derivatives.dynamic.Cn_r < 0.0, ...
    'Yaw-rate damping derivative should be negative.');
assert(derivatives.static.CD_beta >= 0.0, ...
    'Sideslip drag increment should be non-negative.');
assert(derivatives.control.CD_delta_e >= 0.0, ...
    'Elevator drag increment should be non-negative.');
assert(derivatives.control.CD_delta_a >= 0.0, ...
    'Aileron drag increment should be non-negative.');
assert(derivatives.control.CD_delta_r >= 0.0, ...
    'Rudder drag increment should be non-negative.');
end
