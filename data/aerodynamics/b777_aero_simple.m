function aero = b777_aero_simple()
%B777_AERO_SIMPLE First-cut aerodynamic coefficient model.
%
% Coefficients follow the project sign convention:
%   body frame: x forward, y right, z down
%   positive elevator: trailing edge down
%   positive elevator should produce negative pitching moment

geom = b777_geometry();

aero = struct();

aero.reference.S_m2 = geom.wing.area_m2;
aero.reference.b_m = geom.wing.span_m;
aero.reference.c_m = geom.wing.mean_aerodynamic_chord_m;
aero.reference.aspect_ratio = geom.wing.aspect_ratio;

aero.validity.alpha_min_rad = deg2rad_local(-10.0);
aero.validity.alpha_max_rad = deg2rad_local(15.0);
aero.validity.beta_min_rad = deg2rad_local(-10.0);
aero.validity.beta_max_rad = deg2rad_local(10.0);

aero.drag.CD0 = 0.0220;
aero.drag.oswald = 0.80;
aero.drag.k = 1.0 / (pi * aero.drag.oswald * aero.reference.aspect_ratio);
aero.drag.CD_beta = 0.20;
aero.drag.CD_delta_e = 0.03;
aero.drag.CD_delta_a = 0.02;
aero.drag.CD_delta_r = 0.02;

aero.longitudinal.CL0 = 0.25;
aero.longitudinal.CL_alpha = 5.50;
aero.longitudinal.CL_q = 7.50;
aero.longitudinal.CL_delta_e = 0.35;

aero.longitudinal.Cm0 = 0.05;
aero.longitudinal.Cm_alpha = -1.25;
aero.longitudinal.Cm_q = -18.0;
aero.longitudinal.Cm_delta_e = -1.10;

aero.lateral.CY_beta = -0.85;
aero.lateral.CY_p = -0.10;
aero.lateral.CY_r = 0.25;
aero.lateral.CY_delta_a = 0.00;
aero.lateral.CY_delta_r = 0.17;

aero.lateral.Cl_beta = -0.12;
aero.lateral.Cl_p = -0.50;
aero.lateral.Cl_r = 0.20;
aero.lateral.Cl_delta_a = 0.08;
aero.lateral.Cl_delta_r = 0.015;

aero.lateral.Cn_beta = 0.18;
aero.lateral.Cn_p = -0.06;
aero.lateral.Cn_r = -0.25;
aero.lateral.Cn_delta_a = 0.01;
aero.lateral.Cn_delta_r = 0.08;

aero.coeff = @(state, control) compute_coefficients(aero, state, control);
end

function coeff = compute_coefficients(aero, state, control)
V = max(state.V_mps, 1.0);

alpha = clamp(state.alpha_rad, ...
    aero.validity.alpha_min_rad, aero.validity.alpha_max_rad);

beta = clamp(state.beta_rad, ...
    aero.validity.beta_min_rad, aero.validity.beta_max_rad);

p_hat = state.p_radps * aero.reference.b_m / (2.0 * V);
q_hat = state.q_radps * aero.reference.c_m / (2.0 * V);
r_hat = state.r_radps * aero.reference.b_m / (2.0 * V);

de = control.delta_e_rad;
da = control.delta_a_rad;
dr = control.delta_r_rad;

CL = aero.longitudinal.CL0 ...
   + aero.longitudinal.CL_alpha * alpha ...
   + aero.longitudinal.CL_q * q_hat ...
   + aero.longitudinal.CL_delta_e * de;

CD = aero.drag.CD0 ...
   + aero.drag.k * CL^2 ...
   + aero.drag.CD_beta * beta^2 ...
   + aero.drag.CD_delta_e * de^2 ...
   + aero.drag.CD_delta_a * da^2 ...
   + aero.drag.CD_delta_r * dr^2;

Cm = aero.longitudinal.Cm0 ...
   + aero.longitudinal.Cm_alpha * alpha ...
   + aero.longitudinal.Cm_q * q_hat ...
   + aero.longitudinal.Cm_delta_e * de;

CY = aero.lateral.CY_beta * beta ...
   + aero.lateral.CY_p * p_hat ...
   + aero.lateral.CY_r * r_hat ...
   + aero.lateral.CY_delta_a * da ...
   + aero.lateral.CY_delta_r * dr;

Cl = aero.lateral.Cl_beta * beta ...
   + aero.lateral.Cl_p * p_hat ...
   + aero.lateral.Cl_r * r_hat ...
   + aero.lateral.Cl_delta_a * da ...
   + aero.lateral.Cl_delta_r * dr;

Cn = aero.lateral.Cn_beta * beta ...
   + aero.lateral.Cn_p * p_hat ...
   + aero.lateral.Cn_r * r_hat ...
   + aero.lateral.Cn_delta_a * da ...
   + aero.lateral.Cn_delta_r * dr;

coeff = struct();
coeff.CL = CL;
coeff.CD = CD;
coeff.CY = CY;
coeff.Cl = Cl;
coeff.Cm = Cm;
coeff.Cn = Cn;

coeff.alpha_used_rad = alpha;
coeff.beta_used_rad = beta;
coeff.p_hat = p_hat;
coeff.q_hat = q_hat;
coeff.r_hat = r_hat;
end

function y = clamp(x, xmin, xmax)
y = min(max(x, xmin), xmax);
end

function rad = deg2rad_local(deg)
rad = deg * pi / 180.0;
end