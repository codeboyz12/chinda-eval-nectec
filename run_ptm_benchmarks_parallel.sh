#!/bin/bash

# Parallel Thai Benchmark Evaluation for ptm-* models served behind a single
# remote OpenAI-compatible API endpoint (no local vLLM/docker server to manage).
#
# All 4 models run concurrently; each model runs its benchmarks with limited
# parallelism to avoid overloading the shared endpoint.
#
# Usage:
#   ./run_ptm_benchmarks_parallel.sh [OPTIONS]
#
# Options:
#   --benchmarks BENCH1 BENCH2... Specify benchmarks to run (default: the 8 below)
#   --limit N                      Override default sample limit (default: 1500)
#
# Requires a .env file (see .env.example) with PTM_API_URL and PTM_API_KEY set.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Configuration
API_URL="${PTM_API_URL:?Set PTM_API_URL in .env (see .env.example)}"
API_KEY="${PTM_API_KEY:?Set PTM_API_KEY in .env (see .env.example)}"
BASE_OUTPUT_DIR="outputs"
MAX_PARALLEL_PER_MODEL=1  # concurrent benchmarks per model (4 models => up to 4 requests at once).
                          # Was 3 (=> 12 at once); the shared origin (tokenmind.9meo.uk) returned
                          # repeated Cloudflare 524s under that load and no model finished.
EVAL_BATCH_SIZE=1
DEFAULT_MAX_SAMPLES=1500

MODELS=(
    "ptm-minimax-2.5"
    "ptm-diffusiongemma-26B-A4B-it"
    "ptm-minimax-m3"
    "ptm-qwen3.5-122b"
)

# Per-benchmark sample limits (override DEFAULT_MAX_SAMPLES for slow benchmarks).
# Plain `case`, not `declare -A`: macOS ships bash 3.2, which has no associative arrays.
benchmark_limit() {
    case "$1" in
        code_switching) echo 500 ;;
        live_code_bench-th) echo 200 ;;
        math_500-th) echo 500 ;;
        ifeval-th) echo 500 ;;
        *) echo "$DEFAULT_MAX_SAMPLES" ;;
    esac
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_model_message() {
    local model=$1
    local message=$2
    local color=$3
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$model]${NC} $message"
}

# Function to run a single benchmark for a model
run_benchmark() {
    local benchmark=$1
    local model_name=$2
    local bench_output_dir="$BASE_OUTPUT_DIR/${model_name}/${benchmark}"
    mkdir -p "$bench_output_dir"

    local start_time=$(date +%s)
    local sample_limit=$(benchmark_limit "$benchmark")

    print_model_message "$model_name" "Starting benchmark: $benchmark (limit: $sample_limit samples)" "$BLUE"

    evalscope eval \
        --model "$model_name" \
        --api-url "$API_URL" \
        --api-key "$API_KEY" \
        --eval-type openai_api \
        --datasets "$benchmark" \
        --dataset-hub huggingface \
        --work-dir "$bench_output_dir" \
        --eval-batch-size $EVAL_BATCH_SIZE \
        --ignore-errors \
        --generation-config '{"do_sample": false, "temperature": 0.0, "max_new_tokens": 32768}' \
        --timeout 300 \
        --limit $sample_limit > "$bench_output_dir/output.log" 2>&1

    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -eq 0 ]; then
        print_model_message "$model_name" "Benchmark $benchmark completed in ${duration}s" "$GREEN"
        echo "SUCCESS" > "$bench_output_dir/status.txt"
    else
        print_model_message "$model_name" "Benchmark $benchmark failed after ${duration}s" "$RED"
        echo "FAILED" > "$bench_output_dir/status.txt"
        tail -10 "$bench_output_dir/output.log"
    fi
    echo "$duration" > "$bench_output_dir/duration.txt"
}

# Function to extract score from benchmark results
extract_score() {
    local benchmark=$1
    local model_name=$2
    local bench_dir="$BASE_OUTPUT_DIR/$model_name/$benchmark"

    local report_file=""
    if [ -d "$bench_dir" ]; then
        report_file=$(find "$bench_dir" -name "*.json" -path "*/reports/*" 2>/dev/null | head -1)
    fi

    if [ -f "$report_file" ]; then
        case "$benchmark" in
            "code_switching")
                python3 -c "
