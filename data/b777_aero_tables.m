function aero = b777_aero_tables()
%B777_AERO_TABLES Initial approximate aerodynamic model coefficients.
%
% The first implementation will be intentionally simple:
%   CL = CL0 + CL_alpha * alpha + CL_de * delta_e
%   CD = CD0 + k * CL^2
%   Cm = Cm0 + Cm_alpha * alpha + Cm_q * q_hat + Cm_de * delta_e

aero = struct();

aero.CL0       = NaN;
aero.CL_alpha  = NaN;
aero.CL_de     = NaN;
aero.CD0       = NaN;
aero.k         = NaN;
aero.Cm0       = NaN;
aero.Cm_alpha  = NaN;
aero.Cm_q      = NaN;
aero.Cm_de     = NaN;

% Lateral-directional placeholder coefficients
aero.CY_beta   = NaN;
aero.Cl_beta   = NaN;
aero.Cn_beta   = NaN;
aero.Cl_da     = NaN;
aero.Cn_dr     = NaN;

end
