function loads = b777_aero_forces_moments(state, control, configName, options)
%B777_AERO_FORCES_MOMENTS Convert aerodynamic coefficients to plant loads.
%
% LOADS = B777_AERO_FORCES_MOMENTS(STATE, CONTROL) returns aerodynamic forces
% and moments for the clean configuration. The returned force and moment
% vectors are expressed in the body frame: x forward, y right, z down.
%
% Optional inputs:
%   CONFIG_NAME - "clean", "approach" or "landing".
%   OPTIONS     - struct with optional fields:
%                 aero, geometry, rho_kgm3, h_m,
%                 cg_body_m, aero_reference_point_body_m.

if nargin < 3 || isempty(configName)
    configName = "clean";
end

if nargin < 4 || isempty(options)
    options = struct();
end

geom = option_or_default(options, 'geometry', b777_geometry());
aero = option_or_default(options, 'aero', b777_aero_database());

[stateForAero, atmosphere] = complete_aero_state(state, options);
coeff = aero.coeff(stateForAero, control, string(configName));

qbar_Pa = 0.5 * atmosphere.rho_kgm3 * stateForAero.V_mps^2;
S_m2 = aero.reference.S_m2;
b_m = aero.reference.b_m;
c_m = aero.reference.c_m;

forceWind_N = qbar_Pa * S_m2 * [ ...
    -coeff.CD; ...
     coeff.CY; ...
    -coeff.CL ...
];

windToBody = wind_to_body_dcm( ...
    stateForAero.alpha_rad, ...
    stateForAero.beta_rad);
forceBody_N = windToBody * forceWind_N;

momentReferenceBody_Nm = qbar_Pa * S_m2 * [ ...
    b_m * coeff.Cl; ...
    c_m * coeff.Cm; ...
    b_m * coeff.Cn ...
];

cgBody_m = option_or_default(options, 'cg_body_m', geom.reference.cg_body_m);
aeroRefBody_m = option_or_default(options, ...
    'aero_reference_point_body_m', ...
    geom.reference.aero_reference_point_body_m);

cgBody_m = column3(cgBody_m, 'cg_body_m');
aeroRefBody_m = column3(aeroRefBody_m, 'aero_reference_point_body_m');
referenceToCgMoment_Nm = cross(aeroRefBody_m - cgBody_m, forceBody_N);
momentBody_Nm = momentReferenceBody_Nm + referenceToCgMoment_Nm;

loads = struct();
loads.config = string(configName);
loads.coeff = coeff;
loads.atmosphere = atmosphere;
loads.dynamic_pressure_Pa = qbar_Pa;
loads.Mach = stateForAero.Mach;
loads.force_wind_N = forceWind_N;
loads.force_body_N = forceBody_N;
loads.moment_reference_body_Nm = momentReferenceBody_Nm;
loads.cg_shift_moment_body_Nm = referenceToCgMoment_Nm;
loads.moment_body_Nm = momentBody_Nm;
loads.wind_to_body_dcm = windToBody;
loads.reference.S_m2 = S_m2;
loads.reference.b_m = b_m;
loads.reference.c_m = c_m;
loads.reference.cg_body_m = cgBody_m;
loads.reference.aero_reference_point_body_m = aeroRefBody_m;
loads.source.current_source_id = coeff.current_source_id;
loads.source.clean_baseline_source_id = coeff.clean_baseline_source_id;
loads.source.config_increment_source_id = coeff.config_increment_source_id;
loads.source.table_status = coeff.table_status;
loads.source.validity_status = coeff.validity_status;
end

function [stateForAero, atmosphere] = complete_aero_state(state, options)
stateForAero = state;

if ~isfield(stateForAero, 'V_mps') ...
        || ~isfield(stateForAero, 'alpha_rad') ...
        || ~isfield(stateForAero, 'beta_rad')
    [hasVelocity, u, v, w] = body_velocity_components(stateForAero);
    if hasVelocity
        V = sqrt(u^2 + v^2 + w^2);
        stateForAero.V_mps = V;
        stateForAero.alpha_rad = atan2(w, u);
        stateForAero.beta_rad = asin(max(min(v / max(V, 1e-9), 1.0), -1.0));
    end
end

stateForAero = complete_rate_fields(stateForAero);

altitude_m = infer_altitude_m(stateForAero, options);
if isfield(options, 'rho_kgm3')
    rho_kgm3 = validate_positive_scalar(options.rho_kgm3, 'rho_kgm3');
    atmosphere = struct();
    atmosphere.h_m = altitude_m;
    atmosphere.rho_kgm3 = rho_kgm3;
    atmosphere.a_mps = infer_speed_of_sound_mps(stateForAero, altitude_m);
    atmosphere.source = "provided-density";
elseif isfield(stateForAero, 'rho_kgm3')
    rho_kgm3 = validate_positive_scalar(stateForAero.rho_kgm3, 'state.rho_kgm3');
    atmosphere = struct();
    atmosphere.h_m = altitude_m;
    atmosphere.rho_kgm3 = rho_kgm3;
    atmosphere.a_mps = infer_speed_of_sound_mps(stateForAero, altitude_m);
    atmosphere.source = "state-density";
else
    atmosphere = b777_atmosphere_isa(altitude_m);
    atmosphere.source = "ISA";
end

if ~isfield(stateForAero, 'Mach')
    stateForAero.Mach = stateForAero.V_mps / atmosphere.a_mps;
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

function state = complete_rate_fields(state)
if ~isfield(state, 'p_radps') && has_finite_scalar_field(state, 'p')
    state.p_radps = state.p;
end

if ~isfield(state, 'q_radps') && has_finite_scalar_field(state, 'q')
    state.q_radps = state.q;
end

if ~isfield(state, 'r_radps') && has_finite_scalar_field(state, 'r')
    state.r_radps = state.r;
end
end

function altitude_m = infer_altitude_m(state, options)
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
end

function a_mps = infer_speed_of_sound_mps(state, altitude_m)
if isfield(state, 'a_mps')
    a_mps = validate_positive_scalar(state.a_mps, 'state.a_mps');
else
    atm = b777_atmosphere_isa(altitude_m);
    a_mps = atm.a_mps;
end
end

function dcm = wind_to_body_dcm(alphaRad, betaRad)
ca = cos(alphaRad);
sa = sin(alphaRad);
cb = cos(betaRad);
sb = sin(betaRad);

dcm = [ ...
    ca * cb, -ca * sb, -sa; ...
    sb,       cb,        0.0; ...
    sa * cb, -sa * sb,  ca ...
];
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

function value = validate_positive_scalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) ...
        || ~isfinite(value) || value <= 0.0
    error('b777_aero_forces_moments:InvalidInput', ...
        '%s must be a positive finite numeric scalar.', label);
end
end

function value = validate_finite_scalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) ...
        || ~isfinite(value)
    error('b777_aero_forces_moments:InvalidInput', ...
        '%s must be a finite numeric scalar.', label);
end
end

function value = column3(value, label)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 3 ...
        || any(~isfinite(value(:)))
    error('b777_aero_forces_moments:InvalidInput', ...
        '%s must be a finite 3-element numeric vector.', label);
end

value = value(:);
end
