function cases = reference_cases()
%REFERENCE_CASES Reference flight conditions for validation and trim.
%
% Output:
%   cases - structure array with representative flight conditions.

cases = struct([]);

cases(1).name      = "cruise";
cases(1).h_m       = 10668;       % 35000 ft, placeholder
cases(1).Mach      = 0.84;
cases(1).gamma_rad = 0;
cases(1).massCase  = "cruise";

cases(2).name      = "approach";
cases(2).h_m       = 914.4;       % 3000 ft, placeholder
cases(2).Vtas_mps   = NaN;
cases(2).gamma_rad = deg2rad(-3);
cases(2).massCase  = "approach";

end
