# Digital DATCOM Workflow

This project uses Digital DATCOM only as a documented semi-empirical
replacement path for missing residual derivatives. The active simulator still
uses the low-confidence table in
`data/aerodynamics/raw/datcom/b777_like_derivative_seed.csv` until a DATCOM run has passed
the quality gates below and the extracted coefficients have been reviewed.

## Source

- Official program page: https://www.pdas.com/datcom.html
- Official program description: https://www.pdas.com/datcomDescription.html
- Official download page: https://www.pdas.com/datcomdownload.html
- Official reference page: https://www.pdas.com/datcomrefs.html

The PDAS download page states that `datcom.zip` contains `datcom.f`,
`namelist.pdf`, sample cases and expected outputs. The same page gives the
legacy Fortran build command:

```sh
gfortran -std=legacy datcom.f -o datcom.exe
```

## Project Input Decks

The first project deck remains available for a single `Mach = 0.60` smoke run:

```text
data/aerodynamics/raw/datcom/b777_like_digital_datcom_static_damping.inp
```

It is a clean B777-300ER-like geometry screen at `Mach = 0.60`, not a
certified Boeing data file. The deck uses SI units, the current project wing
reference area, span and mean aerodynamic chord, and first-cut fuselage, wing,
horizontal-tail and vertical-tail geometry derived from `data/b777_geometry.m`.

The committed Mach-grid decks are stored in:

```text
data/aerodynamics/raw/datcom/mach_grid/
```

They cover `Mach = 0.30, 0.50, 0.60, 0.70, 0.80`. Each deck intentionally
supports only a single-Mach clean static and damping derivative screening run.
The decks should not be used to replace the NASA CRM clean `CL`, `CD` and
`Cm` grid. Their intended use is to replace residual lateral-directional,
damping and control derivative seed values after review. The legacy Digital
DATCOM damping path is more robust in one-flight-condition runs than in a
single multi-Mach damping case, so the project keeps each Mach point as a
separate traceable input deck.

## Running

Run from the repository root:

```sh
tools/run_digital_datcom.sh
```

The script downloads `datcom.zip` from PDAS into `.cache/datcom`, compiles the
program with `gfortran -std=legacy`, runs the project input deck, extracts the
selected residual derivatives and writes the output to:

```text
data/aerodynamics/raw/datcom/runs/b777_like_static_damping_v0/
```

The `runs/` directory is generated workspace output and is ignored by Git. The
committed inputs, candidate CSV files and reports remain outside that folder.

The automatic extractor is:

```text
tools/extract_datcom_derivatives.py
```

It reads the first static and dynamic derivative tables in `datcom.out`,
converts DATCOM `per degree` derivatives to `per rad`, writes the candidate
CSV and records skipped or non-promotable cells such as `NDM` in
`datcom_extraction_report.txt`.

To run the committed Mach grid, use:

```sh
tools/run_datcom_mach_grid.sh
```

This wrapper runs the five single-Mach decks, writes one candidate derivative
CSV per Mach point and records the run index in:

```text
data/aerodynamics/raw/datcom/mach_grid/b777_like_datcom_mach_grid_run_index.csv
```

It also consolidates the per-Mach candidate files into one Mach-dependent
candidate table:

```text
data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_candidate_mach_grid.csv
```

The consolidated table keeps a grid-level source id and preserves each
per-run source id as `case_source_id`. Its interpolation policy is linear
interpolation in Mach inside the committed grid only. Extrapolation is not
allowed before the required validation gates are complete.

The same wrapper evaluates the promotion gates and writes:

```text
data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_promotion_gates.txt
data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_promotion_gates.csv
```

These files are decision artifacts. They do not activate the DATCOM table.
Instead, they record whether the candidate grid is allowed to replace the
active derivative seed table.

To run the control-effectiveness grid, use:

```sh
tools/run_datcom_control_grid.sh
```

This wrapper first regenerates the committed elevator and aileron input decks
under:

```text
data/aerodynamics/raw/datcom/control_grid/
```

