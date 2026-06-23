%TEST_ENGINE_LOADS Validate the initial propulsion load model.

scriptPath = mfilename('fullpath');
featureTestDir = fileparts(scriptPath);
testsDir = fileparts(featureTestDir);
projectRoot = fileparts(testsDir);

addpath(fullfile(projectRoot, 'data'));
addpath(fullfile(projectRoot, 'plant'));

geom = b777_geometry();
engine = b777_engine_model();

assert(engine.id == "B777_ENGINE_MODEL_V0", ...
    'Unexpected engine model identifier.');
assert(engine.n_engines == 2, 'B777-like model should have two engines.');
assertClose(engine.max_static_thrust_per_engine_N, ...
    geom.engine.max_static_thrust_per_engine_N, 1e-12, ...
    'sea-level static thrust');
assertRange(engine.spool_tau_s, 3.0, 10.0, 'engine spool time constant');

seaLevelMax_N = engine.max_thrust_per_engine_N(0.0, 0.0);
cruiseMax_N = engine.max_thrust_per_engine_N(10668.0, 0.84);
assertClose(seaLevelMax_N, engine.max_static_thrust_per_engine_N, 1e-6, ...
    'sea-level maximum thrust');
assert(cruiseMax_N < seaLevelMax_N, ...
    'Thrust lapse should reduce maximum thrust at cruise.');
assert(cruiseMax_N > 0.20 * seaLevelMax_N, ...
    'Cruise thrust should remain positive and plausible.');

idle_N = engine.commanded_thrust_per_engine_N(0.0, 0.0, 0.0);
mid_N = engine.commanded_thrust_per_engine_N(0.0, 0.0, 0.5);
full_N = engine.commanded_thrust_per_engine_N(0.0, 0.0, 1.0);
assert(idle_N > 0.0, 'Throttle zero should map to idle thrust.');
assert(mid_N > idle_N, 'Mid throttle should exceed idle thrust.');
assert(full_N > mid_N, 'Full throttle should exceed mid throttle.');
assertClose(full_N, seaLevelMax_N, 1e-6, 'full-throttle static thrust');

state = struct();
state.h_m = 0.0;
state.Mach = 0.0;

command = struct();
command.throttle = 0.5;
loadsSym = b777_engine_forces_moments(state, command);

expectedSymmetricForce_N = 2.0 * mid_N;
assertClose(loadsSym.force_body_N(1), expectedSymmetricForce_N, 1e-6, ...
    'symmetric engine force x');
assertClose(loadsSym.force_body_N(2), 0.0, 1e-12, ...
    'symmetric engine force y');
assertClose(loadsSym.force_body_N(3), 0.0, 1e-12, ...
    'symmetric engine force z');
assertClose(loadsSym.moment_body_Nm(3), 0.0, 1e-6, ...
    'symmetric engine yaw moment');

expectedPitchMoment_Nm = ...
    (geom.engine.left_position_body_m(3) - geom.reference.cg_body_m(3)) * mid_N ...
    + (geom.engine.right_position_body_m(3) - geom.reference.cg_body_m(3)) * mid_N;
assertClose(loadsSym.moment_body_Nm(2), expectedPitchMoment_Nm, 1e-6, ...
    'symmetric engine pitch moment');

commandAsym = struct();
commandAsym.throttle_left = 1.0;
commandAsym.throttle_right = 0.0;
loadsAsym = b777_engine_forces_moments(state, commandAsym);
assert(loadsAsym.moment_body_Nm(3) > 0.0, ...
    'Higher left-engine thrust should create positive yaw moment with current body convention.');
assertClose(loadsAsym.force_body_N(1), loadsSym.force_body_N(1), 1e-6, ...
    'full-left plus idle-right total force equals symmetric half throttle');

stateLag = state;
stateLag.T1_N = idle_N;
stateLag.T2_N = full_N;
commandLag = struct();
commandLag.throttle_left = 1.0;
commandLag.throttle_right = 0.0;
loadsLag = b777_engine_forces_moments(stateLag, commandLag);
assert(loadsLag.thrust_derivative_Nps(1) > 0.0, ...
    'Left engine should spool up toward full thrust.');
assert(loadsLag.thrust_derivative_Nps(2) < 0.0, ...
    'Right engine should spool down toward idle thrust.');

fprintf('Feature test passed: engine loads are defined consistently.\n');

function assertRange(value, lowerBound, upperBound, label)
    assert(value >= lowerBound && value <= upperBound, ...
        '%s is outside expected range: %.8g', label, value);
end

function assertClose(value, expected, tolerance, label)
    assert(abs(value - expected) <= tolerance, ...
        '%s mismatch: got %.16g, expected %.16g', label, value, expected);
end
