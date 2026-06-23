function act = b777_actuator_dynamics(state, command, options)
%B777_ACTUATOR_DYNAMICS Convert control commands to actuator state rates.
%
% ACT = B777_ACTUATOR_DYNAMICS(STATE, COMMAND) applies position limits,
% first-order actuator dynamics and rate limits for elevator, effective
% aileron and rudder. The returned ACT.control structure is ready for the
% aerodynamic database interface.

if nargin < 1 || isempty(state)
    state = struct();
end

if nargin < 2 || isempty(command)
    command = struct();
end

if nargin < 3 || isempty(options)
    options = struct();
end

model = option_or_default(options, 'actuator', b777_actuator_model());
surfaceNames = model.surface_names;
nSurface = numel(surfaceNames);

actual_rad = zeros(nSurface, 1);
commanded_rad = zeros(nSurface, 1);
commandedLimited_rad = zeros(nSurface, 1);
derivative_radps = zeros(nSurface, 1);
positionLimited = false(nSurface, 1);
commandLimited = false(nSurface, 1);
rateLimited = false(nSurface, 1);

for k = 1:nSurface
    surfaceKey = char(surfaceNames(k));
    surface = model.(surfaceKey);

    rawActual_rad = infer_actual_surface(state, surfaceKey, k);
    rawCommanded_rad = infer_command_surface(command, surfaceKey, k, ...
        rawActual_rad);

    [actual_rad(k), positionLimited(k)] = saturate( ...
        rawActual_rad, surface.position_min_rad, surface.position_max_rad);
    [commandedLimited_rad(k), commandLimited(k)] = saturate( ...
        rawCommanded_rad, surface.position_min_rad, surface.position_max_rad);
    commanded_rad(k) = rawCommanded_rad;

    desiredRate_radps = (commandedLimited_rad(k) - actual_rad(k)) ...
        / surface.tau_s;
    [derivative_radps(k), rateLimited(k)] = saturate( ...
        desiredRate_radps, surface.rate_min_radps, surface.rate_max_radps);

    derivative_radps(k) = block_rate_past_position_limit( ...
        actual_rad(k), derivative_radps(k), surface);
end

act = struct();
act.model_id = model.id;
act.surface_names = surfaceNames;
act.actual_rad = actual_rad;
act.commanded_rad = commanded_rad;
act.commanded_limited_rad = commandedLimited_rad;
act.derivative_radps = derivative_radps;
act.delta_e_rad = actual_rad(1);
act.delta_a_rad = actual_rad(2);
act.delta_r_rad = actual_rad(3);
act.delta_e_dot_radps = derivative_radps(1);
act.delta_a_dot_radps = derivative_radps(2);
act.delta_r_dot_radps = derivative_radps(3);
act.control.delta_e_rad = actual_rad(1);
act.control.delta_a_rad = actual_rad(2);
act.control.delta_r_rad = actual_rad(3);
act.limits.position_saturated = positionLimited;
act.limits.command_saturated = commandLimited;
act.limits.rate_saturated = rateLimited;
act.reference.elevator = model.elevator;
act.reference.aileron = model.aileron;
act.reference.rudder = model.rudder;
act.source.status = model.data_status;
act.source.model = model.name;
end

function value = infer_actual_surface(state, surfaceKey, index)
if isnumeric(state) && numel(state) >= index
    value = validate_finite_scalar(state(index), 'state');
    return;
end

if ~isstruct(state)
    value = 0.0;
    return;
end

switch surfaceKey
    case 'elevator'
        aliases = {'delta_e_rad', 'delta_e', 'elevator_rad', 'elevator'};
    case 'aileron'
        aliases = {'delta_a_rad', 'delta_a', 'aileron_rad', 'aileron'};
    case 'rudder'
        aliases = {'delta_r_rad', 'delta_r', 'rudder_rad', 'rudder'};
    otherwise
        aliases = {};
end

value = first_available_scalar(state, aliases, 0.0);
end

function value = infer_command_surface(command, surfaceKey, index, defaultValue)
if isnumeric(command) && numel(command) >= index
    value = validate_finite_scalar(command(index), 'command');
    return;
end

if ~isstruct(command)
    value = defaultValue;
    return;
end

switch surfaceKey
    case 'elevator'
        aliases = {'delta_e_cmd_rad', 'delta_e_cmd', ...
            'elevator_cmd_rad', 'elevator_cmd'};
    case 'aileron'
        aliases = {'delta_a_cmd_rad', 'delta_a_cmd', ...
            'aileron_cmd_rad', 'aileron_cmd'};
    case 'rudder'
        aliases = {'delta_r_cmd_rad', 'delta_r_cmd', ...
            'rudder_cmd_rad', 'rudder_cmd'};
    otherwise
        aliases = {};
end

value = first_available_scalar(command, aliases, defaultValue);
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

function rate_radps = block_rate_past_position_limit(actual_rad, ...
    rate_radps, surface)

tol = 1e-12;
if actual_rad <= surface.position_min_rad + tol && rate_radps < 0.0
    rate_radps = 0.0;
elseif actual_rad >= surface.position_max_rad - tol && rate_radps > 0.0
    rate_radps = 0.0;
end
end

function [value, wasLimited] = saturate(value, lowerBound, upperBound)
value = validate_finite_scalar(value, 'value');
wasLimited = value < lowerBound || value > upperBound;
value = min(max(value, lowerBound), upperBound);
end

function value = option_or_default(options, fieldName, defaultValue)
if isstruct(options) && isfield(options, fieldName)
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function value = validate_finite_scalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) ...
        || ~isfinite(value)
    error('b777_actuator_dynamics:InvalidInput', ...
        '%s must be a finite numeric scalar.', label);
end
end
