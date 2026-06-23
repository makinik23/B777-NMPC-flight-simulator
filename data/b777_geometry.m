function geom = b777_geometry()
%B777_GEOMETRY Return reference geometry for a B777-300ER-like aircraft.
%
% The values in this file are intended for an educational nonlinear
% flight-dynamics simulator. Publicly available values are used where
% possible. Parameters that are not normally published are explicitly marked
% as estimates so they can be refined later during trim and validation.

geom = struct();

geom.name = 'B777-300ER-like';
geom.variant = 'Boeing 777-300ER reference configuration';
geom.data_status = 'public reference data plus first-cut engineering estimates';
geom.units.length = 'm';
geom.units.area = 'm^2';
geom.units.angle = 'deg';
geom.units.force = 'N';

geom.sources = { ...
    'Boeing 777 technical specs and design highlights: https://www.boeing.com/commercial/777', ...
    'Boeing Airport Planning Manuals index: https://www.boeing.com/commercial/airports/plan-manuals', ...
    'GE Aerospace GE90-115B public thrust information: https://www.geaerospace.com/news/press-releases/commercial-engines/ge90-115b-ges-best-ever-new-jet-engine-entry-airline-service', ...
    'Civil Jet Aircraft Design public aircraft data file, used only for secondary geometric estimates: https://booksite.elsevier.com/9780340741528/appendices/data-a/table-4/table.htm' ...
};

geom.fuselage.length_m = 73.90;
geom.fuselage.width_m = 6.20;
geom.fuselage.height_m = 6.20;
geom.fuselage.fineness_ratio = geom.fuselage.length_m / geom.fuselage.width_m;

geom.aircraft.overall_height_m = 18.50;

geom.wing.span_m = 64.80;
geom.wing.area_m2 = 436.80;
geom.wing.aspect_ratio = geom.wing.span_m^2 / geom.wing.area_m2;
geom.wing.geometric_mean_chord_m = geom.wing.area_m2 / geom.wing.span_m;

% MAC is kept separate from S/b. The value below is a practical B777-300ER
% weight-and-balance style reference length, converted from 278.5 in.
geom.wing.mean_aerodynamic_chord_m = 278.5 * 0.0254;
geom.wing.mean_aerodynamic_chord_source = ...
    'public B777-300ER weight-and-balance manual mirror; update if operator-specific data is used';
geom.wing.quarter_chord_sweep_deg = 31.60;
geom.wing.taper_ratio_estimate = 0.149;

geom.horizontal_tail.area_m2 = 101.26;
geom.horizontal_tail.span_m = 21.35;
geom.horizontal_tail.aspect_ratio = 4.50;
geom.horizontal_tail.taper_ratio = 0.300;
geom.horizontal_tail.quarter_chord_sweep_deg = 35.00;
geom.horizontal_tail.tail_arm_m = 32.95;

geom.vertical_tail.area_m2 = 53.23;
geom.vertical_tail.height_m = 9.24;
geom.vertical_tail.aspect_ratio = 1.60;
geom.vertical_tail.taper_ratio = 0.290;
geom.vertical_tail.quarter_chord_sweep_deg = 46.00;
geom.vertical_tail.tail_arm_m = 31.65;

geom.engine.count = 2;
geom.engine.model = 'GE90-115B';
geom.engine.max_static_thrust_per_engine_N = 512e3;
geom.engine.max_static_thrust_total_N = ...
    geom.engine.count * geom.engine.max_static_thrust_per_engine_N;

% First-cut engine placement for differential-thrust moments. The simulator
% body frame origin is the center of gravity, x forward, y right, z down.
geom.engine.y_arm_m = 0.326 * (geom.wing.span_m / 2);
geom.engine.x_location_m_estimate = 8.0;
geom.engine.z_location_m_estimate = 1.5;
geom.engine.left_position_body_m = [ ...
    geom.engine.x_location_m_estimate; ...
   -geom.engine.y_arm_m; ...
    geom.engine.z_location_m_estimate ...
];
geom.engine.right_position_body_m = [ ...
    geom.engine.x_location_m_estimate; ...
    geom.engine.y_arm_m; ...
    geom.engine.z_location_m_estimate ...
];

geom.reference.cg_body_m = [0.0; 0.0; 0.0];
geom.reference.aero_reference_point_body_m = [0.0; 0.0; 0.0];

geom.notes = { ...
    'Use wing.mean_aerodynamic_chord_m for moment coefficient scaling.', ...
    'Use wing.geometric_mean_chord_m only when a simple S/b chord is needed.', ...
    'Tail and engine-location values are initial estimates and should be revisited after trim validation.', ...
    'This dataset is B777-like and is not a certified Boeing 777 simulation dataset.' ...
};
end
