# Aerodynamic Database Development Plan

## Objective

Build a credible B777-300ER-like aerodynamic database for control-oriented
simulation. The objective is not to reproduce proprietary Boeing aerodynamics,
but to create a traceable large-transport model whose coefficients are based on
public reference data, semi-empirical methods, selected CFD checks and final
flight-dynamics validation.

## Target Model Interface

The plant should eventually obtain coefficients from a single database-style
interface:

```matlab
aero = b777_aero_database();
coeff = aero.coeff(state, control, config);
```

The long-term coefficient set is:

```text
CX, CY, CZ, Cl, Cm, Cn
```

The current transition layer also exposes:

```text
CL, CD, CY, Cl, Cm, Cn
```

## Source Hierarchy

| Layer | Source | Role | Status |
|---|---|---|---|
| Geometry and mass | Boeing public data and project estimates | B777-300ER-like scaling, reference area, span, MAC, mass | Implemented |
| Clean cruise baseline | NASA Common Research Model | Transonic transport clean CL/CD/Cm trends | Implemented: NTF197/TWICS Mach-alpha grid; M=0.85 CFD retained as cross-check |
| Missing derivatives | USAF DATCOM / Digital DATCOM | Static, control and damping derivative gaps | DATCOM-ready seed table active; static/damping Mach-grid, elevator/aileron control-grid and derived gap-fill candidates available but not promoted |
| High-lift increments | NASA CRM-HL and DATCOM | Approach and landing flap/slat/gear increments | CRM-HL/DATCOM-ready seed table active; validated data pending |
| Operational performance | OpenAP and possibly EUROCONTROL BADA | Drag/thrust/performance plausibility checks | Planned |
| CFD spot checks | OpenFOAM | Selected validation points after CRM setup is reproduced | Planned later |

## Development Stages

1. Freeze the database interface and source inventory.
2. Keep the current analytical model as a low-confidence seed model.
3. Ingest the first NASA CRM clean force and moment source table.
4. Expose the aerodynamic force/moment adapter for the nonlinear plant.
5. Shift aerodynamic moments from the configured reference point to the current CG.
6. Expose seed control, static and dynamic derivatives as replaceable data.
7. Expose seed approach and landing high-lift increments as replaceable data.
8. Expand NASA CRM clean tables over Reynolds number and configuration.
9. Convert CRM data to the project coefficient convention.
10. Fill derivative gaps using DATCOM.
11. Add CRM-HL and DATCOM high-lift increments.
12. Tune only physically meaningful parameters using trim and modal validation.
13. Run selected OpenFOAM cases after reproducing CRM benchmark cases.

## Implemented Clean Cruise Grid

The active clean-cruise table is `NASA_CRM_NTF197_TWICS_CLEAN_GRID`, exposed
through `data/aerodynamics/b777_aero_clean_crm_seed.m` with the curated CSV stored under
`data/aerodynamics/raw/nasa_crm/NTF197_TWICS_clean_grid.csv`. The helper
`data/aerodynamics/b777_aero_read_crm_clean_grid_csv.m` reads the curated Mach-alpha grid
and returns coefficient matrices arranged as angle-of-attack rows and Mach
columns.

The grid is built from NASA CRM NTF Test 197 TWICS-corrected, wall-corrected
force and moment data for the selected clean candidate identified in the source
files by `CONFIG=3`, `CONFTS=1`, `CONFT=0`. The current implementation covers
`Mach = 0.70` to `0.87` and `alpha = -2 deg` to `9 deg`, and provides the
clean longitudinal baseline for `CL`, `CD` and `Cm` using linear interpolation
in Mach and angle of attack. Dynamic derivatives, control increments,
lateral-directional coefficients and out-of-range states still fall back to the
analytical seed model.

The earlier NASA-published USM3D CRM WBT0 original-geometry CFD table at
`Mach = 0.85` remains mirrored under
`data/aerodynamics/raw/nasa_crm/NASA_wbt0_M85_CFD_orig.csv` and is kept as an independent
loader cross-check rather than blended into the active baseline.