import json
data = json.load(open('$report_file'))
for metric in data.get('metrics', []):
    if 'language_accuracy' in metric.get('name', '').lower():
        print(metric.get('score', 'N/A'))
        exit()
print(data.get('score', 'N/A'))
" 2>/dev/null || echo "N/A"
                ;;
            "ifeval-th")
                python3 -c "
import json
data = json.load(open('$report_file'))
for metric in data.get('metrics', []):
    if 'inst_level_loose' in metric.get('name', '').lower():
        print(metric.get('score', 'N/A'))
        exit()
print(data.get('score', 'N/A'))
" 2>/dev/null || echo "N/A"
                ;;
            "live_code_bench-th"|"humaneval-th")
                python3 -c "
import json
data = json.load(open('$report_file'))
for metric in data.get('metrics', []):
    name = metric.get('name', '').lower()
    if 'pass@1' in name or 'pass' in name:
        print(metric.get('score', 'N/A'))
        exit()
print(data.get('score', 'N/A'))
" 2>/dev/null || echo "N/A"
                ;;
            *)
                python3 -c "
import json
data = json.load(open('$report_file'))
for metric in data.get('metrics', []):
    name = metric.get('name', '').lower()
    if 'mean_acc' in name or 'accuracy' in name:
        print(metric.get('score', 'N/A'))
        exit()
print(data.get('score', 'N/A'))
" 2>/dev/null || echo "N/A"
                ;;
        esac
    else
        echo "N/A"
    fi
}

# Function to generate score summary for a model
generate_score_summary() {
    local model_name=$1
    local output_dir="$BASE_OUTPUT_DIR/$model_name"

    print_model_message "$model_name" "Generating score summary..." "$CYAN"

    {
        echo "Benchmarks,$model_name"
        for benchmark in "${BENCHMARKS[@]}"; do
            score=$(extract_score "$benchmark" "$model_name")
            echo "$benchmark,$score"
        done
    } > "$output_dir/score_summary.csv"

    avg=$(python3 -c "
scores = []
with open('$output_dir/score_summary.csv', 'r') as f:
    lines = f.readlines()[1:]
    for line in lines:
        parts = line.strip().split(',')
        if len(parts) == 2 and parts[1] != 'N/A':
            try:
                scores.append(float(parts[1]))
            except:
                pass
if scores:
    print(sum(scores) / len(scores))
else:
    print('N/A')
" 2>/dev/null || echo "N/A")

    echo "AVERAGE,$avg" >> "$output_dir/score_summary.csv"
    print_model_message "$model_name" "Score summary saved to $output_dir/score_summary.csv" "$GREEN"
}

# Function to run all benchmarks for one model (benchmarks run with limited parallelism)
run_model_benchmarks() {
    local model_name=$1
    local model_output_dir="$BASE_OUTPUT_DIR/$model_name"
    mkdir -p "$model_output_dir"

    local pids=()
    for benchmark in "${BENCHMARKS[@]}"; do
        while [ $(jobs -r -p | wc -l) -ge $MAX_PARALLEL_PER_MODEL ]; do
            sleep 1
        done

        {
            run_benchmark "$benchmark" "$model_name"
        } &
        pids+=($!)

        sleep 0.5
    done

    print_model_message "$model_name" "Waiting for all benchmarks to complete..." "$BLUE"
    for pid in "${pids[@]}"; do
        wait $pid
    done

    generate_score_summary "$model_name"
    print_model_message "$model_name" "All benchmarks completed!" "$GREEN"
}

# Parse command line arguments
BENCHMARKS_TO_RUN=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --benchmarks)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                BENCHMARKS_TO_RUN+=("$1")
                shift
            done
            ;;
        --limit)
            DEFAULT_MAX_SAMPLES="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

