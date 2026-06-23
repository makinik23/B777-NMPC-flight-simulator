#!/usr/bin/env python3
"""Evaluate promotion readiness for the DATCOM Mach-grid candidate table."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


EXPECTED_GRID_SOURCE_ID = "DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0"
EXPECTED_MACH_GRID = (0.30, 0.50, 0.60, 0.70, 0.80)
EXPECTED_INTERPOLATION_POLICY = (
    "linear in Mach inside committed grid; no extrapolation before validation"
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


@dataclass(frozen=True)
class GateResult:
    gate_id: str
    status: str
    severity: str
    details: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate DATCOM Mach-grid promotion gates."
    )
    parser.add_argument("candidate_csv", type=Path)
    parser.add_argument("active_seed_csv", type=Path)
    parser.add_argument("run_index_csv", type=Path)
    parser.add_argument("gate_csv", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--validation-report", type=Path, default=None)
    parser.add_argument("--control-candidate-csv", type=Path, default=None)
    parser.add_argument("--supplemental-candidate-csv", type=Path, action="append", default=[])
    return parser.parse_args()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def gate(gate_id: str, passed: bool, details: str, severity: str = "blocker") -> GateResult:
    return GateResult(gate_id, "pass" if passed else "fail", severity, details)


def info(gate_id: str, status: str, details: str, severity: str = "review") -> GateResult:
    return GateResult(gate_id, status, severity, details)


def coefficient_key(row: dict[str, str]) -> str:
    return f"{row['group']}.{row['coefficient']}"


def active_coefficients(rows: list[dict[str, str]]) -> set[str]:
    return {coefficient_key(row) for row in rows}


def candidate_coefficients(rows: list[dict[str, str]]) -> set[str]:
    return {coefficient_key(row) for row in rows}


def unique_values(rows: list[dict[str, str]], column: str) -> list[str]:
    values: list[str] = []
    for row in rows:
        value = row[column]
        if value not in values:
            values.append(value)
    return values


def has_expected_sign(coefficient: str, value: float) -> bool:
    expected = EXPECTED_SIGNS.get(coefficient)
    if expected is None:
        return True
    return value * expected > 0.0


def validation_marker_present(path: Path | None, marker: str) -> bool:
    if path is None or not path.is_file():
        return False
    text = path.read_text(errors="replace")
    return marker in text


def evaluate(
    candidate_rows: list[dict[str, str]],
    active_rows: list[dict[str, str]],
    run_rows: list[dict[str, str]],
    validation_report: Path | None,
    control_candidate_rows: list[dict[str, str]] | None = None,
    supplemental_candidate_rows: list[dict[str, str]] | None = None,
) -> list[GateResult]:
    results: list[GateResult] = []
    control_candidate_rows = control_candidate_rows or []
    supplemental_candidate_rows = supplemental_candidate_rows or []

    candidate_sources = unique_values(candidate_rows, "source_id")
    results.append(
        gate(
            "source_id",
            candidate_sources == [EXPECTED_GRID_SOURCE_ID],
            f"candidate source ids: {', '.join(candidate_sources)}",
        )
    )

    case_source_count = len(unique_values(candidate_rows, "case_source_id"))
    results.append(
        gate(
            "case_traceability",
            case_source_count == len(EXPECTED_MACH_GRID),
            f"case_source_id count={case_source_count}; expected={len(EXPECTED_MACH_GRID)}",
        )
    )

    run_quality_ok = all(
        row["datcom_exit_status"] == "0" and row["error_count"] == "0"
        for row in run_rows
    )
    results.append(
        gate(
            "run_quality",
            run_quality_ok,
            "all DATCOM Mach-grid runs must have datcom_exit_status=0 and error_count=0",
        )
    )

    warning_counts = {row["warning_count"] for row in run_rows}
    results.append(
        info(
            "warning_review",
            "review" if warning_counts != {"0"} else "pass",
            f"warning_count values: {', '.join(sorted(warning_counts))}; known DATCOM body-alone dynamic-derivative warning must remain documented",
            "review",
        )
    )

    mach_values = sorted({round(float(row["mach"]), 2) for row in candidate_rows})
    expected_mach_values = [round(value, 2) for value in EXPECTED_MACH_GRID]
    results.append(
        gate(
            "mach_grid",
            mach_values == expected_mach_values,
            f"candidate Mach grid={mach_values}; expected={expected_mach_values}",
        )
    )

    row_count_ok = len(candidate_rows) == len(EXPECTED_MACH_GRID) * 10
    results.append(
        gate(
            "row_count",
            row_count_ok,
            f"candidate row count={len(candidate_rows)}; expected={len(EXPECTED_MACH_GRID) * 10}",
        )
    )

    status_values = unique_values(candidate_rows, "status")
    results.append(
        gate(
            "candidate_status",
            status_values == ["candidate-pending-review"],
            f"candidate statuses: {', '.join(status_values)}",
        )
    )

    policies = unique_values(candidate_rows, "interpolation_policy")
    results.append(
        gate(
            "interpolation_policy",
            policies == [EXPECTED_INTERPOLATION_POLICY],
            f"interpolation policies: {' | '.join(policies)}",
        )
    )

    sign_failures = []
    for row in candidate_rows:
        value = float(row["value"])
        if not has_expected_sign(row["coefficient"], value):
            sign_failures.append(f"{row['case_id']}:{row['coefficient']}={value}")
    results.append(
        gate(
            "expected_signs",
            not sign_failures,
            "all expected static and damping signs pass" if not sign_failures else "; ".join(sign_failures),
        )
    )

    candidate_confidences = [float(row["confidence"]) for row in candidate_rows]
    confidence_ok = min(candidate_confidences) >= 0.30
    results.append(
        gate(
            "candidate_confidence_floor",
            confidence_ok,
            f"minimum candidate confidence={min(candidate_confidences):.2f}; required >=0.30 before promotion",
        )
    )

    active_keys = active_coefficients(active_rows)
    coverage_candidate_rows = candidate_rows + control_candidate_rows + supplemental_candidate_rows
    candidate_keys = candidate_coefficients(coverage_candidate_rows)
    missing_from_candidate = sorted(active_keys - candidate_keys)
    covered_active_keys = sorted(active_keys & candidate_keys)
    results.append(
        gate(
            "active_table_coverage",
            not missing_from_candidate,
            "candidate active-table coefficients: "
            + (", ".join(covered_active_keys) if covered_active_keys else "none")
            + "; missing: "
            + (", ".join(missing_from_candidate) if missing_from_candidate else "none"),
        )
    )

    control_keys = sorted(key for key in active_keys if key.startswith("control."))
    candidate_control_keys = sorted(key for key in candidate_keys if key.startswith("control."))
    missing_control_keys = sorted(set(control_keys) - set(candidate_control_keys))
    results.append(
        gate(
            "control_derivatives",
            candidate_control_keys == control_keys,
            "candidate control coefficients: "
            + (", ".join(candidate_control_keys) if candidate_control_keys else "none")
            + "; required: "
            + ", ".join(control_keys)
            + "; missing: "
            + (", ".join(missing_control_keys) if missing_control_keys else "none"),
        )
    )

    trim_ok = validation_marker_present(validation_report, "DATCOM_PROMOTION_TRIM_VALIDATED=true")
    results.append(
        gate(
            "trim_validation",
            trim_ok,
            "requires DATCOM_PROMOTION_TRIM_VALIDATED=true in validation report",
        )
    )

    modal_ok = validation_marker_present(validation_report, "DATCOM_PROMOTION_MODAL_VALIDATED=true")
    results.append(
        gate(
            "modal_validation",
            modal_ok,
            "requires DATCOM_PROMOTION_MODAL_VALIDATED=true in validation report",
        )
    )

    return results


def write_gate_csv(path: Path, results: list[GateResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["gate_id", "status", "severity", "details"],
            lineterminator="\n",
        )
        writer.writeheader()
        for result in results:
            writer.writerow(result.__dict__)


def write_report(path: Path, results: list[GateResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    blockers = [result for result in results if result.status != "pass" and result.severity == "blocker"]
    reviews = [result for result in results if result.status != "pass" and result.severity == "review"]
    promotion_allowed = not blockers and not reviews

    lines = [
        "source_id=DIGITAL_DATCOM_B777_LIKE_MACH_GRID_CANDIDATE_V0",
        f"promotion_allowed={'true' if promotion_allowed else 'false'}",
        f"blocker_count={len(blockers)}",
        f"review_count={len(reviews)}",
        "",
        "Gate Results",
    ]
    for result in results:
        lines.append(
            f"{result.gate_id}: status={result.status}; "
            f"severity={result.severity}; {result.details}"
        )

    if blockers:
        lines.extend(["", "Blocking Gates"])
        for result in blockers:
            lines.append(f"- {result.gate_id}: {result.details}")

    if reviews:
        lines.extend(["", "Review Gates"])
        for result in reviews:
            lines.append(f"- {result.gate_id}: {result.details}")

    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    candidate_rows = read_csv(args.candidate_csv)
    active_rows = read_csv(args.active_seed_csv)
    run_rows = read_csv(args.run_index_csv)
    control_candidate_rows = (
        read_csv(args.control_candidate_csv)
        if args.control_candidate_csv is not None and args.control_candidate_csv.is_file()
        else []
    )
    supplemental_candidate_rows: list[dict[str, str]] = []
    for supplemental_path in args.supplemental_candidate_csv:
        if supplemental_path.is_file():
            supplemental_candidate_rows.extend(read_csv(supplemental_path))
    results = evaluate(
        candidate_rows,
        active_rows,
        run_rows,
        args.validation_report,
        control_candidate_rows,
        supplemental_candidate_rows,
    )
    write_gate_csv(args.gate_csv, results)
    write_report(args.report, results)

    blockers = sum(1 for result in results if result.status != "pass" and result.severity == "blocker")
    reviews = sum(1 for result in results if result.status != "pass" and result.severity == "review")
    print(
        "DATCOM promotion gates evaluated: "
        f"{len(results)} gates, {blockers} blockers, {reviews} review items"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
