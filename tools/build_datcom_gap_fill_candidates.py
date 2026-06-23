#!/usr/bin/env python3
"""Build derived DATCOM gap-fill candidates for the active derivative interface."""

from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path


SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_DERIVED_GAP_FILL_CANDIDATE_V0"
INTERPOLATION_POLICY = (
    "linear in Mach by derived coefficient inside committed DATCOM grid; "
    "no extrapolation before validation"
)

SREF_M2 = 436.80
BLREF_M = 64.80
XCG_M = 33.26
XV_M = 64.91
VERTICAL_TAIL_AREA_M2 = 53.23
VERTICAL_TAIL_HEIGHT_M = 9.24
VERTICAL_TAIL_AR = 1.60
VERTICAL_TAIL_EFFICIENCY = 0.75
WING_AR = BLREF_M * BLREF_M / SREF_M2
WING_EFFICIENCY = 0.80

RUDDER_EFFECTIVENESS = 0.45
VERTICAL_TAIL_CP_HEIGHT_FRACTION = 0.60
AILERON_INBOARD_SPAN_M = 20.00
AILERON_OUTBOARD_SPAN_M = 29.00
AILERON_DRAG_MULTIPLIER = 2.00

COEFFICIENT_ORDER = (
    "CD_beta",
    "CY_r",
    "CD_delta_a",
    "CY_delta_r",
    "Cl_delta_r",
    "Cn_delta_r",
    "CD_delta_r",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Derive missing active-interface DATCOM candidates from the "
            "static/damping Mach grid, control grid and B777-like geometry."
        )
    )
    parser.add_argument("mach_candidate_csv", type=Path)
    parser.add_argument("control_candidate_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--source-id", default=SOURCE_ID)
    return parser.parse_args()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def rows_by_mach_and_coefficient(
    rows: list[dict[str, str]],
) -> dict[float, dict[str, dict[str, str]]]:
    by_mach: dict[float, dict[str, dict[str, str]]] = defaultdict(dict)
    for row in rows:
        mach = round(float(row["mach"]), 2)
        by_mach[mach][row["coefficient"]] = row
    return by_mach


def value(row: dict[str, str]) -> float:
    return float(row["value"])


def candidate_row(
    source_id: str,
    mach: float,
    group: str,
    coefficient: str,
    basis: str,
    value_: float,
    units: str,
    confidence: float,
    notes: str,
) -> dict[str, object]:
    return {
        "source_id": source_id,
        "mach": f"{mach:.2f}",
        "case_id": f"gap_fill_m{int(round(mach * 100.0)):03d}",
        "case_source_id": source_id,
        "group": group,
        "coefficient": coefficient,
        "basis": basis,
        "value": f"{value_:.8f}",
        "units": units,
        "status": "candidate-pending-review",
        "confidence": f"{confidence:.2f}",
        "interpolation_policy": INTERPOLATION_POLICY,
        "notes": notes,
    }


def vertical_tail_drag_from_sideforce(sideforce_slope: float) -> float:
    return (
        sideforce_slope
        * sideforce_slope
        * (SREF_M2 / VERTICAL_TAIL_AREA_M2)
        / (math.pi * VERTICAL_TAIL_EFFICIENCY * VERTICAL_TAIL_AR)
    )