THAI_BENCHMARKS=(
    "aime24-th"
    "hellaswag-th"
    "humaneval-th"
    "ifeval-th"
    "math_500-th"
    "code_switching"
    "live_code_bench-th"
    "openthaieval"
)

if [ ${#BENCHMARKS_TO_RUN[@]} -eq 0 ]; then
    BENCHMARKS=("${THAI_BENCHMARKS[@]}")
else
    BENCHMARKS=("${BENCHMARKS_TO_RUN[@]}")
fi

# Main execution
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}PARALLEL PTM MODEL BENCHMARK EVALUATION${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${CYAN}Models:${NC} ${MODELS[@]}"
echo -e "${CYAN}API URL:${NC} $API_URL"
echo -e "${CYAN}Benchmarks:${NC} ${BENCHMARKS[@]}"
echo -e "${CYAN}Max parallel benchmarks per model:${NC} $MAX_PARALLEL_PER_MODEL"
echo -e "${CYAN}Default max samples:${NC} $DEFAULT_MAX_SAMPLES"

echo -e "${CYAN}Benchmark-specific limits:${NC}"
for bench in code_switching live_code_bench-th math_500-th ifeval-th; do
    echo "  - $bench: $(benchmark_limit "$bench") samples"
done
echo -e "${GREEN}=========================================${NC}"

mkdir -p "$BASE_OUTPUT_DIR"
overall_start=$(date +%s)

declare -a MODEL_PIDS
for model_name in "${MODELS[@]}"; do
    {
        run_model_benchmarks "$model_name"
    } &
    MODEL_PIDS+=($!)
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] Launched $model_name (PID: $!)${NC}"
done

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for all models to complete...${NC}"
for pid in "${MODEL_PIDS[@]}"; do
    wait $pid
done

overall_end=$(date +%s)
total_duration=$((overall_end - overall_start))

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}PARALLEL EVALUATION COMPLETE${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${CYAN}Total execution time:${NC} ${total_duration}s"
echo -e "${CYAN}Models evaluated:${NC} ${MODELS[@]}"

{
    echo "Parallel PTM Model Evaluation Report"
    echo "====================================="
    echo "Date: $(date)"
    echo "Total Duration: ${total_duration}s"
    echo "API URL: $API_URL"
    echo ""
    echo "Models Evaluated (in parallel):"
    for model_name in "${MODELS[@]}"; do
        echo "  - $model_name"
    done
    echo ""
    echo "Individual Model Summaries:"
    echo ""
    for model_name in "${MODELS[@]}"; do
        if [ -f "$BASE_OUTPUT_DIR/$model_name/score_summary.csv" ]; then
            echo "=== $model_name ==="
            cat "$BASE_OUTPUT_DIR/$model_name/score_summary.csv"
            echo ""
        fi
    done
} > "$BASE_OUTPUT_DIR/parallel_ptm_evaluation_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Full report saved to $BASE_OUTPUT_DIR/parallel_ptm_evaluation_*.txt${NC}"
echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Individual model results in $BASE_OUTPUT_DIR/{model_name}/${NC}"

echo ""
echo -e "${CYAN}Score Summary Across All Models:${NC}"
echo ""

python3 -c "
import os
import csv

base_dir = '$BASE_OUTPUT_DIR'
models = '${MODELS[@]}'.split()

all_data = {}
benchmarks_order = []
models_with_data = []

for model_name in models:
    csv_file = os.path.join(base_dir, model_name, 'score_summary.csv')
    if os.path.exists(csv_file):
        models_with_data.append(model_name)
        with open(csv_file, 'r') as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                if row[0] not in all_data:
                    all_data[row[0]] = {}
                    benchmarks_order.append(row[0])
                all_data[row[0]][model_name] = row[1]

if all_data:
    print('Benchmarks,' + ','.join(models_with_data))
    for benchmark in benchmarks_order:
        row = [benchmark]
        for model_name in models_with_data:
            row.append(all_data[benchmark].get(model_name, 'N/A'))
        print(','.join(row))
" 2>/dev/null | column -t -s ','

echo ""
echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Evaluation complete!${NC}"
