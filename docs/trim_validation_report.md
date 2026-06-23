# Trim Validation Report

source_id=DATCOM_CANDIDATE_LONGITUDINAL_TRIM_VALIDATION_V0
crm_source_id=NASA_CRM_NTF197_TWICS_CLEAN_GRID
control_source_id=DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0
case_count=3
pass_count=3
fail_count=0
case_table=data/aerodynamics/validation/trim_validation_cases.csv

## Scope

This validation covers clean-cruise longitudinal trim for the DATCOM
candidate aerodynamic path. The clean baseline is the NASA CRM NTF197
TWICS Mach-alpha table. Elevator lift, pitching-moment and drag
increments are taken from the Digital DATCOM control-grid candidate
table. The trim solve enforces vertical force balance, zero pitching
moment coefficient and positive static-equivalent thrust.

This is not yet a full six-degree-of-freedom trim with engine pitching
moments, actuator states or lateral-directional modal checks.

## Results

| Case | Mach | alpha deg | delta_e deg | CL | CD | thrust N | throttle static equiv | status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| clean_cruise_m070 | 0.7001 | 5.58145413 | -0.53146074 | 0.68223554 | 0.03994532 | 143409.6108 | 0.14004845 | pass |
| clean_cruise_m075 | 0.7501 | 4.40347722 | 0.15502381 | 0.59519818 | 0.03164617 | 130205.5950 | 0.12715390 | pass |
| clean_cruise_m080 | 0.8000 | 3.49573101 | 0.93234763 | 0.52381604 | 0.02716336 | 126969.8472 | 0.12399399 | pass |

## Acceptance Criteria

- Angle of attack must remain inside the clean CRM table range and below 8 deg.
- Elevator trim must remain within +/-5 deg.
- Static-equivalent thrust must be positive and below 30% of the public GE90-115B static thrust estimate.
- Vertical and axial residuals must be numerically negligible.
- Pitching-moment coefficient residual must be near zero.
- Clean lift-coefficient margin to the current CLmax estimate must be at least 0.40.

## Promotion Marker Recommendation

DATCOM_PROMOTION_TRIM_VALIDATED=true
