# B777-Like Digital DATCOM Mach Grid

This folder contains single-Mach Digital DATCOM input decks for the clean
B777-like static and damping derivative screen. Each deck keeps the same
geometry, reference dimensions and angle-of-attack schedule as the initial
`Mach = 0.60` case, but changes the Mach number and Reynolds number per metre.

The Reynolds number per metre values are scaled from the initial cruise
reference condition:

```text
Re_per_m(M) = 4.7115E6 * M / 0.60
```

The decks are intended to be run independently because the legacy Digital
DATCOM damping path has been more robust for one-flight-condition runs than for
multi-Mach damping cases.

After `tools/run_datcom_mach_grid.sh` is executed, this folder also contains
one candidate derivative CSV per Mach point and one consolidated candidate
table:

```text
b777_like_derivative_datcom_candidate_mach_grid.csv
```

The consolidated table uses the source id
`DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0`, keeps each per-run source id
as `case_source_id`, and remains marked `candidate-pending-review`. Its
interpolation policy is linear interpolation in Mach inside the committed grid
only, with no extrapolation before validation.

The promotion-gate artifacts are:

```text
b777_like_derivative_datcom_promotion_gates.csv
b777_like_derivative_datcom_promotion_gates.txt
```

The expected current result is `promotion_allowed=false`. The candidate table
passes traceability, run-quality, Mach-grid, row-count, status, interpolation
policy, sign and confidence checks. When the control-grid candidate table and
the derived gap-fill table exist, the promotion evaluator includes them in the
active-interface coverage check. Active-table coverage and control-derivative
coverage then pass, and the clean-cruise longitudinal trim and restricted
longitudinal modal markers are now present. Promotion remains blocked by the
documented warning-review item.
