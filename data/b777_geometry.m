function geom = b777_geometry()
%B777_GEOMETRY Public-data-based approximate geometry of a B777-like aircraft.
%
% Output:
%   geom - structure with geometric parameters in SI units.
%

geom = struct();

% Wing geometry
geom.S_ref_m2      = NaN;  % reference wing area [m^2]
geom.b_ref_m       = NaN;  % wing span [m]
geom.c_bar_m       = NaN;  % mean aerodynamic chord [m]
geom.AR            = NaN;  % aspect ratio [-]

% Aircraft dimensions
geom.length_m      = NaN;
geom.height_m      = NaN;

% Engine / control geometry
geom.engine_y_m    = NaN;  % lateral distance of one engine from centerline [m]
geom.engine_z_m    = NaN;  % vertical distance from CG, sign according to body axes [m]

end