It then runs five elevator `SYMFLP` cases and five aileron `ASYFLP` cases at
the same Mach stations as the clean static/damping grid. The control extractor
is:

```text
tools/extract_datcom_control_derivatives.py
```

The consolidated control candidate table is:

```text
data/aerodynamics/raw/datcom/control_grid/b777_like_control_derivative_datcom_candidate_mach_grid.csv
```

The current control grid provides source-backed candidates for `CL_delta_e`,
`Cm_delta_e`, `CD_delta_e`, `CY_delta_a`, `Cl_delta_a` and `Cn_delta_a`.
`CY_delta_a` is a symmetry assumption because Digital DATCOM does not print a
side-force derivative in the current `ASYFLP` output. The remaining active
control-interface gaps are `CD_delta_a`, `CD_delta_r`, `CY_delta_r`,
`Cl_delta_r` and `Cn_delta_r`.

The active derivative interface also requires `CD_beta` and `CY_r`, which are
not printed directly by the current static/damping extraction. These gaps, and
the remaining lateral control gaps, are handled by an explicit derived
gap-fill candidate table:

```text
data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid.csv
```

It is generated by `tools/build_datcom_gap_fill_candidates.py` from the
static/damping Mach-grid candidates, the control-grid candidates and the
committed B777-like geometry. The generated source id is
`DIGITAL_DATCOM_B777_LIKE_DERIVED_GAP_FILL_CANDIDATE_V0`. These rows are not
direct DATCOM printouts; they are low-confidence candidate values used to keep
the active-interface coverage check explicit. The formulas derive `CY_r` from
DATCOM `Cn_r` and the vertical-tail moment arm, estimate `CD_beta` and
`CD_delta_r` with a vertical-tail induced-drag model, derive rudder moment
coefficients from `CY_delta_r` and the same tail arms, and estimate
`CD_delta_a` from DATCOM `Cl_delta_a` and the aileron spanwise moment arm.

## Quality Gates

Before any DATCOM-derived coefficient is allowed into
`b777_like_derivative_seed.csv`, the run must satisfy these gates:

1. The input deck must be traceable to a committed file.
2. The DATCOM output must report zero input-card errors.
3. The output must be reviewed for warnings, extrapolations and method
   limitations.
4. Static derivatives must have physically plausible signs:
   `CY_beta < 0`, `Cl_beta < 0`, `Cn_beta > 0`.
5. Damping derivatives must have physically plausible signs:
   `Cl_p < 0`, `Cm_q < 0`, `Cn_r < 0`.
6. Transonic results must not override the NASA CRM clean-cruise force and
   moment grid. DATCOM transonic values are advisory unless validated against
   trim, modal and performance checks.
7. Extracted derivative values must be stored in a source-oriented CSV with
   source id, units, Mach/alpha extraction point, status, confidence and notes.
8. Mach-dependent candidate values must retain the per-run source id, record a
   grid-level interpolation policy and remain marked `candidate-pending-review`
   until promotion.
9. Promotion must be blocked unless the candidate tables cover the active
   derivative interface, including control derivatives and drag increments.
10. Promotion must be blocked until the required trim and modal validation
    markers are present in the project validation report.

## Current Status

The DATCOM path is now reproducible for the committed static/damping Mach grid,
the elevator/aileron control grid and the derived gap-fill table. The five
static/damping runs and ten control runs complete with zero input-card errors
and each direct output is parsed automatically into a candidate CSV. The
per-Mach static/damping files are consolidated into
`DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0`, the control files are
consolidated into `DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0`, and
the remaining active-interface terms are collected in
`DIGITAL_DATCOM_B777_LIKE_DERIVED_GAP_FILL_CANDIDATE_V0`. The active plant
still reads `DATCOM_DERIVATIVE_SEED_B777_LIKE_V0` until the candidate
derivatives are reviewed and validated against trim and modal checks. The
current promotion gate result is `promotion_allowed=false`; active-interface
coverage, clean-cruise longitudinal trim validation and restricted longitudinal
modal validation now pass, while warning review remains open.
