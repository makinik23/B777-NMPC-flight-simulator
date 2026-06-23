function cases = reference_cases()
%REFERENCE_CASES Reference flight conditions for validation and trim.
%
% Output:
%   cases - structure array with representative flight conditions.

cases = struct([]);

mass = b777_mass_inertia();
g0_mps2 = mass.standard_gravity_mps2;

cases(1).name      = "cruise";
cases(1).h_m       = 10668;       % 35000 ft, placeholder
cases(1).Mach      = 0.84;
cases(1).Vtas_mps  = NaN;
cases(1).gamma_rad = 0;
cases(1).config    = "clean";
cases(1).mass_kg   = mass.nominal_cruise_kg;
cases(1).g_mps2    = g0_mps2;

cases(2).name      = "approach";
cases(2).h_m       = 914.4;       % 3000 ft, placeholder
cases(2).Mach      = NaN;
cases(2).Vtas_mps  = NaN;
cases(2).gamma_rad = deg2rad(-3);
cases(2).config    = "approach";
cases(2).mass_kg   = mass.nominal_approach_kg;
cases(2).g_mps2    = g0_mps2;

end
