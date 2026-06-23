function tableData = b777_aero_clean_crm_seed()
%B777_AERO_CLEAN_CRM_SEED Return the NASA CRM clean aerodynamic grid.
%
% This table is a public NASA CRM source-data grid for the clean-cruise
% aerodynamic database. It is not a proprietary B777 table. The grid uses
% NTF Test 197 TWICS-corrected wall-corrected force and moment data for
% configuration code CONFIG=3, CONFTS=1, CONFT=0, curated onto a common
% alpha grid for deterministic MATLAB interpolation.

dataDir = fileparts(mfilename('fullpath'));
rawFile = fullfile(dataDir, 'raw', 'nasa_crm', ...
    'NTF197_TWICS_clean_grid.csv');
raw = b777_aero_read_crm_clean_grid_csv(rawFile);
geom = b777_geometry();

tableData = struct();
tableData.id = "NASA_CRM_NTF197_TWICS_CLEAN_GRID";
tableData.parent_source_id = "NASA_CRM_CLEAN";
tableData.status = "implemented-multi-mach-clean-baseline";
tableData.confidence = 0.65;
tableData.role = ...
    "clean longitudinal CL/CD/Cm baseline over the initial cruise Mach grid";

tableData.source.title = ...
    "NASA CRM NTF Test 197 TWICS-corrected clean force and moment grid";
tableData.source.kind = "NASA-published wind-tunnel data, curated grid";
tableData.source.url = ...
    "https://commonresearchmodel.larc.nasa.gov/wp-content/uploads/sites/7/2017/06/NTF197Data.zip";
tableData.source.local_raw_file = ...
    "data/aerodynamics/raw/nasa_crm/NTF197_TWICS_clean_grid.csv";
tableData.source.source_archive_member = "TWICSCorr/t197R*.csv";
tableData.source.run_ids = raw.run_id_by_Mach;
tableData.source.configuration_code = "CONFIG=3, CONFTS=1, CONFT=0";
tableData.source.notes = ...
    "Grid values are linearly interpolated from selected TWICS-corrected NTF197 runs onto alpha=-2:1:9 deg.";

tableData.geometry.name = "NASA CRM NTF Test 197 model";
tableData.geometry.configuration = ...
    "CRM clean cruise candidate identified by CONFIG=3, CONFTS=1, CONFT=0";
tableData.reference.S_m2 = geom.wing.area_m2;
tableData.reference.b_m = geom.wing.span_m;
tableData.reference.c_m = geom.wing.mean_aerodynamic_chord_m;
tableData.reference.moment_reference_point_body_m = ...
    geom.reference.aero_reference_point_body_m;
tableData.reference_state.Mach = raw.Mach;
tableData.reference_state.Re_million = raw.Re_million_by_Mach;
tableData.reference_state.beta_rad = 0.0;
tableData.reference_state.control_deflection_rad = 0.0;
tableData.reference_state.rate_radps = 0.0;

tableData.validity.Mach = [min(raw.Mach), max(raw.Mach)];
tableData.validity.alpha_rad = [min(raw.alpha_rad), max(raw.alpha_rad)];
tableData.validity.beta_rad = deg2rad_local([-1.0, 1.0]);
tableData.validity.notes = ...
    "Use as clean baseline only inside the curated NTF197 Mach-alpha grid.";

tableData.alpha_deg = raw.alpha_deg;
tableData.alpha_rad = raw.alpha_rad;
tableData.Mach = raw.Mach;
tableData.CL = raw.CL;
tableData.CD = raw.CD;
tableData.Cm = raw.Cm;

tableData.grid.status = "multi-Mach-alpha-grid";
tableData.grid.Mach = raw.Mach;
tableData.grid.alpha_deg = raw.alpha_deg;
tableData.grid.alpha_rad = raw.alpha_rad;
tableData.grid.CL = raw.CL;
tableData.grid.CD = raw.CD;
tableData.grid.Cm = raw.Cm;
tableData.grid.Re_million_by_Mach = raw.Re_million_by_Mach;
tableData.grid.run_id_by_Mach = raw.run_id_by_Mach;
tableData.grid.notes = ...
    "Rows are alpha stations and columns are Mach stations.";

tableData.interpolation.method = "linear in Mach and alpha";
tableData.interpolation.extrapolation = ...
    "disabled; database falls back to analytical seed";
tableData.cg_shift_status = "unshifted-crm-reference";
tableData.cg_shift_policy = ...
    "plant adapter shifts moments from the configured aero reference point to CG";

validate_table(tableData);
end

function validate_table(tableData)
nAlpha = numel(tableData.alpha_rad);
nMach = numel(tableData.Mach);
assert(size(tableData.CL, 1) == nAlpha, 'CL grid row count mismatch.');
assert(size(tableData.CL, 2) == nMach, 'CL grid column count mismatch.');
assert(size(tableData.CD, 1) == nAlpha, 'CD grid row count mismatch.');
assert(size(tableData.CD, 2) == nMach, 'CD grid column count mismatch.');
assert(size(tableData.Cm, 1) == nAlpha, 'Cm grid row count mismatch.');
assert(size(tableData.Cm, 2) == nMach, 'Cm grid column count mismatch.');
assert(all(diff(tableData.alpha_rad) > 0.0), ...
    'Angle-of-attack samples must be strictly increasing.');
assert(all(diff(tableData.Mach) > 0.0), ...
    'Mach samples must be strictly increasing.');
assert(all(tableData.CD(:) > 0.0), 'Drag coefficients must be positive.');
end

function rad = deg2rad_local(deg)
rad = deg * pi / 180.0;
end
