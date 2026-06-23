#!/usr/bin/env python3
"""Run restricted longitudinal modal validation for DATCOM candidates."""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np


STANDARD_GRAVITY_MPS2 = 9.80665
GAS_CONSTANT_JPKGK = 287.05287
SPECIFIC_HEAT_RATIO = 1.4
SREF_M2 = 436.80
CBAR_M = 278.5 * 0.0254
FUSELAGE_LENGTH_M = 73.90
EFFECTIVE_VERTICAL_RADIUS_M = 4.5

MODAL_SOURCE_ID = "DATCOM_CANDIDATE_LONGITUDINAL_MODAL_VALIDATION_V0"
TRIM_SOURCE_ID = "DATCOM_CANDIDATE_LONGITUDINAL_TRIM_VALIDATION_V0"
CRM_SOURCE_ID = "NASA_CRM_NTF197_TWICS_CLEAN_GRID"
DERIVATIVE_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0"
CONTROL_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_CONTROL_GRID_CANDIDATE_V0"

STATE_LABELS = ("u_mps", "w_mps", "q_radps", "theta_rad")
FINITE_DIFFERENCE_STEPS = np.array([0.1, 0.1, 1.0e-4, 1.0e-5], dtype=float)


@dataclass(frozen=True)
class ModalTrimCase:
    case_id: str
    h_m: float
    mach: float
    mass_kg: float
    alpha_rad: float
    theta_rad: float
    delta_e_rad: float
    velocity_mps: float
    thrust_required_N: float


@dataclass(frozen=True)
class ModeResult:
    case_id: str
    mode_id: str
    status: str
    mach: float
    alpha_deg: float
    delta_e_deg: float
    u_trim_mps: float
    w_trim_mps: float
    theta_deg: float
    eigen_real_1: float
    eigen_imag_1: float
    eigen_real_2: float
    eigen_imag_2: float
    natural_frequency_radps: float
    damping_ratio: float
    period_s: float
    time_to_half_s: float
    residual_norm: float
    linearization_methods: str
    checks: str
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate restricted clean-cruise longitudinal modes around the "
            "existing DATCOM-candidate trim cases."
        )
    )
    parser.add_argument(
        "--trim-case-csv",
        type=Path,
        default=Path("data/aerodynamics/validation/trim_validation_cases.csv"),
    )
    parser.add_argument(
        "--crm-grid-csv",
        type=Path,
        default=Path("data/aerodynamics/raw/nasa_crm/NTF197_TWICS_clean_grid.csv"),
    )
    parser.add_argument(
        "--derivative-candidate-csv",
        type=Path,
        default=Path(
            "data/aerodynamics/raw/datcom/mach_grid/"
            "b777_like_derivative_datcom_candidate_mach_grid.csv"
        ),
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
        default=Path("data/aerodynamics/validation/longitudinal_modal_validation_cases.csv"),
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("docs/longitudinal_modal_validation_report.md"),
    )
    return parser.parse_args()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"CSV file is empty: {path}")
    return rows


def read_trim_cases(path: Path) -> list[ModalTrimCase]:
    cases: list[ModalTrimCase] = []
    for row in read_csv(path):
        if row["source_id"] != TRIM_SOURCE_ID:
            raise ValueError(f"Unexpected trim source id in {path}: {row['source_id']}")
        if row["status"] != "pass":
            raise ValueError(f"Trim case is not pass: {row['case_id']}")
        cases.append(
            ModalTrimCase(
                case_id=row["case_id"],
                h_m=float(row["h_m"]),
                mach=float(row["mach"]),
                mass_kg=float(row["mass_kg"]),
                alpha_rad=math.radians(float(row["alpha_deg"])),
                theta_rad=math.radians(float(row["theta_deg"])),
                delta_e_rad=math.radians(float(row["delta_e_deg"])),
                velocity_mps=float(row["velocity_mps"]),
                thrust_required_N=float(row["thrust_required_N"]),
            )
        )
    return cases