## DATCOM-Ready Derivative Layer

The active residual derivative table is
`DATCOM_DERIVATIVE_SEED_B777_LIKE_V0`, stored in
`data/aerodynamics/raw/datcom/b777_like_derivative_seed.csv` and read by
`data/aerodynamics/b777_aero_read_derivative_csv.m`. It currently contains low-confidence
engineering seed values, but its schema is deliberately source-oriented:
source identifier, derivative group, coefficient name, basis variable, value,
units, status, confidence and notes.

When the clean CRM grid is valid, the database now computes the clean
quasi-static `CL`, `CD` and `Cm` from the CRM table and adds residual terms from
this derivative table:

- sideslip residuals for `CY`, `Cl`, `Cn` and the sideslip drag increment,
- nondimensional rate residuals for pitch, roll and yaw damping,
- control residuals for elevator, aileron and rudder effectiveness,
- squared control-deflection drag increments.

This makes the DATCOM replacement path explicit. The reproducible Digital
DATCOM run package is stored under `data/aerodynamics/raw/datcom/`. The single-run helper
`tools/run_digital_datcom.sh` executes one committed input deck and calls
`tools/extract_datcom_derivatives.py`, which parses the first static and
dynamic derivative tables, converts `per degree` outputs to `per rad`, and
writes the source-oriented candidate CSV.

The Mach-grid workflow is driven by `tools/run_datcom_mach_grid.sh`. The
committed decks in `data/aerodynamics/raw/datcom/mach_grid/` cover
`Mach = 0.30, 0.50, 0.60, 0.70, 0.80` as independent single-condition runs.
Each run writes reproducible output under `data/aerodynamics/raw/datcom/runs/`.
That directory is treated as generated workspace output and is ignored by Git.
The grid-level run index is
`data/aerodynamics/raw/datcom/mach_grid/b777_like_datcom_mach_grid_run_index.csv`.

The extracted source-backed candidate derivatives are first stored as one CSV
per Mach point under `data/aerodynamics/raw/datcom/mach_grid/`. The consolidation helper
`tools/build_datcom_mach_grid_table.py` then builds
`data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_candidate_mach_grid.csv`,
which has the grid-level source id
`DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0` while retaining each per-run
source id as `case_source_id`. The companion MATLAB reader
`data/aerodynamics/b777_aero_read_mach_derivative_csv.m` reads this candidate table and
checks the Mach grid, status, interpolation policy and physically expected
signs. The interpolation policy is linear in Mach inside the committed grid
only; no extrapolation is allowed before validation.

The consolidated candidates are not yet active in the plant-facing database
because the documented warning review remains open. The clean-cruise
longitudinal trim gate and restricted longitudinal modal gate have passed for
the DATCOM candidate path. The companion
control workflow is driven by `tools/run_datcom_control_grid.sh`. It generates and runs elevator
`SYMFLP` and aileron `ASYFLP` decks at the same five Mach stations, parses the
control output with `tools/extract_datcom_control_derivatives.py`, and
consolidates the result into
`data/aerodynamics/raw/datcom/control_grid/b777_like_control_derivative_datcom_candidate_mach_grid.csv`.
This table currently supplies `CL_delta_e`, `Cm_delta_e`, `CD_delta_e`,
`CY_delta_a`, `Cl_delta_a` and `Cn_delta_a`. The remaining control gaps are
`CD_delta_a`, `CD_delta_r`, `CY_delta_r`, `Cl_delta_r` and `Cn_delta_r` in the
direct control-grid report. They are now covered as low-confidence derived
gap-fill candidates, together with `CD_beta` and `CY_r`, by
`tools/build_datcom_gap_fill_candidates.py`. The resulting table is
`data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid.csv`
with source id `DIGITAL_DATCOM_B777_LIKE_DERIVED_GAP_FILL_CANDIDATE_V0`. A
later promotion step should merge all accepted direct and derived values into
an active derivative table and update the table metadata; the plant-facing
database interface should not need to change.

