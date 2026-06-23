function loads = b777_engine_forces_moments(state, command, options)
%B777_ENGINE_FORCES_MOMENTS Convert engine thrust states to body loads.
%
% LOADS = B777_ENGINE_FORCES_MOMENTS(STATE, COMMAND) returns propulsion force
% and moment vectors in the body frame: x forward, y right, z down.
%
% STATE may contain h_m, Mach, u/v/w or T1/T2 thrust states. COMMAND may
% contain throttle, throttle_left/throttle_right, tau, tau_left/tau_right or a
% 2-element throttle vector. If actual thrust states are not provided, the
% commanded thrust values are used as actual thrust for the returned loads.

if nargin < 1 || isempty(state)
    state = struct();
end

if nargin < 2 || isempty(command)
    command = struct();
end

if nargin < 3 || isempty(options)
    options = struct();
end

engine = option_or_default(options, 'engine', b777_engine_model());
geom = option_or_default(options, 'geometry', b777_geometry());

[altitude_m, mach, atmosphere] = infer_flight_condition(state, options);
[throttleLeft, throttleRight] = infer_throttle_pair(command, engine);

maxThrust_N = engine.max_thrust_per_engine_N(altitude_m, mach);
idleThrust_N = engine.idle_thrust_per_engine_N(altitude_m, mach);
commandedLeft_N = engine.commanded_thrust_per_engine_N( ...
    altitude_m, mach, throttleLeft);
commandedRight_N = engine.commanded_thrust_per_engine_N( ...
    altitude_m, mach, throttleRight);

actualLeft_N = infer_actual_thrust(state, ...
    {'T1_N', 'T_left_N', 'left_thrust_N', 'T1'}, commandedLeft_N);
actualRight_N = infer_actual_thrust(state, ...
    {'T2_N', 'T_right_N', 'right_thrust_N', 'T2'}, commandedRight_N);

actualLeft_N = min(max(actualLeft_N, 0.0), maxThrust_N);
actualRight_N = min(max(actualRight_N, 0.0), maxThrust_N);

thrustDirectionBody = option_or_default(options, ...
    'thrust_direction_body', engine.reference.force_direction_body);
thrustDirectionBody = unit_column3(thrustDirectionBody, ...
    'thrust_direction_body');

leftPositionBody_m = option_or_default(options, ...
    'left_engine_position_body_m', geom.engine.left_position_body_m);
rightPositionBody_m = option_or_default(options, ...
    'right_engine_position_body_m', geom.engine.right_position_body_m);
cgBody_m = option_or_default(options, 'cg_body_m', geom.reference.cg_body_m);

leftPositionBody_m = column3(leftPositionBody_m, 'left_engine_position_body_m');
rightPositionBody_m = column3(rightPositionBody_m, 'right_engine_position_body_m');
cgBody_m = column3(cgBody_m, 'cg_body_m');

forceLeftBody_N = actualLeft_N * thrustDirectionBody;
forceRightBody_N = actualRight_N * thrustDirectionBody;
forceBody_N = forceLeftBody_N + forceRightBody_N;

momentLeftBody_Nm = cross(leftPositionBody_m - cgBody_m, forceLeftBody_N);
momentRightBody_Nm = cross(rightPositionBody_m - cgBody_m, forceRightBody_N);
momentBody_Nm = momentLeftBody_Nm + momentRightBody_Nm;

loads = struct();
loads.model_id = engine.id;
loads.atmosphere = atmosphere;
loads.h_m = altitude_m;
loads.Mach = mach;
loads.throttle_left = throttleLeft;
loads.throttle_right = throttleRight;
loads.max_thrust_per_engine_N = maxThrust_N;
loads.idle_thrust_per_engine_N = idleThrust_N;
loads.commanded_thrust_N = [commandedLeft_N; commandedRight_N];
loads.actual_thrust_N = [actualLeft_N; actualRight_N];
loads.thrust_derivative_Nps = [ ...
    engine.spool_derivative_Nps(actualLeft_N, commandedLeft_N); ...
    engine.spool_derivative_Nps(actualRight_N, commandedRight_N) ...
];
loads.force_left_body_N = forceLeftBody_N;
loads.force_right_body_N = forceRightBody_N;
loads.force_body_N = forceBody_N;
loads.moment_left_body_Nm = momentLeftBody_Nm;
loads.moment_right_body_Nm = momentRightBody_Nm;
loads.moment_body_Nm = momentBody_Nm;
loads.reference.left_engine_position_body_m = leftPositionBody_m;
loads.reference.right_engine_position_body_m = rightPositionBody_m;
loads.reference.cg_body_m = cgBody_m;
loads.reference.thrust_direction_body = thrustDirectionBody;
loads.source.status = engine.data_status;
loads.source.model = engine.name;
end

function [altitude_m, mach, atmosphere] = infer_flight_condition(state, options)
if isfield(options, 'h_m')
    altitude_m = validate_finite_scalar(options.h_m, 'options.h_m');
elseif isfield(state, 'h_m')
    altitude_m = validate_finite_scalar(state.h_m, 'state.h_m');
