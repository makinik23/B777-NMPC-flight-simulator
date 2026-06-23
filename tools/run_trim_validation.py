#!/usr/bin/env python3
"""Run clean-cruise longitudinal trim validation for DATCOM candidates."""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path


STANDARD_GRAVITY_MPS2 = 9.80665
GAS_CONSTANT_JPKGK = 287.05287
SPECIFIC_HEAT_RATIO = 1.4
SREF_M2 = 436.80
MAX_STATIC_THRUST_TOTAL_N = 1024_000.0
CLMAX_CLEAN_ESTIMATE = 1.45

TRIM_SOURCE_ID = "DATCOM_CANDIDATE_LONGITUDINAL_TRIM_VALIDATION_V0"
CRM_SOURCE_ID = "NASA_CRM_NTF197_TWICS_CLEAN_GRID"
CONTROL_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0"


@dataclass(frozen=True)
class TrimCase:
    case_id: str
    h_m: float
    mach: float
    mass_kg: float
    gamma_deg: float
    config: str = "clean"


DEFAULT_CASES = (
    TrimCase("clean_cruise_m070", 10668.0, 0.70010, 250000.0, 0.0),
    TrimCase("clean_cruise_m075", 10668.0, 0.75015, 250000.0, 0.0),
    TrimCase("clean_cruise_m080", 10668.0, 0.80000, 250000.0, 0.0),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate clean-cruise longitudinal trim using the NASA CRM clean "
            "baseline and DATCOM elevator/control candidates."
        )
    )
    parser.add_argument(
        "--crm-grid-csv",
        type=Path,
        default=Path("data/aerodynamics/raw/nasa_crm/NTF197_TWICS_clean_grid.csv"),
    )
    parser.add_argument(
        "--control-candidate-csv",
        type=Path,
        default=Path(
            "data/aerodynamics/raw/datcom/control_grid/"
            "b777_like_control_derivative_datcom_candidate_mach_grid.csv"
        ),
    )
    parser.add_argument(
        "--case-csv",
        type=Path,
        default=Path("data/aerodynamics/validation/trim_validation_cases.csv"),
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("docs/trim_validation_report.md"),
    )
    return parser.parse_args()


def read_crm_grid(path: Path) -> list[dict[str, float | str]]:
    with path.open(newline="") as handle:
        rows: list[dict[str, float | str]] = []
        for row in csv.DictReader(handle):
            rows.append(
                {
                    "source_id": row["source_id"],
                    "run": row["run"],
                    "Mach": float(row["Mach"]),
                    "alpha_deg": float(row["alpha_deg"]),
                    "CL": float(row["CL"]),
                    "CD": float(row["CD"]),
                    "Cm": float(row["Cm"]),
                }
            )
    if not rows:
        raise ValueError(f"CRM grid is empty: {path}")
    return rows


def read_control_grid(path: Path) -> list[dict[str, float | str]]:
    with path.open(newline="") as handle:
        rows: list[dict[str, float | str]] = []
        for row in csv.DictReader(handle):
            if row["control_id"] != "elevator":
                continue
            if row["coefficient"] not in {"CL_delta_e", "Cm_delta_e", "CD_delta_e"}:
                continue
            rows.append(
                {
                    "source_id": row["source_id"],
                    "mach": float(row["mach"]),
                    "coefficient": row["coefficient"],
                    "value": float(row["value"]),
                }
            )
    if not rows:
        raise ValueError(f"Control grid has no elevator rows: {path}")
    return rows


def sorted_unique(values: list[float], tolerance: float = 1e-10) -> list[float]:
    result: list[float] = []
    for value in sorted(values):
        if not result or abs(value - result[-1]) > tolerance:
            result.append(value)
    return result


def bracket_index(grid: list[float], value: float, label: str) -> int:
    if value < grid[0] - 1e-12 or value > grid[-1] + 1e-12:
        raise ValueError(f"{label}={value:.8g} is outside [{grid[0]:.8g}, {grid[-1]:.8g}]")
    if value <= grid[0]:
        return 0
    if value >= grid[-1]:
        return len(grid) - 2
    for idx in range(len(grid) - 1):
        if grid[idx] <= value <= grid[idx + 1]:
            return idx
    raise ValueError(f"Could not bracket {label}={value:.8g}")


