#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_FILE="${1:-$ROOT_DIR/data/aerodynamics/raw/datcom/b777_like_digital_datcom_static_damping.inp}"
RUN_DIR="${2:-$ROOT_DIR/data/aerodynamics/raw/datcom/runs/b777_like_static_damping_v0}"
BUILD_DIR="${DATCOM_BUILD_DIR:-$ROOT_DIR/.cache/datcom}"
DATCOM_URL="${DATCOM_URL:-https://www.pdas.com/packages/datcom.zip}"
CANDIDATE_FILE="${DATCOM_CANDIDATE_FILE:-$ROOT_DIR/data/aerodynamics/raw/datcom/b777_like_derivative_datcom_candidate_m060.csv}"
EXTRACTION_REPORT="${DATCOM_EXTRACTION_REPORT:-$RUN_DIR/datcom_extraction_report.txt}"
EXTRACTOR="${DATCOM_EXTRACTOR:-$ROOT_DIR/tools/extract_datcom_derivatives.py}"

mkdir -p "$BUILD_DIR" "$RUN_DIR"

if [[ ! -f "$BUILD_DIR/datcom.f" ]]; then
    curl -L -o "$BUILD_DIR/datcom.zip" "$DATCOM_URL"
    unzip -q -o "$BUILD_DIR/datcom.zip" -d "$BUILD_DIR"
fi

if [[ ! -x "$BUILD_DIR/datcom.exe" || "$BUILD_DIR/datcom.f" -nt "$BUILD_DIR/datcom.exe" ]]; then
    gfortran -std=legacy "$BUILD_DIR/datcom.f" -o "$BUILD_DIR/datcom.exe" \
        > "$BUILD_DIR/build.log" 2>&1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cp "$INPUT_FILE" "$WORK_DIR/input.inp"

(
    cd "$WORK_DIR"
    set +e
    printf 'input.inp\n' | "$BUILD_DIR/datcom.exe" > datcom.console 2>&1
    echo "$?" > datcom.status
)

cp "$WORK_DIR/input.inp" "$RUN_DIR/$(basename "$INPUT_FILE")"
if [[ -f "$WORK_DIR/datcom.out" ]]; then
    cp "$WORK_DIR/datcom.out" "$RUN_DIR/datcom.out"
else
    : > "$RUN_DIR/datcom.out"
fi
cp "$WORK_DIR/datcom.console" "$RUN_DIR/datcom.console"
cp "$WORK_DIR/datcom.status" "$RUN_DIR/datcom.status"

grep -n -E "\\*\\* ERROR \\*\\*|\\*\\*\\* ERROR \\*\\*\\*|ERROR[[:space:]]*\\*\\*" \
    "$RUN_DIR/datcom.out" > "$RUN_DIR/datcom_errors.txt" || true
grep -n "WARNING" "$RUN_DIR/datcom.out" > "$RUN_DIR/datcom_warnings.txt" || true

error_count="$(grep -c -E "\\*\\* ERROR \\*\\*|\\*\\*\\* ERROR \\*\\*\\*|ERROR[[:space:]]*\\*\\*" \
    "$RUN_DIR/datcom.out" || true)"
warning_count="$(grep -c "WARNING" "$RUN_DIR/datcom.out" || true)"
datcom_exit_status="$(cat "$RUN_DIR/datcom.status")"
build_log_path="$BUILD_DIR/build.log"
if [[ "$build_log_path" == "$ROOT_DIR/"* ]]; then
    build_log_path="${build_log_path#"$ROOT_DIR"/}"
fi

{
    echo "input_file=$(basename "$INPUT_FILE")"
    echo "datcom_url=$DATCOM_URL"
    echo "build_log=$build_log_path"
    echo "datcom_exit_status=$datcom_exit_status"
    echo "error_count=$error_count"
    echo "warning_count=$warning_count"
    echo "candidate_file=${CANDIDATE_FILE#"$ROOT_DIR"/}"
    echo "extraction_report=${EXTRACTION_REPORT#"$ROOT_DIR"/}"
    echo "extractor=${EXTRACTOR#"$ROOT_DIR"/}"
} > "$RUN_DIR/run_quality.txt"

if [[ "$datcom_exit_status" == "0" && "$error_count" == "0" ]]; then
    python3 "$EXTRACTOR" \
        "$RUN_DIR/datcom.out" \
        "$CANDIDATE_FILE" \
        --report "$EXTRACTION_REPORT"
else
    echo "Skipping derivative extraction because DATCOM did not pass run gates."
fi

echo "Digital DATCOM run written to $RUN_DIR"
echo "Review datcom_errors.txt and datcom_warnings.txt before promoting values."
