# B777 NMPC Flight Simulator

Nonlinear flight dynamics simulator for a Boeing 777-like aircraft and Nonlinear Model Predictive Control in MATLAB/Simulink.

## Structure

- `data/` - geometry, mass, inertia, atmosphere, aerodynamic database, actuator, thrust and flight configurations.
- `plant/` - nonlinear 6DOF plant adapters.
- `nmpc/` - state definitions, outputs, cost functions and constraints for NMPC.
- `guidance/` - MCP, mode manager, LNAV/VNAV/ILS and reference generators.
- `validation/` - trimming, simulation and autopilot tests.
- `models/` - Simulink `.slx` models.
- `plots/` - output graphs.
- `docs/` - engineering documentation and thesis sources.
- `tests/` - feature-oriented MATLAB checks for project structure, data, aerodynamics, engine loads and actuator dynamics.
- `tools/` - Python and shell helpers for DATCOM extraction, validation and reports.

## Thesis PDF

The main thesis PDF is published in the repository root as:

```text
B777_NMPC_Flight_Simulator.pdf
```

Build it from the repository root with:

```sh
make thesis
```

## Quick Check

In MATLAB:

```matlab
startup
results = run_feature_tests();
```

`tests/features/test_aerodynamic_database.m` validates the staged aerodynamic database, the NASA CRM
NTF197/TWICS clean-cruise Mach-alpha grid, the retained `Mach = 0.85` CFD
cross-check loader, the DATCOM-ready residual derivative table, the
CRM-HL/DATCOM-ready high-lift table, and the aerodynamic force/moment adapter
used by the plant.

`tests/features/test_engine_loads.m` validates the initial GE90-115B-like
propulsion seed: static thrust consistency with the geometry module,
altitude/Mach thrust lapse, idle-to-maximum throttle mapping, first-order
spool derivatives and body-axis force/moment signs for symmetric and
asymmetric thrust.

`tests/features/test_actuator_dynamics.m` validates the first control-surface
actuator seed: elevator, effective aileron and rudder position limits, rate
limits, first-order response signs and the current-deflection control output
used by the aerodynamic database.

The first reproducible Digital DATCOM run package is documented in
`docs/datcom_workflow.md`. It now includes a five-point Mach-grid runner that
parses each `datcom.out` automatically into a source-backed derivative
candidate CSV and consolidates the grid into a Mach-dependent candidate table.
It also includes a control-grid runner for elevator and aileron derivatives,
plus a derived gap-fill table for the active-interface terms not printed
directly by DATCOM (`CD_beta`, `CY_r`, rudder derivatives and lateral control
drag). Clean-cruise longitudinal trim validation and restricted longitudinal
modal validation for the DATCOM candidate path are now recorded in
`docs/trim_validation_report.md` and
`docs/longitudinal_modal_validation_report.md`. The active plant still uses the
reviewed seed derivative table until the DATCOM warning review is complete.

Digital DATCOM run folders under `data/aerodynamics/raw/datcom/runs/` are
generated artifacts. They are ignored by Git and can be recreated with the
scripts in `tools/`.
