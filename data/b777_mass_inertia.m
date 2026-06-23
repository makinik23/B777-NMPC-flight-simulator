function mass = b777_mass_inertia(mass_kg)
%B777_MASS_INERTIA Return mass properties for the B777-like simulator.
%
% MASS = B777_MASS_INERTIA() returns the nominal cruise-mass case.
% MASS = B777_MASS_INERTIA(MASS_KG) scales the inertia estimate to MASS_KG.
% MASS.FORCES(G_MPS2) returns force quantities that depend on local gravity.
% MASS.STANDARD_GRAVITY_MPS2 is the current fixed project default gravity.
%
% Boeing does not publish a certified full inertia tensor for public use.
% The inertia tensor below is therefore a first-cut engineering estimate,
% based on effective radii of gyration derived from the public aircraft
% dimensions. It is suitable for early model integration and must be refined
% through trim, modal response and validation checks.

if nargin < 1
    mass_kg = 250000.0;
end

if ~isnumeric(mass_kg) || ~isscalar(mass_kg) || ~isreal(mass_kg) ...
        || ~isfinite(mass_kg) || mass_kg <= 0
    error('b777_mass_inertia:InvalidMass', ...
        'mass_kg must be a positive finite scalar mass value.');
end

constants = b777_constants();
geom = b777_geometry();

mass = struct();
mass.name = 'B777-300ER-like mass and inertia data';
mass.units.mass = 'kg';
mass.units.inertia = 'kg m^2';
mass.units.gravity = 'm/s^2';
mass.units.force = 'N';
mass.standard_gravity_mps2 = constants.standard_gravity_mps2;

mass.max_takeoff_kg = 351530.0;
mass.max_landing_kg = 251290.0;
mass.max_zero_fuel_kg = 237680.0;
mass.operating_empty_kg = 168700.0;
mass.max_payload_kg = 68500.0;
mass.usable_fuel_kg_estimate = 142300.0;

mass.nominal_cruise_kg = 250000.0;
mass.nominal_approach_kg = 220000.0;
mass.current_kg = mass_kg;

current_kg = mass.current_kg;
max_takeoff_kg = mass.max_takeoff_kg;
max_static_thrust_total_N = geom.engine.max_static_thrust_total_N;

mass.forces = @(g_mps2) b777_mass_forces( ...
    current_kg, ...
    max_takeoff_kg, ...
    max_static_thrust_total_N, ...
    g_mps2);

mass.source_notes = { ...
    'MTOW is aligned with public Boeing 777-300ER characteristics.', ...
    'MLW, MZFW, OEW, payload and fuel are public planning-level values or first-cut estimates.', ...
    'The inertia tensor is estimated, not certified or proprietary Boeing data.', ...
    'Project checks currently use fixed standard gravity from mass.standard_gravity_mps2.', ...
    'Gravity-dependent force values are computed by mass.forces(g_mps2).' ...
};

% Effective radii of gyration. The vertical mass radius is intentionally
% smaller than half the overall tail height because most mass is concentrated
% near the fuselage, wing and landing gear.
effective_half_length_m = geom.fuselage.length_m / 2;
effective_half_span_m = geom.wing.span_m / 2;
effective_vertical_radius_m = 4.5;

kx_m = sqrt((effective_half_span_m^2 + effective_vertical_radius_m^2) / 5);
ky_m = sqrt((effective_half_length_m^2 + effective_vertical_radius_m^2) / 5);
kz_m = sqrt((effective_half_length_m^2 + effective_half_span_m^2) / 5);

mass.radius_of_gyration_m = struct();
mass.radius_of_gyration_m.kx = kx_m;
mass.radius_of_gyration_m.ky = ky_m;
mass.radius_of_gyration_m.kz = kz_m;
mass.radius_of_gyration_method = ...
    'uniform-ellipsoid-inspired first-cut estimate with reduced vertical mass radius';

mass.Ixx_kgm2 = mass.current_kg * kx_m^2;
mass.Iyy_kgm2 = mass.current_kg * ky_m^2;
mass.Izz_kgm2 = mass.current_kg * kz_m^2;
mass.Ixz_kgm2 = 0.0;

mass.inertia_matrix_kgm2 = [ ...
    mass.Ixx_kgm2, 0.0, -mass.Ixz_kgm2; ...
    0.0, mass.Iyy_kgm2, 0.0; ...
   -mass.Ixz_kgm2, 0.0, mass.Izz_kgm2 ...
];

mass.inverse_inertia_matrix_1_kgm2 = inv(mass.inertia_matrix_kgm2);
end

function forces = b777_mass_forces( ...
    current_kg, max_takeoff_kg, max_static_thrust_total_N, g_mps2)
%B777_MASS_FORCES Compute gravity-dependent force quantities.

if ~isnumeric(g_mps2) || ~isreal(g_mps2) || isempty(g_mps2) ...
        || any(~isfinite(g_mps2(:))) || any(g_mps2(:) <= 0)
    error('b777_mass_inertia:InvalidGravity', ...
        'g_mps2 must contain positive numeric gravity acceleration values.');
end

forces = struct();
forces.g_mps2 = g_mps2;
forces.weight_N = current_kg .* g_mps2;
forces.max_takeoff_weight_N = max_takeoff_kg .* g_mps2;
forces.thrust_to_weight_at_mtow = ...
    max_static_thrust_total_N ./ forces.max_takeoff_weight_N;
end
