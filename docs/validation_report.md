# Validation report

This file records validation evidence used by promotion gates.

Planned validation stages:

1. Geometry and mass feature checks.
2. Trim validation.
3. Open-loop dynamic modes.
4. Closed-loop PID baseline.
5. Longitudinal NMPC tests.
6. Lateral NMPC tests.
7. Full mission scenario.

## DATCOM Promotion Markers

The current DATCOM Mach-grid derivative table is not promoted to the active
plant model because the warning review remains open.

```text
DATCOM_PROMOTION_TRIM_VALIDATED=true
DATCOM_PROMOTION_MODAL_VALIDATED=true
```

These markers may be changed to `true` only after the corresponding validation
evidence has been added to this report.

## Trim Validation Evidence

Trim validation evidence is stored in `docs/trim_validation_report.md`, with
the detailed case table in `data/aerodynamics/validation/trim_validation_cases.csv`.

The current trim validation scope is clean-cruise longitudinal trim for the
DATCOM candidate aerodynamic path. The clean baseline is the NASA CRM NTF197
TWICS Mach-alpha table, and elevator lift, pitching-moment and drag increments
come from the Digital DATCOM control-grid candidate table.

Summary:

- `source_id=DATCOM_CANDIDATE_LONGITUDINAL_TRIM_VALIDATION_V0`
- `case_count=3`
- `pass_count=3`
- `fail_count=0`
- validated Mach points: `0.70010`, `0.75015`, `0.80000`

This evidence does not cover full six-degree-of-freedom trim with engine
pitching moments, actuator states or lateral-directional modal checks. Those
items remain part of the modal and plant-integration validation work.

## Longitudinal Modal Validation Evidence

Longitudinal modal validation evidence is stored in
`docs/longitudinal_modal_validation_report.md`, with the detailed mode table
in `data/aerodynamics/validation/longitudinal_modal_validation_cases.csv`.

The current modal validation scope is restricted clean-cruise longitudinal
linearisation for the same three DATCOM candidate trim cases. The state vector
is `[u, w, q, theta]`, thrust and elevator are held at their trim values, and
the aerodynamic model uses the NASA CRM clean table with Digital DATCOM
candidate `CL_q`, `Cm_q` and elevator derivatives.

Summary:

- `source_id=DATCOM_CANDIDATE_LONGITUDINAL_MODAL_VALIDATION_V0`
- `case_count=3`
- `mode_pair_count=6`
- `pass_count=6`
- `fail_count=0`
- validated modes: phugoid and short-period

This evidence does not cover lateral-directional modes, actuator dynamics,
engine pitching moments or full six-degree-of-freedom coupled linearisation.
Those items remain part of the plant-integration validation work.