def lerp(x0: float, y0: float, x1: float, y1: float, x: float) -> float:
    if abs(x1 - x0) < 1e-12:
        return y0
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def crm_value(
    rows: list[dict[str, float | str]],
    mach: float,
    alpha_deg: float,
    coefficient: str,
) -> float:
    mach_grid = sorted_unique([float(row["Mach"]) for row in rows])
    alpha_grid = sorted_unique([float(row["alpha_deg"]) for row in rows])
    mach_idx = bracket_index(mach_grid, mach, "Mach")
    alpha_idx = bracket_index(alpha_grid, alpha_deg, "alpha_deg")

    def value_at_grid(mach_value: float, alpha_value: float) -> float:
        for row in rows:
            if (
                abs(float(row["Mach"]) - mach_value) < 1e-8
                and abs(float(row["alpha_deg"]) - alpha_value) < 1e-10
            ):
                return float(row[coefficient])
        raise ValueError(
            f"Missing CRM grid value for Mach={mach_value:.8g}, "
            f"alpha={alpha_value:.8g}, coefficient={coefficient}"
        )

    m0 = mach_grid[mach_idx]
    m1 = mach_grid[mach_idx + 1]
    a0 = alpha_grid[alpha_idx]
    a1 = alpha_grid[alpha_idx + 1]

    v00 = value_at_grid(m0, a0)
    v01 = value_at_grid(m0, a1)
    v10 = value_at_grid(m1, a0)
    v11 = value_at_grid(m1, a1)
    v0 = lerp(a0, v00, a1, v01, alpha_deg)
    v1 = lerp(a0, v10, a1, v11, alpha_deg)
    return lerp(m0, v0, m1, v1, mach)


def control_value(
    rows: list[dict[str, float | str]],
    mach: float,
    coefficient: str,
) -> float:
    samples = sorted(
        (float(row["mach"]), float(row["value"]))
        for row in rows
        if row["coefficient"] == coefficient
    )
    if not samples:
        raise ValueError(f"Missing control coefficient {coefficient}")
    mach_grid = [mach_value for mach_value, _ in samples]
    idx = bracket_index(mach_grid, mach, "control Mach")
    m0, v0 = samples[idx]
    m1, v1 = samples[idx + 1]
    return lerp(m0, v0, m1, v1, mach)


def isa_atmosphere(h_m: float) -> tuple[float, float]:
    temperature0_K = 288.15
    pressure0_Pa = 101325.0
    lapse_rate_Kpm = -0.0065
    tropopause_m = 11000.0
    temperature11_K = temperature0_K + lapse_rate_Kpm * tropopause_m
    pressure11_Pa = pressure0_Pa * (temperature11_K / temperature0_K) ** (
        -STANDARD_GRAVITY_MPS2 / (lapse_rate_Kpm * GAS_CONSTANT_JPKGK)
    )

    h_m = max(min(h_m, 20000.0), -500.0)
    if h_m <= tropopause_m:
        temperature_K = temperature0_K + lapse_rate_Kpm * h_m
        pressure_Pa = pressure0_Pa * (temperature_K / temperature0_K) ** (
            -STANDARD_GRAVITY_MPS2 / (lapse_rate_Kpm * GAS_CONSTANT_JPKGK)
        )
    else:
        temperature_K = temperature11_K
        pressure_Pa = pressure11_Pa * math.exp(
            -STANDARD_GRAVITY_MPS2
            * (h_m - tropopause_m)
            / (GAS_CONSTANT_JPKGK * temperature11_K)
        )

    rho_kgm3 = pressure_Pa / (GAS_CONSTANT_JPKGK * temperature_K)
    a_mps = math.sqrt(SPECIFIC_HEAT_RATIO * GAS_CONSTANT_JPKGK * temperature_K)
    return rho_kgm3, a_mps


def candidate_coefficients(
    crm_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
    mach: float,
    alpha_deg: float,
    delta_e_rad: float,
) -> tuple[float, float, float]:
    cl = crm_value(crm_rows, mach, alpha_deg, "CL") + control_value(
        control_rows, mach, "CL_delta_e"
    ) * delta_e_rad
    cd = crm_value(crm_rows, mach, alpha_deg, "CD") + control_value(
        control_rows, mach, "CD_delta_e"
    ) * delta_e_rad * delta_e_rad
    cm = crm_value(crm_rows, mach, alpha_deg, "Cm") + control_value(
        control_rows, mach, "Cm_delta_e"
    ) * delta_e_rad
    return cl, cd, cm


def elevator_for_pitch_trim(
    crm_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
    mach: float,
    alpha_deg: float,
) -> float:
    cm_clean = crm_value(crm_rows, mach, alpha_deg, "Cm")
    cm_delta_e = control_value(control_rows, mach, "Cm_delta_e")
    return -cm_clean / cm_delta_e


