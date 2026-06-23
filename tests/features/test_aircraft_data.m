%TEST_AIRCRAFT_DATA Validate B777-like geometry, mass and reference cases.

scriptPath = mfilename('fullpath');
featureTestDir = fileparts(scriptPath);
testsDir = fileparts(featureTestDir);
projectRoot = fileparts(testsDir);

addpath(fullfile(projectRoot, 'data'));

geom = b777_geometry();
mass = b777_mass_inertia();
cases = reference_cases();
constants = b777_constants();
seaLevelAtm = b777_atmosphere_isa(0.0);
forces = mass.forces(mass.standard_gravity_mps2);

assertRange(geom.fuselage.length_m, 70.0, 80.0, 'fuselage length');
assertRange(geom.wing.span_m, 60.0, 70.0, 'wing span');
assertRange(geom.wing.area_m2, 400.0, 460.0, 'wing area');
assertRange(geom.wing.mean_aerodynamic_chord_m, 6.0, 8.5, 'wing MAC');

expectedAspectRatio = geom.wing.span_m^2 / geom.wing.area_m2;
assertClose(geom.wing.aspect_ratio, expectedAspectRatio, 1e-12, 'wing aspect ratio');

expectedMeanChord = geom.wing.area_m2 / geom.wing.span_m;
assertClose(geom.wing.geometric_mean_chord_m, expectedMeanChord, 1e-12, ...
    'geometric mean chord');

assert(mass.operating_empty_kg < mass.nominal_approach_kg, ...
    'Approach mass must be greater than operating empty mass.');
assert(mass.nominal_approach_kg < mass.nominal_cruise_kg, ...
    'Approach mass must be lower than nominal cruise mass.');
assert(mass.nominal_cruise_kg < mass.max_takeoff_kg, ...
    'Nominal cruise mass must be lower than MTOW.');
assertClose(mass.standard_gravity_mps2, constants.standard_gravity_mps2, 1e-12, ...
    'fixed standard gravity');
assertClose(seaLevelAtm.g_mps2, constants.standard_gravity_mps2, 1e-12, ...
    'ISA gravity constant');
assertRange(seaLevelAtm.rho_kgm3, 1.20, 1.25, 'ISA sea-level density');

assert(issymmetric(mass.inertia_matrix_kgm2), ...
    'Inertia matrix must be symmetric.');
assert(all(eig(mass.inertia_matrix_kgm2) > 0), ...
    'Inertia matrix must be positive definite.');
assert(mass.Izz_kgm2 > mass.Iyy_kgm2, ...
    'Yaw inertia should be the largest first-cut inertia.');
assert(mass.Iyy_kgm2 > mass.Ixx_kgm2, ...
    'Pitch inertia should be greater than roll inertia for this first cut.');

assertRange(forces.thrust_to_weight_at_mtow, 0.25, 0.35, ...
    'static thrust-to-weight ratio at MTOW');
assertClose(forces.weight_N, mass.current_kg * mass.standard_gravity_mps2, ...
    1e-6, 'current weight at fixed gravity');

assert(numel(cases) == 2, 'Expected two reference cases.');
assertClose(cases(1).mass_kg, mass.nominal_cruise_kg, 1e-12, ...
    'cruise reference mass');
assertClose(cases(2).mass_kg, mass.nominal_approach_kg, 1e-12, ...
    'approach reference mass');
assertClose(cases(1).g_mps2, mass.standard_gravity_mps2, 1e-12, ...
    'cruise reference gravity');
assertClose(cases(2).g_mps2, mass.standard_gravity_mps2, 1e-12, ...
    'approach reference gravity');

fprintf('Feature test passed: aircraft data are defined consistently.\n');

function assertRange(value, lowerBound, upperBound, label)
    assert(value >= lowerBound && value <= upperBound, ...
        '%s is outside expected range: %.8g', label, value);
end

function assertClose(value, expected, tolerance, label)
    assert(abs(value - expected) <= tolerance, ...
        '%s mismatch: got %.16g, expected %.16g', label, value, expected);
end