The current promotion decision is generated by
`tools/evaluate_datcom_promotion_gates.py`. The report is stored in
`data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_promotion_gates.txt`.
At this stage the expected decision is `promotion_allowed=false`. Passing data
quality gates are recorded, and active-table coverage now passes when the
control-grid and derived gap-fill tables are present. Promotion remains blocked
by the documented warning-review item; the trim-validation and longitudinal
modal-validation markers are present. The gate reads the optional control-grid and supplemental candidate
tables when present, so the report distinguishes direct DATCOM values from
derived gap-fill coverage and prevents silent fallback to seed values.

## CRM-HL/DATCOM-Ready High-Lift Layer

The active high-lift increment table is
`CRMHL_DATCOM_HIGH_LIFT_SEED_B777_LIKE_V0`, stored in
`data/aerodynamics/raw/high_lift/b777_like_high_lift_seed.csv` and read by
`data/aerodynamics/b777_aero_read_high_lift_csv.m`. It currently contains clean, approach
and landing configurations with explicit source identifiers, status,
confidence, flap angle, slat state, landing-gear state, lift/drag/moment
increments, induced-drag increment, `CLmax` estimate and an angle-of-attack
validity range.

The database applies this layer after the clean baseline and derivative
residuals. The clean configuration carries zero high-lift increments. The
approach and landing configurations add `delta_CL0`, `delta_CD0`,
`delta_Cm0`, and an additional induced-drag term based on the increase in lift
coefficient. The `CLmax` estimate is exposed as metadata for trim and
validation logic; it is not yet used as a hard stall model. Future CRM-HL or
DATCOM-derived values should replace the high-lift CSV without changing the
plant-facing coefficient interface.

## Plant-Ready Adapter

The plant-facing adapter is `plant/b777_aero_forces_moments.m`. It converts
database coefficients into body-axis aerodynamic force and moment vectors using
dynamic pressure, the project reference area/span/chord and the body-frame
convention. The adapter also shifts aerodynamic moments from the configured
aerodynamic reference point to the current CG:

```text
M_cg = M_ref + r_ref_to_cg x F_body
```

This makes the database usable by the nonlinear 6-DOF plant while preserving a
clear replacement point for better moment-reference data.

## Seed Derivative and High-Lift Layers

`data/aerodynamics/b777_aero_derivative_seed.m` exposes the DATCOM-ready static, control and
dynamic residual derivatives as a low-confidence data table. The table keeps
important signs explicit, such as negative `Cm_delta_e`, positive
`Cl_delta_a`, positive `Cn_delta_r`, and negative damping derivatives.

`data/aerodynamics/b777_aero_high_lift_seed.m` exposes clean, approach and landing
configuration increments from the CRM-HL/DATCOM-ready high-lift CSV. These
values are sufficient for initial trim and plant integration, but they remain
marked as seed data until replaced by CRM-HL or DATCOM-derived increments.

## Required Metadata for Every Table

Every coefficient table should store:

- source identifier,
- configuration,
- Mach range,
- angle-of-attack range,
- sideslip range,
- Reynolds number or reference condition,
- reference area, span and chord,
- moment reference point,
- CG shift policy,
- confidence level,
- tuning status.

## Validation Gates

The aerodynamic database should pass these gates before being used for NMPC:

1. Clean cruise trim at representative B777-like mass.
2. Required lift coefficient consistency: `CL = W / (q S)`.
3. Drag polar consistency against expected transport-aircraft performance.
4. Elevator trim schedule consistency.
5. Short-period and phugoid modal checks.
6. Dutch-roll, roll-mode and spiral-mode checks.
7. Approach trim with high-lift increments.
8. Control step-response feature checks.

## OpenFOAM Policy

OpenFOAM should not be used as the first source for the whole aerodynamic
database. It should first reproduce selected CRM benchmark conditions. After that
it can be used for B777-like spot checks such as nacelle/pylon effects, selected
tail/elevator cases and a small number of cruise/high-lift validation points.
