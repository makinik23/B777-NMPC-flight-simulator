#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_DIR="$ROOT_DIR/data/aerodynamics/raw/datcom/control_grid"
OUTPUT_DIR="$ROOT_DIR/data/aerodynamics/raw/datcom/runs"
RUN_INDEX="${DATCOM_CONTROL_GRID_INDEX_FILE:-$INPUT_DIR/b777_like_datcom_control_grid_run_index.csv}"
CONSOLIDATED_FILE="${DATCOM_CONTROL_GRID_TABLE_FILE:-$INPUT_DIR/b777_like_control_derivative_datcom_candidate_mach_grid.csv}"
CONSOLIDATION_REPORT="${DATCOM_CONTROL_GRID_REPORT_FILE:-$INPUT_DIR/b777_like_control_derivative_datcom_candidate_mach_grid_report.txt}"
CONTROL_EXTRACTOR="$ROOT_DIR/tools/extract_datcom_control_derivatives.py"
MACH_CANDIDATE_FILE="${DATCOM_MACH_GRID_TABLE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_candidate_mach_grid.csv}"
MACH_RUN_INDEX="${DATCOM_MACH_GRID_INDEX_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/mach_grid/b777_like_datcom_mach_grid_run_index.csv}"
PROMOTION_GATE_FILE="${DATCOM_PROMOTION_GATE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_promotion_gates.csv}"
PROMOTION_GATE_REPORT="${DATCOM_PROMOTION_GATE_REPORT:-$ROOT_DIR/data/aerodynamics/raw/datcom/mach_grid/b777_like_derivative_datcom_promotion_gates.txt}"
VALIDATION_REPORT="${DATCOM_VALIDATION_REPORT:-$ROOT_DIR/docs/validation_report.md}"
GAP_FILL_FILE="${DATCOM_GAP_FILL_TABLE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid.csv}"
GAP_FILL_REPORT="${DATCOM_GAP_FILL_REPORT_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/derived_gap_fill/b777_like_derivative_gap_fill_candidate_mach_grid_report.txt}"

CASES=(
    "elevator_m030|0.30|elevator|b777_like_control_elevator_m030.inp"
    "elevator_m050|0.50|elevator|b777_like_control_elevator_m050.inp"
    "elevator_m060|0.60|elevator|b777_like_control_elevator_m060.inp"
    "elevator_m070|0.70|elevator|b777_like_control_elevator_m070.inp"
    "elevator_m080|0.80|elevator|b777_like_control_elevator_m080.inp"
    "aileron_m030|0.30|aileron|b777_like_control_aileron_m030.inp"
    "aileron_m050|0.50|aileron|b777_like_control_aileron_m050.inp"
    "aileron_m060|0.60|aileron|b777_like_control_aileron_m060.inp"
    "aileron_m070|0.70|aileron|b777_like_control_aileron_m070.inp"
    "aileron_m080|0.80|aileron|b777_like_control_aileron_m080.inp"
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

python3 "$ROOT_DIR/tools/generate_datcom_control_grid.py"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
printf "case_id,mach,control_id,input_file,run_dir,candidate_file,extraction_report,datcom_exit_status,error_count,warning_count\n" > "$RUN_INDEX"

for case_spec in "${CASES[@]}"; do
    IFS='|' read -r case_id mach control_id input_name <<< "$case_spec"

    input_file="$INPUT_DIR/$input_name"
    run_dir="$OUTPUT_DIR/b777_like_control_${case_id}_v0"
    candidate_file="$INPUT_DIR/b777_like_control_derivative_datcom_candidate_${case_id}.csv"
    extraction_report="$run_dir/datcom_control_extraction_report.txt"

    echo "Running Digital DATCOM control ${control_id} Mach ${mach} (${case_id})"
    DATCOM_CANDIDATE_FILE="$candidate_file" \
        DATCOM_EXTRACTION_REPORT="$extraction_report" \
        DATCOM_EXTRACTOR="$CONTROL_EXTRACTOR" \
        "$ROOT_DIR/tools/run_digital_datcom.sh" "$input_file" "$run_dir"

    run_quality="$run_dir/run_quality.txt"
    datcom_exit_status="$(quality_value "datcom_exit_status" "$run_quality")"
    error_count="$(quality_value "error_count" "$run_quality")"
    warning_count="$(quality_value "warning_count" "$run_quality")"

    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$case_id" \
        "$mach" \
        "$control_id" \
        "$(rel_path "$input_file")" \
        "$(rel_path "$run_dir")" \
        "$(rel_path "$candidate_file")" \
        "$(rel_path "$extraction_report")" \
        "$datcom_exit_status" \
        "$error_count" \
        "$warning_count" >> "$RUN_INDEX"
done

python3 "$ROOT_DIR/tools/build_datcom_control_grid_table.py" \
    "$RUN_INDEX" \
    "$CONSOLIDATED_FILE" \
    --report "$CONSOLIDATION_REPORT"

if [[ -f "$MACH_CANDIDATE_FILE" ]]; then
    python3 "$ROOT_DIR/tools/build_datcom_gap_fill_candidates.py" \
        "$MACH_CANDIDATE_FILE" \
        "$CONSOLIDATED_FILE" \
        "$GAP_FILL_FILE" \
        --report "$GAP_FILL_REPORT"

    if [[ -f "$MACH_RUN_INDEX" ]]; then
        python3 "$ROOT_DIR/tools/evaluate_datcom_promotion_gates.py" \
            "$MACH_CANDIDATE_FILE" \
            "$ROOT_DIR/data/aerodynamics/raw/datcom/b777_like_derivative_seed.csv" \
            "$MACH_RUN_INDEX" \
            "$PROMOTION_GATE_FILE" \
            --report "$PROMOTION_GATE_REPORT" \
            --validation-report "$VALIDATION_REPORT" \
            --control-candidate-csv "$CONSOLIDATED_FILE" \
            --supplemental-candidate-csv "$GAP_FILL_FILE"
    fi
fi

echo "Digital DATCOM control-grid index written to $RUN_INDEX"
echo "Digital DATCOM control-grid candidate table written to $CONSOLIDATED_FILE"
echo "Digital DATCOM control-grid report written to $CONSOLIDATION_REPORT"
if [[ -f "$GAP_FILL_FILE" ]]; then
    echo "Digital DATCOM derived gap-fill table written to $GAP_FILL_FILE"
fi
if [[ -f "$PROMOTION_GATE_REPORT" ]]; then
    echo "Digital DATCOM promotion gate report written to $PROMOTION_GATE_REPORT"
fi
