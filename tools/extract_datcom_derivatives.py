#!/usr/bin/env python3
"""Extract selected residual derivatives from a Digital DATCOM output file."""

from __future__ import annotations

import argparse
import csv
import math
import re
from dataclasses import dataclass
from pathlib import Path


FLOAT_RE = re.compile(r"^\s*[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?")
NUMBER_RE = re.compile(r"[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?")


@dataclass(frozen=True)
class ExtractSpec:
    group: str
    coefficient: str
    table: str
    datcom_column: str
    basis: str
    units: str
    target_alpha_deg: float
    confidence: float
    expected_sign: int | None


EXTRACT_SPECS = (
    ExtractSpec("static", "CY_beta", "static", "CYB", "beta_rad", "1/rad", 0.0, 0.40, -1),
    ExtractSpec("static", "Cl_beta", "static", "CLB", "beta_rad", "1/rad", 0.0, 0.40, -1),
    ExtractSpec("static", "Cn_beta", "static", "CNB", "beta_rad", "1/rad", 0.0, 0.40, 1),
    ExtractSpec("dynamic", "CL_q", "dynamic", "CLQ", "q_hat", "1", 0.0, 0.35, 1),
    ExtractSpec("dynamic", "Cm_q", "dynamic", "CMQ", "q_hat", "1", 0.0, 0.35, -1),
    ExtractSpec("dynamic", "CY_p", "dynamic", "CYP", "p_hat", "1", 0.0, 0.35, -1),
    ExtractSpec("dynamic", "Cl_p", "dynamic", "CLP", "p_hat", "1", 0.0, 0.35, -1),
    ExtractSpec("dynamic", "Cn_p", "dynamic", "CNP", "p_hat", "1", 0.0, 0.30, -1),
    ExtractSpec("dynamic", "Cn_r", "dynamic", "CNR", "r_hat", "1", 0.0, 0.35, -1),
    ExtractSpec("dynamic", "Cl_r", "dynamic", "CLR", "r_hat", "1", 0.0, 0.35, None),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract source-oriented candidate derivative CSV from datcom.out."
    )
    parser.add_argument("datcom_out", type=Path)
    parser.add_argument("candidate_csv", type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--source-id", default=None)
    parser.add_argument("--status", default="candidate-pending-review")
    return parser.parse_args()


def parse_static_row(line: str) -> dict[str, object]:
    numbers = [float(match.group(0)) for match in NUMBER_RE.finditer(line)]
    row: dict[str, object] = {column: None for column in (
        "ALPHA", "CD", "CL", "CM", "CN", "CA", "XCP", "CLA", "CMA", "CYB", "CNB", "CLB"
    )}
    invalid: dict[str, str] = {}

    if len(numbers) == 12:
        columns = ("ALPHA", "CD", "CL", "CM", "CN", "CA", "XCP", "CLA", "CMA", "CYB", "CNB", "CLB")
    elif len(numbers) == 10:
        columns = ("ALPHA", "CD", "CL", "CM", "CN", "CA", "XCP", "CLA", "CMA", "CLB")
        invalid.update({"CYB": "blank", "CNB": "blank"})
    elif len(numbers) == 9:
        columns = ("ALPHA", "CD", "CL", "CM", "CN", "CA", "CLA", "CMA", "CLB")
        invalid.update({"XCP": "blank-or-overflow", "CYB": "blank", "CNB": "blank"})
    else:
        raise ValueError(f"Unexpected static DATCOM row format: {line}")

    for column, value in zip(columns, numbers):
        row[column] = value
    row["_invalid"] = invalid
    return row


def parse_dynamic_row(line: str) -> dict[str, object]:
    numbers = [float(match.group(0)) for match in NUMBER_RE.finditer(line)]
    row: dict[str, object] = {column: None for column in (
        "ALPHA", "CLQ", "CMQ", "CLAD", "CMAD", "CLP", "CYP", "CNP", "CNR", "CLR"
    )}
    invalid: dict[str, str] = {}

    if len(numbers) == 10:
        columns = ("ALPHA", "CLQ", "CMQ", "CLAD", "CMAD", "CLP", "CYP", "CNP", "CNR", "CLR")
    elif len(numbers) == 8:
        columns = ("ALPHA", "CLAD", "CMAD", "CLP", "CYP", "CNP", "CNR", "CLR")
        invalid.update({"CLQ": "blank", "CMQ": "blank"})
    elif len(numbers) == 7 and "NDM" in line:
        columns = ("ALPHA", "CLAD", "CMAD", "CLP", "CYP", "CNR", "CLR")
        invalid.update({"CLQ": "blank", "CMQ": "blank", "CNP": "NDM"})
    else:
        raise ValueError(f"Unexpected dynamic DATCOM row format: {line}")

    for column, value in zip(columns, numbers):
        row[column] = value
    row["_invalid"] = invalid
    return row


def parse_datcom_table(
    lines: list[str],
    header_idx: int,
    table: str,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []

    for line in lines[header_idx + 1 :]:
        stripped = line.strip()
        if not stripped or stripped == "0":
            if rows:
                break
            continue
        if stripped.startswith("0***") or stripped.startswith("0 "):
            break
        if not FLOAT_RE.match(line):
            if rows:
                break
            continue

        if table == "static":
            row = parse_static_row(line)
        elif table == "dynamic":
            row = parse_dynamic_row(line)
        else:
            raise ValueError(f"Unsupported DATCOM table type: {table}")
        rows.append(row)

    return rows


def find_static_header(lines: list[str]) -> int:
    for idx, line in enumerate(lines):
        if "ALPHA" in line and "CYB" in line and "CNB" in line and "CLB" in line:
            return idx
    raise ValueError("Could not find DATCOM static derivative table header.")


def find_dynamic_header(lines: list[str]) -> int:
    for idx, line in enumerate(lines):
        if "ALPHA" in line and "CLQ" in line and "CMQ" in line and "CNR" in line:
            return idx
    raise ValueError("Could not find DATCOM dynamic derivative table header.")


def parse_mach_reynolds(lines: list[str], before_idx: int) -> tuple[float, float | None]:
    for line in reversed(lines[:before_idx]):
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "0":
            try:
                mach = float(parts[1])
            except ValueError:
                continue
            reynolds = None
            if len(parts) >= 3:
                try:
                    reynolds = float(parts[2])
                except ValueError:
                    reynolds = None
            return mach, reynolds
    raise ValueError("Could not find Mach number before derivative table.")


def sign_matches(value: float, expected_sign: int | None) -> bool:
    if expected_sign is None:
        return True
    return value * expected_sign > 0.0


def choose_value(
    rows: list[dict[str, object]],
    column: str,
    target_alpha_deg: float,
    expected_sign: int | None,
) -> tuple[float, float, str]:
    candidates: list[tuple[float, float, dict[str, object]]] = []
    rejected: list[str] = []

    for row in rows:
        alpha = row["ALPHA"]
        value = row[column]
        invalid = row["_invalid"]
        assert isinstance(invalid, dict)

        if not isinstance(alpha, float):
            continue
        if not isinstance(value, float):
            marker = invalid.get(column, "missing")
            rejected.append(f"alpha {alpha:g} deg {column} {marker}")
            continue
        if not sign_matches(value, expected_sign):
            rejected.append(f"alpha {alpha:g} deg {column} sign rejected")
            continue
        candidates.append((abs(alpha - target_alpha_deg), abs(alpha), row))

    if not candidates:
        raise ValueError(f"No usable DATCOM value found for {column}. Rejected: {rejected}")

    candidates.sort(key=lambda item: (item[0], item[1], 0 if item[2]["ALPHA"] >= 0 else 1))
    selected = candidates[0][2]
    alpha = selected["ALPHA"]
    value = selected[column]
    assert isinstance(alpha, float)
    assert isinstance(value, float)

    details = [f"selected alpha {alpha:g} deg"]
    if rejected:
        details.append("rejected " + "; ".join(rejected))
    return value / (math.pi / 180.0), alpha, " | ".join(details)


def source_id_from_mach(mach: float) -> str:
    mach_code = int(round(mach * 100.0))
    return f"DIGITAL_DATCOM_B777_LIKE_M{mach_code:03d}_CANDIDATE_V0"


def build_candidate_rows(
    lines: list[str],
    source_id: str | None,
    status: str,
) -> tuple[list[dict[str, object]], list[str]]:
    static_header_idx = find_static_header(lines)
    dynamic_header_idx = find_dynamic_header(lines)
    mach, reynolds = parse_mach_reynolds(lines, static_header_idx)
    source_id = source_id or source_id_from_mach(mach)

    static_rows = parse_datcom_table(lines, static_header_idx, "static")
    dynamic_rows = parse_datcom_table(lines, dynamic_header_idx, "dynamic")

    table_rows = {"static": static_rows, "dynamic": dynamic_rows}
    candidate_rows: list[dict[str, object]] = []
    report_lines = [
        f"source_id={source_id}",
        f"mach={mach:.6g}",
        f"reynolds_per_meter={'' if reynolds is None else f'{reynolds:.6g}'}",
        f"static_rows={len(static_rows)}",
        f"dynamic_rows={len(dynamic_rows)}",
    ]

    warning_lines = [line.strip() for line in lines if "WARNING" in line]
    report_lines.append(f"warning_count={len(warning_lines)}")
    for warning in warning_lines:
        report_lines.append(f"warning={warning}")

    for spec in EXTRACT_SPECS:
        value, alpha_deg, detail = choose_value(
            table_rows[spec.table],
            spec.datcom_column,
            spec.target_alpha_deg,
            spec.expected_sign,
        )
        note = (
            f"Extracted from DATCOM {spec.datcom_column} at Mach {mach:.2f} "
            f"alpha {alpha_deg:g} deg converted from per degree"
        )
        candidate_rows.append(
            {
                "source_id": source_id,
                "group": spec.group,
                "coefficient": spec.coefficient,
                "basis": spec.basis,
                "value": f"{value:.8f}",
                "units": spec.units,
                "status": status,
                "confidence": f"{spec.confidence:.2f}",
                "notes": note,
            }
        )
        report_lines.append(f"{spec.coefficient}={value:.8f} | {detail}")

    return candidate_rows, report_lines


def write_candidate_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "source_id",
        "group",
        "coefficient",
        "basis",
        "value",
        "units",
        "status",
        "confidence",
        "notes",
    ]
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    lines = args.datcom_out.read_text(errors="replace").splitlines()
    rows, report_lines = build_candidate_rows(lines, args.source_id, args.status)
    write_candidate_csv(args.candidate_csv, rows)

    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(report_lines) + "\n")

    print(f"Wrote {len(rows)} DATCOM derivative candidates to {args.candidate_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
