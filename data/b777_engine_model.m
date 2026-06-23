function engine = b777_engine_model()
%B777_ENGINE_MODEL Initial B777-like engine model.
%
% The model is intended for plant integration and early NMPC development. It
% is not a certified GE90 engine deck. It provides:
%   - public sea-level static thrust reference,
%   - altitude/Mach thrust lapse,
%   - idle-to-maximum throttle mapping,
%   - first-order thrust spool dynamics.

geom = b777_geometry();
constants = b777_constants();
seaLevel = b777_atmosphere_isa(0.0);

engine = struct();
engine.id = "B777_ENGINE_MODEL_V0";
engine.name = "B777-like GE90-115B propulsion seed";
engine.data_status = "public static thrust plus first-cut engineering estimates";
engine.n_engines = geom.engine.count;
engine.engine_model = string(geom.engine.model);
engine.units.force = "N";
engine.units.time = "s";
engine.units.length = "m";

engine.sources = { ...
    'GE Aerospace GE90-115B public thrust information: https://www.geaerospace.com/news/press-releases/commercial-engines/ge90-115b-ges-best-ever-new-jet-engine-entry-airline-service', ...
    'Boeing 777 public aircraft data used only for B777-like engine placement and scaling' ...
};

engine.max_static_thrust_per_engine_N = geom.engine.max_static_thrust_per_engine_N;
engine.max_static_thrust_total_N = ...
    engine.n_engines * engine.max_static_thrust_per_engine_N;
engine.sea_level_density_kgm3 = seaLevel.rho_kgm3;
engine.standard_gravity_mps2 = constants.standard_gravity_mps2;

% Low-order lapse model: T_max = T_SL * sigma^a * (1 - k_M*M), clipped.
engine.lapse_model = "density-ratio power law with Mach correction";
engine.density_lapse_exponent = 0.72;
engine.mach_lapse_slope = 0.18;
engine.min_mach_lapse_factor = 0.60;

% Idle thrust is modelled as a fraction of the local maximum available thrust.
engine.idle_thrust_fraction = 0.06;

% First-order spool dynamics for the thrust states T1 and T2.
engine.spool_tau_s = 5.0;
engine.spool_model = "dT/dt = (T_commanded - T_actual) / tau";

engine.throttle_min = 0.0;
engine.throttle_max = 1.0;
engine.throttle_note = ...
    "tau=0 maps to idle thrust; tau=1 maps to maximum available thrust";

engine.reference.left_position_body_m = geom.engine.left_position_body_m;
engine.reference.right_position_body_m = geom.engine.right_position_body_m;
engine.reference.cg_body_m = geom.reference.cg_body_m;
engine.reference.force_direction_body = [1.0; 0.0; 0.0];

maxStatic_N = engine.max_static_thrust_per_engine_N;
rho0 = engine.sea_level_density_kgm3;
densityExponent = engine.density_lapse_exponent;
machSlope = engine.mach_lapse_slope;
minMachFactor = engine.min_mach_lapse_factor;
idleFraction = engine.idle_thrust_fraction;
tau_s = engine.spool_tau_s;

engine.max_thrust_per_engine_N = @(h_m, mach) ...
    max_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor);
engine.idle_thrust_per_engine_N = @(h_m, mach) ...
    idle_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor, idleFraction);
engine.commanded_thrust_per_engine_N = @(h_m, mach, throttle) ...
    commanded_thrust_per_engine_N(h_m, mach, throttle, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor, idleFraction);
engine.spool_derivative_Nps = @(actual_N, commanded_N) ...
    (commanded_N - actual_N) ./ tau_s;

engine.notes = { ...
    'This is a first propulsion model for force and moment integration.', ...
    'The thrust lapse model is approximate and should later be calibrated against public performance data.', ...
    'Fuel flow, EPR/N1/N2, reverse thrust, gyroscopic moments and nacelle drag are outside this first model.' ...
};
end

function thrust_N = max_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor)

h_m = validate_finite_scalar(h_m, 'h_m');
mach = validate_nonnegative_scalar(mach, 'mach');

atmosphere = b777_atmosphere_isa(max(h_m, 0.0));
sigma = max(atmosphere.rho_kgm3 / rho0, 0.0);
machFactor = max(minMachFactor, 1.0 - machSlope * mach);
thrust_N = maxStatic_N * sigma^densityExponent * machFactor;
end

function thrust_N = idle_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor, idleFraction)

maxThrust_N = max_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor);
thrust_N = idleFraction * maxThrust_N;
end

function thrust_N = commanded_thrust_per_engine_N(h_m, mach, throttle, ...
    maxStatic_N, rho0, densityExponent, machSlope, minMachFactor, idleFraction)

throttle = min(max(validate_finite_scalar(throttle, 'throttle'), 0.0), 1.0);
maxThrust_N = max_thrust_per_engine_N(h_m, mach, maxStatic_N, rho0, ...
    densityExponent, machSlope, minMachFactor);
idleThrust_N = idleFraction * maxThrust_N;
thrust_N = idleThrust_N + throttle * (maxThrust_N - idleThrust_N);
end

function value = validate_finite_scalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) ...
        || ~isfinite(value)
    error('b777_engine_model:InvalidInput', ...
        '%s must be a finite numeric scalar.', label);
end
end

function value = validate_nonnegative_scalar(value, label)
value = validate_finite_scalar(value, label);
if value < 0.0
    error('b777_engine_model:InvalidInput', ...
        '%s must be nonnegative.', label);
end
end
