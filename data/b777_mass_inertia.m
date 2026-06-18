function mass = b777_mass_inertia(configName)
%B777_MASS_INERTIA Approximate mass and inertia data for a B777-like aircraft.
%
% Input:
%   configName - "cruise", "approach", "heavy", etc.
%
% Output:
%   mass - structure with mass and inertia in SI units.

if nargin < 1
    configName = "cruise";
end

mass = struct();
mass.configName = string(configName);

% Placeholder values. Fill during Day 4.
mass.m_kg  = NaN;
mass.Ixx   = NaN;
mass.Iyy   = NaN;
mass.Izz   = NaN;
mass.Ixz   = NaN;
mass.cg_m  = [0; 0; 0];

end