elseif isfield(state, 'altitude_m')
    altitude_m = validate_finite_scalar(state.altitude_m, 'state.altitude_m');
elseif isfield(state, 'D_m')
    altitude_m = -validate_finite_scalar(state.D_m, 'state.D_m');
elseif isfield(state, 'D')
    altitude_m = -validate_finite_scalar(state.D, 'state.D');
else
    altitude_m = 0.0;
end

atmosphere = b777_atmosphere_isa(altitude_m);
atmosphere.source = "ISA";

if isfield(options, 'Mach')
    mach = validate_nonnegative_scalar(options.Mach, 'options.Mach');
elseif isfield(state, 'Mach')
    mach = validate_nonnegative_scalar(state.Mach, 'state.Mach');
else
    [hasVelocity, u, v, w] = body_velocity_components(state);
    if hasVelocity
        V_mps = sqrt(u^2 + v^2 + w^2);
        mach = V_mps / atmosphere.a_mps;
    else
        mach = 0.0;
    end
end
end

function [left, right] = infer_throttle_pair(command, engine)
if isnumeric(command) && numel(command) == 2
    left = command(1);
    right = command(2);
elseif isnumeric(command) && isscalar(command)
    left = command;
    right = command;
elseif isstruct(command)
    if isfield(command, 'throttle') && isnumeric(command.throttle) ...
            && numel(command.throttle) == 2
        left = command.throttle(1);
        right = command.throttle(2);
    else
        left = first_available_scalar(command, ...
            {'throttle_left', 'tau_left', 'left_throttle', 'tau'}, 0.0);
        right = first_available_scalar(command, ...
            {'throttle_right', 'tau_right', 'right_throttle', 'tau'}, left);
        if isfield(command, 'throttle') && isnumeric(command.throttle) ...
                && isscalar(command.throttle)
            left = command.throttle;
            right = command.throttle;
        end
    end
else
    left = 0.0;
    right = 0.0;
end

left = saturate_throttle(left, engine);
right = saturate_throttle(right, engine);
end

function value = first_available_scalar(data, fieldNames, defaultValue)
value = defaultValue;
for k = 1:numel(fieldNames)
    fieldName = fieldNames{k};
    if isfield(data, fieldName)
        candidate = data.(fieldName);
        if isnumeric(candidate) && isscalar(candidate) && isreal(candidate) ...
                && isfinite(candidate)
            value = candidate;
            return;
        end
    end
end
end

function value = saturate_throttle(value, engine)
value = validate_finite_scalar(value, 'throttle');
value = min(max(value, engine.throttle_min), engine.throttle_max);
end

function value = infer_actual_thrust(state, fieldNames, defaultValue)
value = defaultValue;
for k = 1:numel(fieldNames)
    fieldName = fieldNames{k};
    if isfield(state, fieldName)
        candidate = state.(fieldName);
        if isnumeric(candidate) && isscalar(candidate) && isreal(candidate) ...
                && isfinite(candidate)
            value = candidate;
            return;
        end
    end
end
end

function [tf, u, v, w] = body_velocity_components(state)
if has_finite_scalar_field(state, 'u_mps') ...
        && has_finite_scalar_field(state, 'v_mps') ...
        && has_finite_scalar_field(state, 'w_mps')
    tf = true;
    u = state.u_mps;
    v = state.v_mps;
    w = state.w_mps;
elseif has_finite_scalar_field(state, 'u') ...
        && has_finite_scalar_field(state, 'v') ...
        && has_finite_scalar_field(state, 'w')
    tf = true;
    u = state.u;
    v = state.v;
    w = state.w;
else
    tf = false;
    u = NaN;
    v = NaN;
    w = NaN;
end
end

function value = option_or_default(options, fieldName, defaultValue)
if isstruct(options) && isfield(options, fieldName)
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function tf = has_finite_scalar_field(data, fieldName)
tf = isfield(data, fieldName) ...
    && isnumeric(data.(fieldName)) ...
    && isscalar(data.(fieldName)) ...
    && isreal(data.(fieldName)) ...
    && isfinite(data.(fieldName));
end

function value = validate_finite_scalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) ...
        || ~isfinite(value)
    error('b777_engine_forces_moments:InvalidInput', ...
        '%s must be a finite numeric scalar.', label);
end
end

function value = validate_nonnegative_scalar(value, label)
value = validate_finite_scalar(value, label);
if value < 0.0
    error('b777_engine_forces_moments:InvalidInput', ...
        '%s must be nonnegative.', label);
end
end

function value = column3(value, label)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 3 ...
        || any(~isfinite(value(:)))
    error('b777_engine_forces_moments:InvalidInput', ...
        '%s must be a finite 3-element numeric vector.', label);
end

value = value(:);
end

function value = unit_column3(value, label)
value = column3(value, label);
normValue = norm(value);
if normValue <= 0.0
    error('b777_engine_forces_moments:InvalidInput', ...
        '%s must have nonzero norm.', label);
end
value = value ./ normValue;
end
