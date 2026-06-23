# Longitudinal Modal Validation Report

source_id=DATCOM_CANDIDATE_LONGITUDINAL_MODAL_VALIDATION_V0
trim_source_id=DATCOM_CANDIDATE_LONGITUDINAL_TRIM_VALIDATION_V0
crm_source_id=NASA_CRM_NTF197_TWICS_CLEAN_GRID
derivative_source_id=DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0
control_source_id=DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0
case_count=3
mode_pair_count=6
pass_count=6
fail_count=0
case_table=data/aerodynamics/validation/longitudinal_modal_validation_cases.csv

## Scope

This validation covers restricted clean-cruise longitudinal modes for
the DATCOM candidate aerodynamic path. The state vector is
`[u, w, q, theta]`, the controls are held at their trim values and
thrust is held at the static-equivalent trim value. The linear model
uses CRM clean `CL`, `CD` and `Cm`, DATCOM candidate `CL_q` and
`Cm_q`, and DATCOM elevator candidates.

This is not yet a full six-degree-of-freedom modal validation. It does
not include engine pitching moments, actuator dynamics, lateral-
directional modes or coupled propulsion states.

## Results

| Case | Mode | real 1/s | imag rad/s | wn rad/s | zeta | period s | status |
|---|---|---:|---:|---:|---:|---:|---|
| clean_cruise_m070 | phugoid | -0.001215 | 0.063877 | 0.063889 | 0.01902 | 98.36 | pass |
| clean_cruise_m070 | short_period | -0.363103 | 0.542395 | 0.652714 | 0.55630 | 11.58 | pass |
| clean_cruise_m075 | phugoid | -0.001819 | 0.066786 | 0.066811 | 0.02722 | 94.08 | pass |
| clean_cruise_m075 | short_period | -0.425626 | 0.758044 | 0.869361 | 0.48959 | 8.29 | pass |
| clean_cruise_m080 | phugoid | -0.001723 | 0.064601 | 0.064624 | 0.02666 | 97.26 | pass |
| clean_cruise_m080 | short_period | -0.479470 | 0.896631 | 1.016779 | 0.47156 | 7.01 | pass |

## Acceptance Criteria

- Each trim case must produce two stable oscillatory longitudinal mode pairs.
- Phugoid natural frequency must be between 0.02 and 0.12 rad/s.
- Phugoid damping ratio must be between 0.005 and 0.20.
- Phugoid period must be between 50 s and 200 s.
- Short-period natural frequency must be between 0.40 and 1.40 rad/s.
- Short-period damping ratio must be between 0.20 and 0.90.
- Short-period period must be between 4 s and 16 s.
- Linearisation residual norm at the trim point must be below 1e-6.

## Promotion Marker Recommendation

DATCOM_PROMOTION_MODAL_VALIDATED=true