def build_rows(
    mach_rows: list[dict[str, str]],
    control_rows: list[dict[str, str]],
    source_id: str,
) -> tuple[list[dict[str, object]], list[str]]:
    mach_by_coeff = rows_by_mach_and_coefficient(mach_rows)
    control_by_coeff = rows_by_mach_and_coefficient(control_rows)
    mach_grid = sorted(mach_by_coeff)

    output_rows: list[dict[str, object]] = []
    by_coefficient: dict[str, list[tuple[float, float]]] = defaultdict(list)

    tail_arm_over_b = (XV_M - XCG_M) / BLREF_M
    tail_height_over_b = (VERTICAL_TAIL_CP_HEIGHT_FRACTION * VERTICAL_TAIL_HEIGHT_M) / BLREF_M
    aileron_ybar_over_b = (
        0.5 * (AILERON_INBOARD_SPAN_M + AILERON_OUTBOARD_SPAN_M) / BLREF_M
    )

    report_lines = [
        f"source_id={source_id}",
        f"interpolation_policy={INTERPOLATION_POLICY}",
        f"mach_count={len(mach_grid)}",
        "mach_grid=" + " ".join(f"{mach:.2f}" for mach in mach_grid),
        "method=derived gap-fill candidates from Digital DATCOM static/damping/control candidates and B777-like geometry",
        f"tail_arm_over_b={tail_arm_over_b:.8f}",
        f"tail_height_over_b={tail_height_over_b:.8f}",
        f"rudder_effectiveness={RUDDER_EFFECTIVENESS:.4f}",
        f"vertical_tail_drag_model=Sref/Sv/(pi*e_v*AR_v), e_v={VERTICAL_TAIL_EFFICIENCY:.3f}",
        f"aileron_ybar_over_b={aileron_ybar_over_b:.8f}",
        f"aileron_drag_multiplier={AILERON_DRAG_MULTIPLIER:.4f}",
    ]

    for mach in mach_grid:
        required_mach = ("CY_beta", "Cn_r")
        required_control = ("Cl_delta_a",)
        missing_mach = [name for name in required_mach if name not in mach_by_coeff[mach]]
        missing_control = [name for name in required_control if name not in control_by_coeff[mach]]
        if missing_mach or missing_control:
            raise ValueError(
                f"Cannot build gap-fill candidates for Mach {mach:.2f}: "
                f"missing_mach={missing_mach} missing_control={missing_control}"
            )

        cy_beta = value(mach_by_coeff[mach]["CY_beta"])
        cn_r = value(mach_by_coeff[mach]["Cn_r"])
        cl_delta_a = value(control_by_coeff[mach]["Cl_delta_a"])

        cd_beta = vertical_tail_drag_from_sideforce(cy_beta)
        cy_r = -cn_r / tail_arm_over_b
        cy_delta_r = RUDDER_EFFECTIVENESS * abs(cy_beta)
        cl_delta_r = cy_delta_r * tail_height_over_b
        cn_delta_r = cy_delta_r * tail_arm_over_b
        cd_delta_r = vertical_tail_drag_from_sideforce(cy_delta_r)

        differential_lift_slope = abs(cl_delta_a) / aileron_ybar_over_b
        cd_delta_a = (
            AILERON_DRAG_MULTIPLIER
            * differential_lift_slope
            * differential_lift_slope
            / (math.pi * WING_EFFICIENCY * WING_AR)
        )

        rows = [
            candidate_row(
                source_id,
                mach,
                "static",
                "CD_beta",
                "beta_rad_squared",
                cd_beta,
                "1/rad^2",
                0.22,
                (
                    "Derived sideslip drag gap-fill from DATCOM CY_beta using "
                    "a vertical-tail induced-drag model; not a direct DATCOM printout."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "dynamic",
                "CY_r",
                "r_hat",
                cy_r,
                "1",
                0.25,
                (
                    "Derived yaw-rate side force from DATCOM Cn_r and the "
                    "B777-like vertical-tail moment arm; not a direct DATCOM printout."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "control",
                "CD_delta_a",
                "delta_a_rad_squared",
                cd_delta_a,
                "1/rad^2",
                0.20,
                (
                    "Derived aileron drag gap-fill from DATCOM Cl_delta_a, "
                    "aileron spanwise arm and a conservative induced/profile multiplier."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "control",
                "CY_delta_r",
                "delta_r_rad",
                cy_delta_r,
                "1/rad",
                0.22,
                (
                    "Derived rudder side-force gap-fill from DATCOM CY_beta and "
                    "a documented rudder effectiveness factor; positive command "
                    "matches the project yawing-moment convention."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "control",
                "Cl_delta_r",
                "delta_r_rad",
                cl_delta_r,
                "1/rad",
                0.20,
                (
                    "Derived rudder rolling-moment gap-fill from CY_delta_r and "
                    "the assumed vertical-tail centre-of-pressure height."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "control",
                "Cn_delta_r",
                "delta_r_rad",
                cn_delta_r,
                "1/rad",
                0.22,
                (
                    "Derived rudder yawing-moment gap-fill from CY_delta_r and "
                    "the B777-like vertical-tail moment arm."
                ),
            ),
            candidate_row(
                source_id,
                mach,
                "control",
                "CD_delta_r",
                "delta_r_rad_squared",
                cd_delta_r,
                "1/rad^2",
                0.20,
                (
                    "Derived rudder drag gap-fill from CY_delta_r using the "
                    "vertical-tail induced-drag model; not a direct DATCOM printout."
                ),
            ),
        ]
        output_rows.extend(rows)
        for row in rows:
            by_coefficient[str(row["coefficient"])].append((mach, float(row["value"])))

    output_rows.sort(
        key=lambda row: (float(row["mach"]), COEFFICIENT_ORDER.index(str(row["coefficient"])))
    )

    for coefficient in COEFFICIENT_ORDER:
        samples = sorted(by_coefficient[coefficient])
        values = [sample_value for _, sample_value in samples]
        machs = [sample_mach for sample_mach, _ in samples]
        report_lines.append(
            f"{coefficient}: count={len(samples)} "
            f"mach_min={min(machs):.2f} mach_max={max(machs):.2f} "
            f"value_min={min(values):.8f} value_max={max(values):.8f}"
        )

    report_lines.append(
        "direct_datcom_gap_note=these rows fill active-interface gaps only as "
        "derived candidates pending trim, modal and source-review validation"
    )

    return output_rows, report_lines


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "source_id",
        "mach",
        "case_id",
        "case_source_id",
        "group",
        "coefficient",
        "basis",
        "value",
        "units",
        "status",
        "confidence",
        "interpolation_policy",
        "notes",
    ]
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    mach_rows = read_csv(args.mach_candidate_csv)
    control_rows = read_csv(args.control_candidate_csv)
    rows, report_lines = build_rows(mach_rows, control_rows, args.source_id)
    write_csv(args.output_csv, rows)

    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(report_lines) + "\n")

    print(f"Wrote {len(rows)} derived DATCOM gap-fill candidate rows to {args.output_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
