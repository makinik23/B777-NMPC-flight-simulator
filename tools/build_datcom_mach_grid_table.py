#!/usr/bin/env python3
"""Build a consolidated Mach-dependent derivative candidate table."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


GRID_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0"
EXPECTED_COEFFICIENTS = (
    "CY_beta",
    "Cl_beta",
    "Cn_beta",
    "CL_q",
    "Cm_q",
    "CY_p",
    "Cl_p",
    "Cn_p",
    "Cn_r",
    "Cl_r",
)
EXPECTED_SIGNS = {
    "CY_beta": -1,
    "Cl_beta": -1,
    "Cn_beta": 1,
    "CL_q": 1,
    "Cm_q": -1,
    "CY_p": -1,
    "Cl_p": -1,
    "Cn_p": -1,
    "Cn_r": -1,
}
INTERPOLATION_POLICY = (
    "linear in Mach inside committed grid; no extrapolation before validation"
)


@dataclass(frozen=True)
class RunIndexRow:
    case_id: str
    mach: float
    candidate_file: Path
    extraction_report: Path
    datcom_exit_status: int
    error_count: int
    warning_count: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Consolidate per-Mach DATCOM candidate CSV files."
    )
    parser.add_argument("run_index_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--source-id", default=GRID_SOURCE_ID)
    return parser.parse_args()


def root_from_run_index(run_index_csv: Path) -> Path:
    run_index_csv = run_index_csv.resolve()
    parts = run_index_csv.parts
    marker = ("data", "aerodynamics", "raw", "datcom", "mach_grid")
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
                    candidate_file=resolve_project_path(root, row["candidate_file"]),
                    extraction_report=resolve_project_path(root, row["extraction_report"]),
                    datcom_exit_status=int(row["datcom_exit_status"]),
                    error_count=int(row["error_count"]),
                    warning_count=int(row["warning_count"]),
                )
            )

    rows.sort(key=lambda item: item.mach)
    return rows


def read_candidate_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def sign_ok(coefficient: str, value: float) -> bool:
    expected = EXPECTED_SIGNS.get(coefficient)
    if expected is None:
        return True
    return value * expected > 0.0


def build_table(
    run_rows: list[RunIndexRow],
    source_id: str,
) -> tuple[list[dict[str, object]], list[str]]:
    output_rows: list[dict[str, object]] = []
    report_lines = [
        f"source_id={source_id}",
        f"interpolation_policy={INTERPOLATION_POLICY}",
        f"mach_count={len(run_rows)}",
        "mach_grid=" + " ".join(f"{row.mach:.2f}" for row in run_rows),
    ]
    by_coefficient: dict[str, list[tuple[float, float]]] = defaultdict(list)

    for run_row in run_rows:
        if run_row.datcom_exit_status != 0 or run_row.error_count != 0:
            raise ValueError(
                f"Run {run_row.case_id} did not pass quality gates: "
                f"exit={run_row.datcom_exit_status} errors={run_row.error_count}"
            )
        if not run_row.candidate_file.is_file():
            raise FileNotFoundError(run_row.candidate_file)

        candidate_rows = read_candidate_rows(run_row.candidate_file)
        found = {row["coefficient"] for row in candidate_rows}
        missing = set(EXPECTED_COEFFICIENTS) - found
        extra = found - set(EXPECTED_COEFFICIENTS)
        if missing or extra:
            raise ValueError(
                f"Unexpected coefficients for {run_row.case_id}: "
                f"missing={sorted(missing)} extra={sorted(extra)}"
            )

        case_sources = {row["source_id"] for row in candidate_rows}
        if len(case_sources) != 1:
            raise ValueError(f"Run {run_row.case_id} has multiple source ids.")
        case_source_id = sorted(case_sources)[0]

        for row in candidate_rows:
            coefficient = row["coefficient"]
            value = float(row["value"])
            confidence = float(row["confidence"])
            status = row["status"]
            if status != "candidate-pending-review":
                raise ValueError(
                    f"Unexpected status for {run_row.case_id} {coefficient}: {status}"
                )
            if not sign_ok(coefficient, value):
                raise ValueError(
                    f"Unexpected sign for {run_row.case_id} {coefficient}: {value}"
                )

            output_rows.append(
                {
                    "source_id": source_id,
                    "mach": f"{run_row.mach:.2f}",
                    "case_id": run_row.case_id,
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

    output_rows.sort(
        key=lambda row: (float(row["mach"]), EXPECTED_COEFFICIENTS.index(row["coefficient"]))
    )

    for coefficient in EXPECTED_COEFFICIENTS:
        samples = sorted(by_coefficient[coefficient])
        values = [value for _, value in samples]
        machs = [mach for mach, _ in samples]
        report_lines.append(
            f"{coefficient}: count={len(samples)} "
            f"mach_min={min(machs):.2f} mach_max={max(machs):.2f} "
            f"value_min={min(values):.8f} value_max={max(values):.8f}"
        )

    return output_rows, report_lines


def write_table(path: Path, rows: list[dict[str, object]]) -> None:
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
    run_rows = read_run_index(args.run_index_csv)
    output_rows, report_lines = build_table(run_rows, args.source_id)
    write_table(args.output_csv, output_rows)

    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(report_lines) + "\n")

    print(f"Wrote {len(output_rows)} Mach-grid derivative rows to {args.output_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