def vertical_residual(
    crm_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
    case: TrimCase,
    alpha_deg: float,
) -> tuple[float, dict[str, float]]:
    rho_kgm3, a_mps = isa_atmosphere(case.h_m)
    velocity_mps = case.mach * a_mps
    qbar_Pa = 0.5 * rho_kgm3 * velocity_mps * velocity_mps
    weight_N = case.mass_kg * STANDARD_GRAVITY_MPS2
    gamma_rad = math.radians(case.gamma_deg)
    alpha_rad = math.radians(alpha_deg)
    theta_rad = alpha_rad + gamma_rad

    delta_e_rad = elevator_for_pitch_trim(crm_rows, control_rows, case.mach, alpha_deg)
    cl, cd, cm = candidate_coefficients(
        crm_rows, control_rows, case.mach, alpha_deg, delta_e_rad
    )

    aero_z_N = qbar_Pa * SREF_M2 * (
        -cd * math.sin(alpha_rad) - cl * math.cos(alpha_rad)
    )
    gravity_z_N = weight_N * math.cos(theta_rad)
    residual_N = aero_z_N + gravity_z_N

    details = {
        "rho_kgm3": rho_kgm3,
        "a_mps": a_mps,
        "velocity_mps": velocity_mps,
        "qbar_Pa": qbar_Pa,
        "weight_N": weight_N,
        "theta_rad": theta_rad,
        "delta_e_rad": delta_e_rad,
        "CL": cl,
        "CD": cd,
        "Cm": cm,
        "aero_z_N": aero_z_N,
        "gravity_z_N": gravity_z_N,
    }
    return residual_N, details


def solve_case(
    crm_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
    case: TrimCase,
) -> dict[str, object]:
    alpha_grid = sorted_unique([float(row["alpha_deg"]) for row in crm_rows])
    low = max(alpha_grid[0], -2.0)
    high = min(alpha_grid[-1], 9.0)
    residual_low, _ = vertical_residual(crm_rows, control_rows, case, low)
    residual_high, _ = vertical_residual(crm_rows, control_rows, case, high)
    if residual_low * residual_high > 0.0:
        raise ValueError(
            f"Could not bracket trim alpha for {case.case_id}: "
            f"residual({low:g})={residual_low:.6g}, "
            f"residual({high:g})={residual_high:.6g}"
        )

    for _ in range(80):
        mid = 0.5 * (low + high)
        residual_mid, _ = vertical_residual(crm_rows, control_rows, case, mid)
        if residual_low * residual_mid <= 0.0:
            high = mid
            residual_high = residual_mid
        else:
            low = mid
            residual_low = residual_mid

    alpha_deg = 0.5 * (low + high)
    vertical_N, details = vertical_residual(crm_rows, control_rows, case, alpha_deg)
    alpha_rad = math.radians(alpha_deg)
    theta_rad = float(details["theta_rad"])
    qbar_Pa = float(details["qbar_Pa"])
    weight_N = float(details["weight_N"])
    cl = float(details["CL"])
    cd = float(details["CD"])
    cm = float(details["Cm"])

    aero_x_N = qbar_Pa * SREF_M2 * (
        -cd * math.cos(alpha_rad) + cl * math.sin(alpha_rad)
    )
    gravity_x_N = -weight_N * math.sin(theta_rad)
    thrust_required_N = -(aero_x_N + gravity_x_N)
    axial_residual_N = aero_x_N + gravity_x_N + thrust_required_N
    lift_margin = CLMAX_CLEAN_ESTIMATE - cl

    status_checks = {
        "alpha_range": -2.0 <= alpha_deg <= 8.0,
        "elevator_range": abs(math.degrees(float(details["delta_e_rad"]))) <= 5.0,
        "thrust_positive": thrust_required_N > 0.0,
        "throttle_range": 0.02 <= thrust_required_N / MAX_STATIC_THRUST_TOTAL_N <= 0.30,
        "vertical_residual": abs(vertical_N) / weight_N <= 1e-6,
        "axial_residual": abs(axial_residual_N) / weight_N <= 1e-9,
        "pitch_residual": abs(cm) <= 1e-10,
        "cl_margin": lift_margin >= 0.40,
    }
    status = "pass" if all(status_checks.values()) else "fail"

    return {
        "source_id": TRIM_SOURCE_ID,
        "case_id": case.case_id,
        "status": status,
        "config": case.config,
        "h_m": f"{case.h_m:.2f}",
        "mach": f"{case.mach:.4f}",
        "mass_kg": f"{case.mass_kg:.2f}",
        "gamma_deg": f"{case.gamma_deg:.4f}",
        "alpha_deg": f"{alpha_deg:.8f}",
        "theta_deg": f"{math.degrees(theta_rad):.8f}",
        "delta_e_deg": f"{math.degrees(float(details['delta_e_rad'])):.8f}",
        "CL": f"{cl:.8f}",
        "CD": f"{cd:.8f}",
        "Cm": f"{cm:.12f}",
        "CLmax_estimate": f"{CLMAX_CLEAN_ESTIMATE:.8f}",
        "CL_margin": f"{lift_margin:.8f}",
        "qbar_Pa": f"{qbar_Pa:.8f}",
        "velocity_mps": f"{float(details['velocity_mps']):.8f}",
        "weight_N": f"{weight_N:.4f}",
        "thrust_required_N": f"{thrust_required_N:.4f}",
        "throttle_static_equiv": f"{thrust_required_N / MAX_STATIC_THRUST_TOTAL_N:.8f}",
        "vertical_residual_N": f"{vertical_N:.8e}",
        "axial_residual_N": f"{axial_residual_N:.8e}",
        "pitch_moment_coeff_residual": f"{cm:.8e}",
        "checks": ";".join(name for name, passed in status_checks.items() if not passed)
        or "all-pass",
        "notes": (
            "Clean-cruise longitudinal trim using CRM CL/CD/Cm and DATCOM "
            "elevator candidates; thrust is a static-equivalent scalar along "
            "the body x axis, with no engine pitching moment model."
        ),
    }


