#!/usr/bin/env python3
"""Build a consolidated Mach-dependent DATCOM control derivative table."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


GRID_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0"
INTERPOLATION_POLICY = (
    "linear in Mach by control derivative inside committed grid; "
    "no extrapolation before validation"
)
EXPECTED_ACTIVE_CONTROL_COEFFICIENTS = (
    "CD_delta_a",
    "CD_delta_e",
    "CD_delta_r",
    "CL_delta_e",
    "CY_delta_a",
    "CY_delta_r",
    "Cl_delta_a",
    "Cl_delta_r",
    "Cm_delta_e",
    "Cn_delta_a",
    "Cn_delta_r",
)
COEFFICIENT_ORDER = (
    "CL_delta_e",
    "Cm_delta_e",
    "CD_delta_e",
    "CY_delta_a",
    "Cl_delta_a",
    "Cn_delta_a",
)
CONTROL_ORDER = ("elevator", "aileron")


@dataclass(frozen=True)
class RunIndexRow:
    case_id: str
    mach: float
    control_id: str
    candidate_file: Path
    extraction_report: Path
    datcom_exit_status: int
    error_count: int
    warning_count: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Consolidate per-Mach DATCOM control derivative CSV files."
    )
    parser.add_argument("run_index_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--source-id", default=GRID_SOURCE_ID)
    return parser.parse_args()


def root_from_run_index(run_index_csv: Path) -> Path:
    run_index_csv = run_index_csv.resolve()
    parts = run_index_csv.parts
    marker = ("data", "aerodynamics", "raw", "datcom", "control_grid")
    for idx in range(len(parts) - len(marker) + 1):
        if parts[idx : idx + len(marker)] == marker:
            return Path(*parts[:idx])
    return Path.cwd()


def resolve_project_path(root: Path, value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return root / path


def read_run_index(path: Path) -> list[RunIndexRow]:
    root = root_from_run_index(path)
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        rows = []
        for row in reader:
            rows.append(
                RunIndexRow(
                    case_id=row["case_id"],
                    mach=float(row["mach"]),
                    control_id=row["control_id"],
                    candidate_file=resolve_project_path(root, row["candidate_file"]),
                    extraction_report=resolve_project_path(root, row["extraction_report"]),
                    datcom_exit_status=int(row["datcom_exit_status"]),
                    error_count=int(row["error_count"]),
                    warning_count=int(row["warning_count"]),
                )
            )

    rows.sort(key=lambda item: (item.mach, CONTROL_ORDER.index(item.control_id)))
    return rows


def read_candidate_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def coefficient_sort_key(coefficient: str) -> int:
    if coefficient in COEFFICIENT_ORDER:
        return COEFFICIENT_ORDER.index(coefficient)
    return len(COEFFICIENT_ORDER)


def build_table(
    run_rows: list[RunIndexRow],
    source_id: str,
) -> tuple[list[dict[str, object]], list[str]]:
    output_rows: list[dict[str, object]] = []
    by_coefficient: dict[str, list[tuple[float, float]]] = defaultdict(list)
    by_control = defaultdict(int)

    report_lines = [
        f"source_id={source_id}",
        f"interpolation_policy={INTERPOLATION_POLICY}",
        f"mach_count={len(sorted({row.mach for row in run_rows}))}",
        "mach_grid=" + " ".join(f"{mach:.2f}" for mach in sorted({row.mach for row in run_rows})),
        "control_cases=" + " ".join(sorted({row.control_id for row in run_rows})),
    ]

    for run_row in run_rows:
        if run_row.datcom_exit_status != 0 or run_row.error_count != 0:
            raise ValueError(
                f"Run {run_row.case_id} did not pass quality gates: "
                f"exit={run_row.datcom_exit_status} errors={run_row.error_count}"
            )
        if not run_row.candidate_file.is_file():
            raise FileNotFoundError(run_row.candidate_file)

        candidate_rows = read_candidate_rows(run_row.candidate_file)
        case_sources = {row["source_id"] for row in candidate_rows}
        if len(case_sources) != 1:
            raise ValueError(f"Run {run_row.case_id} has multiple source ids.")
        case_source_id = sorted(case_sources)[0]

        for row in candidate_rows:
            coefficient = row["coefficient"]
            value = float(row["value"])
            confidence = float(row["confidence"])
            status = row["status"]
            if row["group"] != "control":
                raise ValueError(f"Unexpected group for {run_row.case_id}: {row['group']}")
            if status != "candidate-pending-review":
                raise ValueError(
                    f"Unexpected status for {run_row.case_id} {coefficient}: {status}"
                )

            output_rows.append(
                {
                    "source_id": source_id,
                    "mach": f"{run_row.mach:.2f}",
                    "case_id": run_row.case_id,
                    "control_id": run_row.control_id,
                    "case_source_id": case_source_id,
                    "group": row["group"],
                    "coefficient": coefficient,
                    "basis": row["basis"],
                    "value": f"{value:.8f}",
                    "units": row["units"],
                    "status": status,
                    "confidence": f"{confidence:.2f}",
                    "interpolation_policy": INTERPOLATION_POLICY,
                    "notes": (
                        f"Consolidated from {run_row.case_id}; "
                        f"warning_count={run_row.warning_count}; {row['notes']}"
                    ),
                }
            )
            by_coefficient[coefficient].append((run_row.mach, value))
            by_control[run_row.control_id] += 1

    output_rows.sort(
        key=lambda row: (
            float(row["mach"]),
            CONTROL_ORDER.index(row["control_id"]),
            coefficient_sort_key(row["coefficient"]),
        )
    )

    for control_id in CONTROL_ORDER:
        report_lines.append(f"{control_id}_row_count={by_control[control_id]}")

    for coefficient in sorted(by_coefficient, key=coefficient_sort_key):
        samples = sorted(by_coefficient[coefficient])
        values = [value for _, value in samples]
        machs = [mach for mach, _ in samples]
        report_lines.append(
            f"{coefficient}: count={len(samples)} "
            f"mach_min={min(machs):.2f} mach_max={max(machs):.2f} "
            f"value_min={min(values):.8f} value_max={max(values):.8f}"
        )

    found_control = set(by_coefficient)
    missing = [
        coefficient
        for coefficient in EXPECTED_ACTIVE_CONTROL_COEFFICIENTS
        if coefficient not in found_control
    ]
    report_lines.append(
        "missing_active_control_coefficients="
        + (", ".join(missing) if missing else "none")
    )
    report_lines.append(
        "datcom_direct_gap_notes="
        "rudder derivatives and aileron/rudder drag increments are not produced by the current DATCOM control decks"
    )

    return output_rows, report_lines


def write_table(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "source_id",
        "mach",
        "case_id",
        "control_id",
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
    run_rows = read_run_index(args.run_index_csv)
    output_rows, report_lines = build_table(run_rows, args.source_id)
    write_table(args.output_csv, output_rows)

    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(report_lines) + "\n")

    print(f"Wrote {len(output_rows)} Mach-grid control derivative rows to {args.output_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