def read_crm_grid(path: Path) -> list[dict[str, float | str]]:
    rows: list[dict[str, float | str]] = []
    for row in read_csv(path):
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
    return rows


def read_candidate_grid(path: Path, coefficients: set[str]) -> list[dict[str, float | str]]:
    rows: list[dict[str, float | str]] = []
    for row in read_csv(path):
        if row["coefficient"] not in coefficients:
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
        raise ValueError(f"Candidate grid has no requested coefficients: {path}")
    return rows


def sorted_unique(values: list[float], tolerance: float = 1.0e-10) -> list[float]:
    result: list[float] = []
    for value in sorted(values):
        if not result or abs(value - result[-1]) > tolerance:
            result.append(value)
    return result


def bracket_index(grid: list[float], value: float, label: str) -> int:
    if value < grid[0] - 1.0e-10 or value > grid[-1] + 1.0e-10:
        raise ValueError(
            f"{label}={value:.10g} is outside [{grid[0]:.10g}, {grid[-1]:.10g}]"
        )
    value = min(max(value, grid[0]), grid[-1])
    if value <= grid[0]:
        return 0
    if value >= grid[-1]:
        return len(grid) - 2
    for idx in range(len(grid) - 1):
        if grid[idx] <= value <= grid[idx + 1]:
            return idx
    raise ValueError(f"Could not bracket {label}={value:.10g}")


