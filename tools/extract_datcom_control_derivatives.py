#!/usr/bin/env python3
"""Extract control derivative candidates from a Digital DATCOM output file."""

from __future__ import annotations

import argparse
import csv
import math
import re
from pathlib import Path


FLOAT_RE = re.compile(r"^\s*[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?")
NUMBER_RE = re.compile(r"[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?")
CONTROL_REFERENCE_ALPHA_DEG = 2.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract Digital DATCOM elevator and aileron control candidates."
    )
    parser.add_argument("datcom_out", type=Path)
    parser.add_argument("candidate_csv", type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--source-id", default=None)
    parser.add_argument("--status", default="candidate-pending-review")
    return parser.parse_args()


def numbers_from_line(line: str) -> list[float]:
    return [float(match.group(0)) for match in NUMBER_RE.finditer(line)]


def parse_mach_reynolds(lines: list[str]) -> tuple[float, float | None]:
    for line in lines:
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
    raise ValueError("Could not find Mach number in DATCOM output.")


def detect_control_id(lines: list[str]) -> str:
    joined = "\n".join(lines).upper()
    if "ELEVATOR CONTROL" in joined:
        return "elevator"
    if "AILERON CONTROL" in joined:
        return "aileron"
    raise ValueError("Could not identify control case from CASEID text.")


def source_id_from_control(control_id: str, mach: float) -> str:
    mach_code = int(round(mach * 100.0))
    return f"DIGITAL_DATCOM_B777_LIKE_CONTROL_{control_id.upper()}_M{mach_code:03d}_CANDIDATE_V0"


def choose_alpha_row(
    rows: list[tuple[float, list[float]]],
    target_alpha_deg: float,
) -> tuple[float, list[float]]:
    if not rows:
        raise ValueError("No alpha rows were available.")
    return min(rows, key=lambda row: (abs(row[0] - target_alpha_deg), abs(row[0])))


def linear_slope_per_rad(
    samples: dict[float, float],
    label: str,
) -> tuple[float, str]:
    pairs = []
    for delta in sorted(samples):
        if delta > 0.0 and -delta in samples:
            pairs.append(delta)
    if not pairs:
        raise ValueError(f"No symmetric deflection pair found for {label}.")
    delta = max(pairs)
    slope_per_deg = (samples[delta] - samples[-delta]) / (2.0 * delta)
    slope_per_rad = slope_per_deg * 180.0 / math.pi
    return slope_per_rad, (
        f"central difference using +/-{delta:g} deg; "
        f"{label}(+)= {samples[delta]:.8g}, {label}(-)= {samples[-delta]:.8g}"
    )


def quadratic_per_rad2(
    samples: dict[float, float],
    label: str,
) -> tuple[float, str]:
    values = []
    for delta_deg, value in samples.items():
        if abs(delta_deg) < 1e-12:
            continue
        delta_rad = math.radians(delta_deg)
        values.append(value / (delta_rad * delta_rad))
    if not values:
        raise ValueError(f"No nonzero deflection samples found for {label}.")
    average = sum(values) / len(values)
    return average, (
        f"mean quadratic coefficient from {len(values)} nonzero samples; "
        f"{label}/delta_rad^2"
    )


def parse_symmetric_increment_table(lines: list[str]) -> list[dict[str, float]]:
    for idx, line in enumerate(lines):
        if "INCREMENTS DUE TO DEFLECTION" not in line:
            continue
        rows: list[dict[str, float]] = []
        for candidate in lines[idx + 1 :]:
            if "INDUCED DRAG COEFFICIENT INCREMENT" in candidate:
                break
            if not FLOAT_RE.match(candidate):
                continue
            nums = numbers_from_line(candidate)
            if len(nums) < 5:
                continue
            rows.append(
                {
                    "delta_deg": nums[0],
                    "dcl": nums[1],
                    "dcm": nums[2],
                    "dclmax": nums[3],
                    "dcdmin": nums[4],
                }
            )
        if rows:
            return rows
    raise ValueError("Could not find symmetric control increment table.")


def parse_symmetric_induced_drag(
    lines: list[str],
    target_alpha_deg: float,
) -> tuple[dict[float, float], float]:
    for idx, line in enumerate(lines):
        if "DELTA =" not in line:
            continue
        deltas = numbers_from_line(line.split("=", 1)[1])
        if not deltas:
            continue
        rows: list[tuple[float, list[float]]] = []
        for candidate in lines[idx + 1 :]:
            if candidate.startswith("0***") or candidate.startswith(" Return "):
                break
            if not FLOAT_RE.match(candidate):
                continue
            nums = numbers_from_line(candidate)
            if len(nums) < len(deltas) + 1:
                continue
            rows.append((nums[0], nums[1 : 1 + len(deltas)]))
        if rows:
            alpha, values = choose_alpha_row(rows, target_alpha_deg)
            return dict(zip(deltas, values)), alpha
    raise ValueError("Could not find symmetric induced drag table.")


def parse_asymmetric_cn_table(
    lines: list[str],
    target_alpha_deg: float,
) -> tuple[dict[float, float], float]:
    for idx, line in enumerate(lines):
        if "YAWING MOMENT COEFFICIENT" not in line or "CONTROL DEFLECTION" not in line:
            continue
        delta_line_idx = None
        for candidate_idx in range(idx + 1, min(idx + 8, len(lines))):
            if "(DELTAL-DELTAR)=" in lines[candidate_idx]:
                delta_line_idx = candidate_idx
                break
        if delta_line_idx is None:
            continue
        ddelta_deg = numbers_from_line(lines[delta_line_idx].split("=", 1)[1])
        rows: list[tuple[float, list[float]]] = []
        for candidate in lines[delta_line_idx + 1 :]:
            if "DELTAL" in candidate and "DELTAR" in candidate:
                break
            if not FLOAT_RE.match(candidate):
                continue
            nums = numbers_from_line(candidate)
            if len(nums) < len(ddelta_deg) + 1:
                continue
            rows.append((nums[0], nums[1 : 1 + len(ddelta_deg)]))
        if rows:
            alpha, values = choose_alpha_row(rows, target_alpha_deg)
            effective_delta_deg = [value / 2.0 for value in ddelta_deg]
            return dict(zip(effective_delta_deg, values)), alpha
    raise ValueError("Could not find asymmetric yawing-moment table.")


def parse_asymmetric_roll_table(lines: list[str]) -> dict[float, float]:
    for idx, line in enumerate(lines):
        if "DELTAL" not in line or "DELTAR" not in line or "(CL)ROLL" not in line:
            continue
        rows: dict[float, float] = {}
        for candidate in lines[idx + 1 :]:
            if candidate.startswith(" Return ") or candidate.startswith("1 "):
                break
            if not FLOAT_RE.match(candidate):
                continue
            nums = numbers_from_line(candidate)
            if len(nums) < 3:
                continue
            effective_delta_deg = (nums[0] - nums[1]) / 2.0
            rows[effective_delta_deg] = nums[2]
        if rows:
            return rows
    raise ValueError("Could not find asymmetric rolling-moment table.")


def candidate_row(
    source_id: str,
    coefficient: str,
    basis: str,
    value: float,
    units: str,
    status: str,
    confidence: float,
    notes: str,
) -> dict[str, object]:
    return {
        "source_id": source_id,
        "group": "control",
        "coefficient": coefficient,
        "basis": basis,
        "value": f"{value:.8f}",
        "units": units,
        "status": status,
        "confidence": f"{confidence:.2f}",
        "notes": notes,
    }


def build_elevator_rows(
    lines: list[str],
    source_id: str,
    status: str,
) -> tuple[list[dict[str, object]], list[str]]:
    increments = parse_symmetric_increment_table(lines)
    induced_drag, drag_alpha = parse_symmetric_induced_drag(lines, 0.0)

    dcl = {row["delta_deg"]: row["dcl"] for row in increments}
    dcm = {row["delta_deg"]: row["dcm"] for row in increments}
    dcd_total = {
        row["delta_deg"]: row["dcdmin"] + induced_drag.get(row["delta_deg"], 0.0)
        for row in increments
    }

    cl_delta_e, cl_detail = linear_slope_per_rad(dcl, "DCL")
    cm_delta_e, cm_detail = linear_slope_per_rad(dcm, "DCM")
    cd_delta_e, cd_detail = quadratic_per_rad2(dcd_total, "DCD")

    rows = [
        candidate_row(
            source_id,
            "CL_delta_e",
            "delta_e_rad",
            cl_delta_e,
            "1/rad",
            status,
            0.35,
            "Elevator derivative from DATCOM SYMFLP D(CL); " + cl_detail,
        ),
        candidate_row(
            source_id,
            "Cm_delta_e",
            "delta_e_rad",
            cm_delta_e,
            "1/rad",
            status,
            0.35,
            "Elevator derivative from DATCOM SYMFLP D(CM); " + cm_detail,
        ),
        candidate_row(
            source_id,
            "CD_delta_e",
            "delta_e_rad_squared",
            cd_delta_e,
            "1/rad^2",
            status,
            0.30,
            (
                "Elevator drag from DATCOM SYMFLP D(CD MIN)+D(CDI) "
                f"at alpha {drag_alpha:g} deg; {cd_detail}"
            ),
        ),
    ]
    report = [
        f"elevator_increment_rows={len(increments)}",
        f"elevator_induced_drag_alpha_deg={drag_alpha:g}",
        f"CL_delta_e={cl_delta_e:.8f} | {cl_detail}",
        f"Cm_delta_e={cm_delta_e:.8f} | {cm_detail}",
        f"CD_delta_e={cd_delta_e:.8f} | {cd_detail}",
    ]
    return rows, report


def build_aileron_rows(
    lines: list[str],
    source_id: str,
    status: str,
) -> tuple[list[dict[str, object]], list[str]]:
    cn_samples, cn_alpha = parse_asymmetric_cn_table(lines, CONTROL_REFERENCE_ALPHA_DEG)
    roll_samples = parse_asymmetric_roll_table(lines)

    cn_delta_a, cn_detail = linear_slope_per_rad(cn_samples, "CN")
    cl_delta_a, cl_detail = linear_slope_per_rad(roll_samples, "Cl")

    rows = [
        candidate_row(
            source_id,
            "CY_delta_a",
            "delta_a_rad",
            0.0,
            "1/rad",
            status,
            0.20,
            (
                "Aileron side-force derivative not printed by DATCOM ASYFLP; "
                "set to zero by symmetry pending review."
            ),
        ),
        candidate_row(
            source_id,
            "Cl_delta_a",
            "delta_a_rad",
            cl_delta_a,
            "1/rad",
            status,
            0.35,
            "Aileron derivative from DATCOM ASYFLP (CL)ROLL; " + cl_detail,
        ),
        candidate_row(
            source_id,
            "Cn_delta_a",
            "delta_a_rad",
            cn_delta_a,
            "1/rad",
            status,
            0.30,
            (
                f"Aileron yawing derivative from DATCOM ASYFLP CN at alpha {cn_alpha:g} deg; "
                + cn_detail
            ),
        ),
    ]
    report = [
        f"aileron_yaw_alpha_deg={cn_alpha:g}",
        f"CY_delta_a=0.00000000 | symmetry assumption, not printed by DATCOM",
        f"Cl_delta_a={cl_delta_a:.8f} | {cl_detail}",
        f"Cn_delta_a={cn_delta_a:.8f} | {cn_detail}",
        "CD_delta_a=missing | DATCOM ASYFLP output does not provide drag increment",
    ]
    return rows, report


def build_candidate_rows(
    lines: list[str],
    source_id: str | None,
    status: str,
) -> tuple[list[dict[str, object]], list[str]]:
    mach, reynolds = parse_mach_reynolds(lines)
    control_id = detect_control_id(lines)
    source_id = source_id or source_id_from_control(control_id, mach)

    warning_lines = [line.strip() for line in lines if "WARNING" in line]
    report_lines = [
        f"source_id={source_id}",
        f"control_id={control_id}",
        f"mach={mach:.6g}",
        f"reynolds_per_meter={'' if reynolds is None else f'{reynolds:.6g}'}",
        f"warning_count={len(warning_lines)}",
    ]
    for warning in warning_lines:
        report_lines.append(f"warning={warning}")

    if control_id == "elevator":
        rows, control_report = build_elevator_rows(lines, source_id, status)
    elif control_id == "aileron":
        rows, control_report = build_aileron_rows(lines, source_id, status)
    else:
        raise ValueError(f"Unsupported control case: {control_id}")

    report_lines.extend(control_report)
    return rows, report_lines


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

    print(f"Wrote {len(rows)} DATCOM control derivative candidates to {args.candidate_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
