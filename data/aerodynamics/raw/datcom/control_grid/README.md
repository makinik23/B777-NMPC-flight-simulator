# B777-Like Digital DATCOM Control Grid

This folder contains generated single-Mach Digital DATCOM input decks for the
current B777-like control-effectiveness screen.

The deck generator is:

```text
tools/generate_datcom_control_grid.py
```

The runner is:

```text
tools/run_datcom_control_grid.sh
```

It runs elevator and aileron control cases at:

```text
Mach = 0.30, 0.50, 0.60, 0.70, 0.80
```

The Reynolds number per metre follows the same scaling used by the clean
static/damping Mach grid:

```text
Re_per_m(M) = 4.7115E6 * M / 0.60
```

## Extracted Candidates

The elevator cases use the Digital DATCOM `SYMFLP` path and extract:

```text
CL_delta_e
Cm_delta_e
CD_delta_e
```

The aileron cases use the Digital DATCOM `ASYFLP` path and extract:

```text
CY_delta_a
Cl_delta_a
Cn_delta_a
```

`CY_delta_a` is currently a symmetry assumption because the `ASYFLP` output does
not print a side-force derivative for this case.

The consolidated table is:

```text
b777_like_control_derivative_datcom_candidate_mach_grid.csv
```

The report is:

```text
b777_like_control_derivative_datcom_candidate_mach_grid_report.txt
```

## Direct DATCOM Gaps

The current control DATCOM path does not yet produce:

```text
CD_delta_a
CD_delta_r
CY_delta_r
Cl_delta_r
Cn_delta_r
```

These rows are not added to the direct control-grid table. They are covered by
the separate derived gap-fill table under `data/aerodynamics/raw/datcom/derived_gap_fill`,
which records the formulas and keeps the lower-confidence values distinct from
direct DATCOM printouts.