def write_case_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "source_id",
        "case_id",
        "status",
        "config",
        "h_m",
        "mach",
        "mass_kg",
        "gamma_deg",
        "alpha_deg",
        "theta_deg",
        "delta_e_deg",
        "CL",
        "CD",
        "Cm",
        "CLmax_estimate",
        "CL_margin",
        "qbar_Pa",
        "velocity_mps",
        "weight_N",
        "thrust_required_N",
        "throttle_static_equiv",
        "vertical_residual_N",
        "axial_residual_N",
        "pitch_moment_coeff_residual",
        "checks",
        "notes",
    ]
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, rows: list[dict[str, object]], case_csv: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    passed = sum(1 for row in rows if row["status"] == "pass")
    failed = len(rows) - passed
    lines = [
        "# Trim Validation Report",
        "",
        f"source_id={TRIM_SOURCE_ID}",
        f"crm_source_id={CRM_SOURCE_ID}",
        f"control_source_id={CONTROL_SOURCE_ID}",
        f"case_count={len(rows)}",
        f"pass_count={passed}",
        f"fail_count={failed}",
        f"case_table={case_csv.as_posix()}",
        "",
        "## Scope",
        "",
        "This validation covers clean-cruise longitudinal trim for the DATCOM",
        "candidate aerodynamic path. The clean baseline is the NASA CRM NTF197",
        "TWICS Mach-alpha table. Elevator lift, pitching-moment and drag",
        "increments are taken from the Digital DATCOM control-grid candidate",
        "table. The trim solve enforces vertical force balance, zero pitching",
        "moment coefficient and positive static-equivalent thrust.",
        "",
        "This is not yet a full six-degree-of-freedom trim with engine pitching",
        "moments, actuator states or lateral-directional modal checks.",
        "",
        "## Results",
        "",
        "| Case | Mach | alpha deg | delta_e deg | CL | CD | thrust N | throttle static equiv | status |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        lines.append(
            "| {case_id} | {mach} | {alpha_deg} | {delta_e_deg} | "
            "{CL} | {CD} | {thrust_required_N} | {throttle_static_equiv} | {status} |".format(
                **row
            )
        )

    lines.extend(
        [
            "",
            "## Acceptance Criteria",
            "",
            "- Angle of attack must remain inside the clean CRM table range and below 8 deg.",
            "- Elevator trim must remain within +/-5 deg.",
            "- Static-equivalent thrust must be positive and below 30% of the public GE90-115B static thrust estimate.",
            "- Vertical and axial residuals must be numerically negligible.",
            "- Pitching-moment coefficient residual must be near zero.",
            "- Clean lift-coefficient margin to the current CLmax estimate must be at least 0.40.",
            "",
            "## Promotion Marker Recommendation",
            "",
            (
                "DATCOM_PROMOTION_TRIM_VALIDATED=true"
                if failed == 0
                else "DATCOM_PROMOTION_TRIM_VALIDATED=false"
            ),
            "",
        ]
    )
    path.write_text("\n".join(lines))


def main() -> int:
    args = parse_args()
    crm_rows = read_crm_grid(args.crm_grid_csv)
    control_rows = read_control_grid(args.control_candidate_csv)
    rows = [solve_case(crm_rows, control_rows, case) for case in DEFAULT_CASES]
    write_case_csv(args.case_csv, rows)
    write_report(args.report, rows, args.case_csv)

    failed = [row["case_id"] for row in rows if row["status"] != "pass"]
    if failed:
        print(f"Trim validation failed for: {', '.join(failed)}")
        return 1

    print(f"Trim validation passed for {len(rows)} cases.")
    print(f"Case table written to {args.case_csv}")
    print(f"Report written to {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
