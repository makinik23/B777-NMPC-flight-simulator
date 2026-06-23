function atm = b777_atmosphere_isa(h_m)
%B777_ATMOSPHERE_ISA Simple ISA atmosphere model up to 20 km.
%
% ATM = B777_ATMOSPHERE_ISA(H_M) returns temperature, pressure, density,
% speed of sound and viscosity at altitude H_M above mean sea level.

if ~isnumeric(h_m) || ~isscalar(h_m) || ~isreal(h_m) || ~isfinite(h_m)
    error('b777_atmosphere_isa:InvalidAltitude', ...
        'h_m must be a finite scalar altitude in meters.');
end

h_m = max(min(h_m, 20000.0), -500.0);

constants = b777_constants();
g0_mps2 = constants.standard_gravity_mps2;
gas_constant_JpkgK = 287.05287;
specific_heat_ratio = 1.4;

T0_K = 288.15;
p0_Pa = 101325.0;
rho0_kgm3 = 1.225;
lapse_rate_Kpm = -0.0065;

h_tropopause_m = 11000.0;
T11_K = T0_K + lapse_rate_Kpm * h_tropopause_m;
p11_Pa = p0_Pa * (T11_K / T0_K)^(-g0_mps2 / ...
    (lapse_rate_Kpm * gas_constant_JpkgK));

if h_m <= h_tropopause_m
    T_K = T0_K + lapse_rate_Kpm * h_m;
    p_Pa = p0_Pa * (T_K / T0_K)^(-g0_mps2 / ...
        (lapse_rate_Kpm * gas_constant_JpkgK));
else
    T_K = T11_K;
    p_Pa = p11_Pa * exp(-g0_mps2 * (h_m - h_tropopause_m) / ...
        (gas_constant_JpkgK * T11_K));
end

rho_kgm3 = p_Pa / (gas_constant_JpkgK * T_K);
a_mps = sqrt(specific_heat_ratio * gas_constant_JpkgK * T_K);

mu0_Pas = 1.7894e-5;
sutherland_K = 110.4;
mu_Pas = mu0_Pas * (T_K / T0_K)^(3/2) * ...
    (T0_K + sutherland_K) / (T_K + sutherland_K);

atm = struct();
atm.h_m = h_m;
atm.g_mps2 = g0_mps2;
atm.T_K = T_K;
atm.p_Pa = p_Pa;
atm.rho_kgm3 = rho_kgm3;
atm.a_mps = a_mps;
atm.mu_Pas = mu_Pas;
atm.nu_m2ps = mu_Pas / rho_kgm3;

atm.theta = T_K / T0_K;
atm.delta = p_Pa / p0_Pa;
atm.sigma = rho_kgm3 / rho0_kgm3;

end