def lerp(x0: float, y0: float, x1: float, y1: float, x: float) -> float:
    if abs(x1 - x0) < 1.0e-12:
        return y0
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def crm_value(
    rows: list[dict[str, float | str]],
    mach: float,
    alpha_rad: float,
    coefficient: str,
) -> float:
    mach_grid = sorted_unique([float(row["Mach"]) for row in rows])
    alpha_grid = sorted_unique([float(row["alpha_deg"]) for row in rows])
    alpha_deg = math.degrees(alpha_rad)
    mach = min(max(mach, mach_grid[0]), mach_grid[-1])
    alpha_deg = min(max(alpha_deg, alpha_grid[0]), alpha_grid[-1])
    mach_idx = bracket_index(mach_grid, mach, "CRM Mach")
    alpha_idx = bracket_index(alpha_grid, alpha_deg, "CRM alpha")

    def value_at_grid(mach_value: float, alpha_value: float) -> float:
        for row in rows:
            if (
                abs(float(row["Mach"]) - mach_value) < 1.0e-8
                and abs(float(row["alpha_deg"]) - alpha_value) < 1.0e-10
            ):
                return float(row[coefficient])
        raise ValueError(
            f"Missing CRM value Mach={mach_value:.10g}, "
            f"alpha={alpha_value:.10g}, coefficient={coefficient}"
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


def mach_candidate_value(
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
        raise ValueError(f"Missing candidate coefficient {coefficient}")
    mach_grid = [mach_value for mach_value, _ in samples]
    mach = min(max(mach, mach_grid[0]), mach_grid[-1])
    idx = bracket_index(mach_grid, mach, f"{coefficient} Mach")
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


def longitudinal_coefficients(
    crm_rows: list[dict[str, float | str]],
    derivative_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
    mach: float,
    alpha_rad: float,
    q_radps: float,
    delta_e_rad: float,
    velocity_mps: float,
) -> tuple[float, float, float]:
    q_hat = q_radps * CBAR_M / (2.0 * max(velocity_mps, 1.0))
    cl = (
        crm_value(crm_rows, mach, alpha_rad, "CL")
        + mach_candidate_value(control_rows, mach, "CL_delta_e") * delta_e_rad
        + mach_candidate_value(derivative_rows, mach, "CL_q") * q_hat
    )
    cd = (
        crm_value(crm_rows, mach, alpha_rad, "CD")
        + mach_candidate_value(control_rows, mach, "CD_delta_e")
        * delta_e_rad
        * delta_e_rad
    )
    cm = (
        crm_value(crm_rows, mach, alpha_rad, "Cm")
        + mach_candidate_value(control_rows, mach, "Cm_delta_e") * delta_e_rad
        + mach_candidate_value(derivative_rows, mach, "Cm_q") * q_hat
    )
    return cl, cd, cm


def iyy_kgm2(mass_kg: float) -> float:
    effective_half_length_m = FUSELAGE_LENGTH_M / 2.0
    ky_m = math.sqrt(
        (effective_half_length_m * effective_half_length_m
         + EFFECTIVE_VERTICAL_RADIUS_M * EFFECTIVE_VERTICAL_RADIUS_M)
        / 5.0
    )
    return mass_kg * ky_m * ky_m


def state_is_inside_data_domain(
    x: np.ndarray,
    case: ModalTrimCase,
    crm_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
) -> bool:
    _, a_mps = isa_atmosphere(case.h_m)
    velocity_mps = float(math.hypot(float(x[0]), float(x[1])))
    mach = velocity_mps / a_mps
    alpha_deg = math.degrees(math.atan2(float(x[1]), float(x[0])))
    crm_mach_grid = sorted_unique([float(row["Mach"]) for row in crm_rows])
    crm_alpha_grid = sorted_unique([float(row["alpha_deg"]) for row in crm_rows])
    control_mach_grid = sorted_unique([float(row["mach"]) for row in control_rows])
    return (
        crm_mach_grid[0] - 1.0e-10 <= mach <= crm_mach_grid[-1] + 1.0e-10
        and control_mach_grid[0] - 1.0e-10 <= mach <= control_mach_grid[-1] + 1.0e-10
        and crm_alpha_grid[0] - 1.0e-10 <= alpha_deg <= crm_alpha_grid[-1] + 1.0e-10
    )


def longitudinal_dynamics(
    x: np.ndarray,
    case: ModalTrimCase,
    crm_rows: list[dict[str, float | str]],
    derivative_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
) -> np.ndarray:
    u_mps, w_mps, q_radps, theta_rad = [float(value) for value in x]
    rho_kgm3, a_mps = isa_atmosphere(case.h_m)
    velocity_mps = max(math.hypot(u_mps, w_mps), 1.0)
    mach = velocity_mps / a_mps
    alpha_rad = math.atan2(w_mps, u_mps)
    qbar_Pa = 0.5 * rho_kgm3 * velocity_mps * velocity_mps

    cl, cd, cm = longitudinal_coefficients(
        crm_rows,
        derivative_rows,
        control_rows,
        mach,
        alpha_rad,
        q_radps,
        case.delta_e_rad,
        velocity_mps,
    )
    aero_x_N = qbar_Pa * SREF_M2 * (
        -cd * math.cos(alpha_rad) + cl * math.sin(alpha_rad)
    )
    aero_z_N = qbar_Pa * SREF_M2 * (
        -cd * math.sin(alpha_rad) - cl * math.cos(alpha_rad)
    )
    moment_y_Nm = qbar_Pa * SREF_M2 * CBAR_M * cm

    u_dot = (
        (aero_x_N + case.thrust_required_N) / case.mass_kg
        - STANDARD_GRAVITY_MPS2 * math.sin(theta_rad)
        - q_radps * w_mps
    )
    w_dot = (
        aero_z_N / case.mass_kg
        + STANDARD_GRAVITY_MPS2 * math.cos(theta_rad)
        + q_radps * u_mps
    )
    q_dot = moment_y_Nm / iyy_kgm2(case.mass_kg)
    theta_dot = q_radps
    return np.array([u_dot, w_dot, q_dot, theta_dot], dtype=float)


def trim_state(case: ModalTrimCase) -> np.ndarray:
    return np.array(
        [
            case.velocity_mps * math.cos(case.alpha_rad),
            case.velocity_mps * math.sin(case.alpha_rad),
            0.0,
            case.theta_rad,
        ],
        dtype=float,
    )


def finite_difference_column(
    x0: np.ndarray,
    idx: int,
    step: float,
    case: ModalTrimCase,
    crm_rows: list[dict[str, float | str]],
    derivative_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
) -> tuple[np.ndarray, str]:
    perturb = np.zeros_like(x0)
    perturb[idx] = step
    plus = x0 + perturb
    minus = x0 - perturb
    base = longitudinal_dynamics(x0, case, crm_rows, derivative_rows, control_rows)

    plus_ok = state_is_inside_data_domain(plus, case, crm_rows, control_rows)
    minus_ok = state_is_inside_data_domain(minus, case, crm_rows, control_rows)
    if plus_ok and minus_ok:
        f_plus = longitudinal_dynamics(plus, case, crm_rows, derivative_rows, control_rows)
        f_minus = longitudinal_dynamics(minus, case, crm_rows, derivative_rows, control_rows)
        return (f_plus - f_minus) / (2.0 * step), "central"
    if plus_ok:
        f_plus = longitudinal_dynamics(plus, case, crm_rows, derivative_rows, control_rows)
        return (f_plus - base) / step, "forward"
    if minus_ok:
        f_minus = longitudinal_dynamics(minus, case, crm_rows, derivative_rows, control_rows)
        return (base - f_minus) / step, "backward"
    raise ValueError(
        f"Cannot finite-difference {STATE_LABELS[idx]} for {case.case_id} "
        "without leaving the validated data domain."
    )


def linearize_case(
    case: ModalTrimCase,
    crm_rows: list[dict[str, float | str]],
    derivative_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
) -> tuple[np.ndarray, np.ndarray, list[str]]:
    x0 = trim_state(case)
    residual = longitudinal_dynamics(x0, case, crm_rows, derivative_rows, control_rows)
    a_matrix = np.zeros((4, 4), dtype=float)
    methods: list[str] = []
    for idx, step in enumerate(FINITE_DIFFERENCE_STEPS):
        column, method = finite_difference_column(
            x0, idx, float(step), case, crm_rows, derivative_rows, control_rows
        )
        a_matrix[:, idx] = column
        methods.append(f"{STATE_LABELS[idx]}:{method}")
    return a_matrix, residual, methods


def classify_modes(eigenvalues: np.ndarray) -> list[tuple[str, complex, complex]]:
    positive_imag = sorted(
        [complex(value) for value in eigenvalues if value.imag > 1.0e-8],
        key=lambda value: abs(value),
    )
    if len(positive_imag) != 2:
        raise ValueError(
            "Expected two oscillatory longitudinal mode pairs; "
            f"found {len(positive_imag)}."
        )
    return [
        ("phugoid", positive_imag[0], complex(positive_imag[0].real, -positive_imag[0].imag)),
        (
            "short_period",
            positive_imag[1],
            complex(positive_imag[1].real, -positive_imag[1].imag),
        ),
    ]


def checks_for_mode(mode_id: str, real_part: float, imag_part: float, wn: float, zeta: float, period: float, residual_norm: float) -> dict[str, bool]:
    checks = {
        "stable_real_part": real_part < -1.0e-4,
        "oscillatory_pair": imag_part > 1.0e-4,
        "trim_residual": residual_norm < 1.0e-6,
    }
    if mode_id == "phugoid":
        checks.update(
            {
                "phugoid_frequency": 0.02 <= wn <= 0.12,
                "phugoid_damping": 0.005 <= zeta <= 0.20,
                "phugoid_period": 50.0 <= period <= 200.0,
            }
        )
    elif mode_id == "short_period":
        checks.update(
            {
                "short_period_frequency": 0.40 <= wn <= 1.40,
                "short_period_damping": 0.20 <= zeta <= 0.90,
                "short_period_period": 4.0 <= period <= 16.0,
            }
        )
    else:
        raise ValueError(f"Unknown mode id: {mode_id}")
    return checks


def validate_case(
    case: ModalTrimCase,
    crm_rows: list[dict[str, float | str]],
    derivative_rows: list[dict[str, float | str]],
    control_rows: list[dict[str, float | str]],
) -> list[ModeResult]:
    a_matrix, residual, methods = linearize_case(case, crm_rows, derivative_rows, control_rows)
    eigenvalues = np.linalg.eigvals(a_matrix)
    residual_norm = float(np.linalg.norm(residual))
    mode_pairs = classify_modes(eigenvalues)
    x0 = trim_state(case)

    results: list[ModeResult] = []
    for mode_id, eigen_1, eigen_2 in mode_pairs:
        wn = abs(eigen_1)
        zeta = -eigen_1.real / wn
        period_s = 2.0 * math.pi / abs(eigen_1.imag)
        time_to_half_s = math.log(2.0) / (-eigen_1.real)
        checks = checks_for_mode(
            mode_id,
            eigen_1.real,
            abs(eigen_1.imag),
            wn,
            zeta,
            period_s,
            residual_norm,
        )
        failed = [name for name, passed in checks.items() if not passed]
        results.append(
            ModeResult(
                case_id=case.case_id,
                mode_id=mode_id,
                status="pass" if not failed else "fail",
                mach=case.mach,
                alpha_deg=math.degrees(case.alpha_rad),
                delta_e_deg=math.degrees(case.delta_e_rad),
                u_trim_mps=float(x0[0]),
                w_trim_mps=float(x0[1]),
                theta_deg=math.degrees(case.theta_rad),
                eigen_real_1=eigen_1.real,
                eigen_imag_1=eigen_1.imag,
                eigen_real_2=eigen_2.real,
                eigen_imag_2=eigen_2.imag,
                natural_frequency_radps=wn,
                damping_ratio=zeta,
                period_s=period_s,
                time_to_half_s=time_to_half_s,
                residual_norm=residual_norm,
                linearization_methods=";".join(methods),
                checks="all-pass" if not failed else ";".join(failed),
                notes=(
                    "Restricted longitudinal [u,w,q,theta] finite-difference "
                    "linearisation using CRM clean CL/CD/Cm, DATCOM CL_q/Cm_q "
                    "and DATCOM elevator candidates; thrust is fixed at the "
                    "trim static-equivalent value."
                ),
            )
        )
    return results


def write_case_csv(path: Path, results: list[ModeResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "source_id",
        "case_id",
        "mode_id",
        "status",
        "mach",
        "alpha_deg",
        "delta_e_deg",
        "u_trim_mps",
        "w_trim_mps",
        "theta_deg",
        "eigen_real_1",
        "eigen_imag_1",
        "eigen_real_2",
        "eigen_imag_2",
        "natural_frequency_radps",
        "damping_ratio",
        "period_s",
        "time_to_half_s",
        "residual_norm",
        "linearization_methods",
        "checks",
        "notes",
    ]
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for result in results:
            writer.writerow(
                {
                    "source_id": MODAL_SOURCE_ID,
                    "case_id": result.case_id,
                    "mode_id": result.mode_id,
                    "status": result.status,
                    "mach": f"{result.mach:.5f}",
                    "alpha_deg": f"{result.alpha_deg:.8f}",
                    "delta_e_deg": f"{result.delta_e_deg:.8f}",
                    "u_trim_mps": f"{result.u_trim_mps:.8f}",
                    "w_trim_mps": f"{result.w_trim_mps:.8f}",
                    "theta_deg": f"{result.theta_deg:.8f}",
                    "eigen_real_1": f"{result.eigen_real_1:.10f}",
                    "eigen_imag_1": f"{result.eigen_imag_1:.10f}",
                    "eigen_real_2": f"{result.eigen_real_2:.10f}",
                    "eigen_imag_2": f"{result.eigen_imag_2:.10f}",
                    "natural_frequency_radps": f"{result.natural_frequency_radps:.10f}",
                    "damping_ratio": f"{result.damping_ratio:.10f}",
                    "period_s": f"{result.period_s:.6f}",
                    "time_to_half_s": f"{result.time_to_half_s:.6f}",
                    "residual_norm": f"{result.residual_norm:.8e}",
                    "linearization_methods": result.linearization_methods,
                    "checks": result.checks,
                    "notes": result.notes,
                }
            )


def write_report(path: Path, results: list[ModeResult], case_csv: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    passed = sum(1 for result in results if result.status == "pass")
    failed = len(results) - passed
    case_count = len({result.case_id for result in results})
    lines = [
        "# Longitudinal Modal Validation Report",
        "",
        f"source_id={MODAL_SOURCE_ID}",
        f"trim_source_id={TRIM_SOURCE_ID}",
        f"crm_source_id={CRM_SOURCE_ID}",
        f"derivative_source_id={DERIVATIVE_SOURCE_ID}",
        f"control_source_id={CONTROL_SOURCE_ID}",
        f"case_count={case_count}",
        f"mode_pair_count={len(results)}",
        f"pass_count={passed}",
        f"fail_count={failed}",
        f"case_table={case_csv.as_posix()}",
        "",
        "## Scope",
        "",
        "This validation covers restricted clean-cruise longitudinal modes for",
        "the DATCOM candidate aerodynamic path. The state vector is",
        "`[u, w, q, theta]`, the controls are held at their trim values and",
        "thrust is held at the static-equivalent trim value. The linear model",
        "uses CRM clean `CL`, `CD` and `Cm`, DATCOM candidate `CL_q` and",
        "`Cm_q`, and DATCOM elevator candidates.",
        "",
        "This is not yet a full six-degree-of-freedom modal validation. It does",
        "not include engine pitching moments, actuator dynamics, lateral-",
        "directional modes or coupled propulsion states.",
        "",
        "## Results",
        "",
        "| Case | Mode | real 1/s | imag rad/s | wn rad/s | zeta | period s | status |",
        "|---|---|---:|---:|---:|---:|---:|---|",
    ]
    for result in results:
        lines.append(
            "| {case_id} | {mode_id} | {real:.6f} | {imag:.6f} | "
            "{wn:.6f} | {zeta:.5f} | {period:.2f} | {status} |".format(
                case_id=result.case_id,
                mode_id=result.mode_id,
                real=result.eigen_real_1,
                imag=abs(result.eigen_imag_1),
                wn=result.natural_frequency_radps,
                zeta=result.damping_ratio,
                period=result.period_s,
                status=result.status,
            )
        )

    lines.extend(
        [
            "",
            "## Acceptance Criteria",
            "",
            "- Each trim case must produce two stable oscillatory longitudinal mode pairs.",
            "- Phugoid natural frequency must be between 0.02 and 0.12 rad/s.",
            "- Phugoid damping ratio must be between 0.005 and 0.20.",
            "- Phugoid period must be between 50 s and 200 s.",
            "- Short-period natural frequency must be between 0.40 and 1.40 rad/s.",
            "- Short-period damping ratio must be between 0.20 and 0.90.",
            "- Short-period period must be between 4 s and 16 s.",
            "- Linearisation residual norm at the trim point must be below 1e-6.",
            "",
            "## Promotion Marker Recommendation",
            "",
            (
                "DATCOM_PROMOTION_MODAL_VALIDATED=true"
                if failed == 0
                else "DATCOM_PROMOTION_MODAL_VALIDATED=false"
            ),
            "",
        ]
    )
    path.write_text("\n".join(lines))


def main() -> int:
    args = parse_args()
    trim_cases = read_trim_cases(args.trim_case_csv)
    crm_rows = read_crm_grid(args.crm_grid_csv)
    derivative_rows = read_candidate_grid(args.derivative_candidate_csv, {"CL_q", "Cm_q"})
    control_rows = read_candidate_grid(
        args.control_candidate_csv,
        {"CL_delta_e", "Cm_delta_e", "CD_delta_e"},
    )

    results: list[ModeResult] = []
    for case in trim_cases:
        results.extend(validate_case(case, crm_rows, derivative_rows, control_rows))

    write_case_csv(args.case_csv, results)
    write_report(args.report, results, args.case_csv)

    failed = [f"{result.case_id}:{result.mode_id}" for result in results if result.status != "pass"]
    if failed:
        print("Longitudinal modal validation failed for: " + ", ".join(failed))
        return 1

    print(f"Longitudinal modal validation passed for {len(trim_cases)} cases.")
    print(f"Case table written to {args.case_csv}")
    print(f"Report written to {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
