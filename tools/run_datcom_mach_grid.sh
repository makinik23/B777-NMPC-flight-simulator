#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_DIR="$ROOT_DIR/data/aerodynamics/raw/datcom/mach_grid"
OUTPUT_DIR="$ROOT_DIR/data/aerodynamics/raw/datcom/runs"
RUN_INDEX="${DATCOM_MACH_GRID_INDEX_FILE:-$INPUT_DIR/b777_like_datcom_mach_grid_run_index.csv}"
CONSOLIDATED_FILE="${DATCOM_MACH_GRID_TABLE_FILE:-$INPUT_DIR/b777_like_derivative_datcom_candidate_mach_grid.csv}"
CONSOLIDATION_REPORT="${DATCOM_MACH_GRID_REPORT_FILE:-$INPUT_DIR/b777_like_derivative_datcom_candidate_mach_grid_report.txt}"
PROMOTION_GATE_FILE="${DATCOM_PROMOTION_GATE_FILE:-$INPUT_DIR/b777_like_derivative_datcom_promotion_gates.csv}"
PROMOTION_GATE_REPORT="${DATCOM_PROMOTION_GATE_REPORT:-$INPUT_DIR/b777_like_derivative_datcom_promotion_gates.txt}"
VALIDATION_REPORT="${DATCOM_VALIDATION_REPORT:-$ROOT_DIR/docs/validation_report.md}"
CONTROL_CANDIDATE_FILE="${DATCOM_CONTROL_GRID_TABLE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/control_grid/b777_like_control_derivative_datcom_candidate_mach_grid.csv}"
GAP_FILL_FILE="${DATCOM_GAP_FILL_TABLE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid.csv}"
GAP_FILL_REPORT="${DATCOM_GAP_FILL_REPORT_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid_report.txt}"

CASES=(
    "m030|0.30|b777_like_static_damping_m030.inp"
    "m050|0.50|b777_like_static_damping_m050.inp"
    "m060|0.60|b777_like_static_damping_m060.inp"
    "m070|0.70|b777_like_static_damping_m070.inp"
    "m080|0.80|b777_like_static_damping_m080.inp"
)

rel_path() {
    local path="$1"
    if [[ "$path" == "$ROOT_DIR/"* ]]; then
        printf "%s" "${path#"$ROOT_DIR"/}"
    else
        printf "%s" "$path"
    fi
}

quality_value() {
    local key="$1"
    local file="$2"
    sed -n "s/^${key}=//p" "$file" | head -n 1
}

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
printf "case_id,mach,input_file,run_dir,candidate_file,extraction_report,datcom_exit_status,error_count,warning_count\n" > "$RUN_INDEX"

for case_spec in "${CASES[@]}"; do
    IFS='|' read -r case_id mach input_name <<< "$case_spec"

    input_file="$INPUT_DIR/$input_name"
    run_dir="$OUTPUT_DIR/b777_like_static_damping_${case_id}_v0"
    candidate_file="$INPUT_DIR/b777_like_derivative_datcom_candidate_${case_id}.csv"
    extraction_report="$run_dir/datcom_extraction_report.txt"

    echo "Running Digital DATCOM Mach ${mach} (${case_id})"
    DATCOM_CANDIDATE_FILE="$candidate_file" \
        DATCOM_EXTRACTION_REPORT="$extraction_report" \
        "$ROOT_DIR/tools/run_digital_datcom.sh" "$input_file" "$run_dir"

    run_quality="$run_dir/run_quality.txt"
    datcom_exit_status="$(quality_value "datcom_exit_status" "$run_quality")"
    error_count="$(quality_value "error_count" "$run_quality")"
    warning_count="$(quality_value "warning_count" "$run_quality")"

    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$case_id" \
        "$mach" \
        "$(rel_path "$input_file")" \
        "$(rel_path "$run_dir")" \
        "$(rel_path "$candidate_file")" \
        "$(rel_path "$extraction_report")" \
        "$datcom_exit_status" \
        "$error_count" \
        "$warning_count" >> "$RUN_INDEX"
done

python3 "$ROOT_DIR/tools/build_datcom_mach_grid_table.py" \
    "$RUN_INDEX" \
    "$CONSOLIDATED_FILE" \
    --report "$CONSOLIDATION_REPORT"

SUPPLEMENTAL_ARGS=()
if [[ -f "$CONTROL_CANDIDATE_FILE" ]]; then
    python3 "$ROOT_DIR/tools/build_datcom_gap_fill_candidates.py" \
        "$CONSOLIDATED_FILE" \
        "$CONTROL_CANDIDATE_FILE" \
        "$GAP_FILL_FILE" \
        --report "$GAP_FILL_REPORT"
    SUPPLEMENTAL_ARGS=(--supplemental-candidate-csv "$GAP_FILL_FILE")
fi

python3 "$ROOT_DIR/tools/evaluate_datcom_promotion_gates.py" \
    "$CONSOLIDATED_FILE" \
    "$ROOT_DIR/data/aerodynamics/raw/datcom/b777_like_derivative_seed.csv" \
    "$RUN_INDEX" \
    "$PROMOTION_GATE_FILE" \
    --report "$PROMOTION_GATE_REPORT" \
    --validation-report "$VALIDATION_REPORT" \
    --control-candidate-csv "$CONTROL_CANDIDATE_FILE" \
    "${SUPPLEMENTAL_ARGS[@]}"

echo "Digital DATCOM Mach-grid index written to $RUN_INDEX"
echo "Digital DATCOM Mach-grid candidate table written to $CONSOLIDATED_FILE"
if [[ -f "$GAP_FILL_FILE" ]]; then
    echo "Digital DATCOM derived gap-fill table written to $GAP_FILL_FILE"
fi
echo "Digital DATCOM promotion gate report written to $PROMOTION_GATE_REPORT"
