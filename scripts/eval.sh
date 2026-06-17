#!/bin/bash
# Thin wrapper around `evalscope eval` that fills in the flags every Thai-benchmark
# eval needs (--eval-type openai_api, --dataset-hub huggingface, generation config,
# batch size, timeout) so callers only have to specify model / datasets.
#
# Usage:
#   ./scripts/eval.sh --model MODEL_NAME --datasets aime24-th hellaswag-th [OPTIONS]
#
# Options:
#   --api-url URL      Defaults to PTM_API_URL from .env (see .env.example)
#   --api-key KEY      Defaults to PTM_API_KEY from .env, or EMPTY for local vLLM
#   --limit N          Max samples per benchmark
#   --work-dir DIR     Defaults to outputs/<model>/<first-dataset>
#   Any other flag is passed straight through to `evalscope eval`.
#
# Example (local vLLM server):
#   ./scripts/eval.sh --model chinda-qwen3-8b --api-url http://localhost:8808/v1/chat/completions --api-key EMPTY --datasets aime24-th --limit 10
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

MODEL=""
API_URL="${PTM_API_URL:-}"
API_KEY="${PTM_API_KEY:-EMPTY}"
DATASETS=()
LIMIT=""
WORK_DIR=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        --api-url) API_URL="$2"; shift 2 ;;
        --api-key) API_KEY="$2"; shift 2 ;;
        --datasets)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do DATASETS+=("$1"); shift; done
            ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --work-dir) WORK_DIR="$2"; shift 2 ;;
        *) EXTRA_ARGS+=("$1"); shift ;;
    esac
done

if [ -z "$MODEL" ] || [ ${#DATASETS[@]} -eq 0 ] || [ -z "$API_URL" ]; then
    echo "Usage: $0 --model MODEL_NAME --datasets BENCH1 [BENCH2 ...] [--api-url URL] [--api-key KEY] [--limit N] [--work-dir DIR]" >&2
    echo "  --api-url/--api-key default to PTM_API_URL/PTM_API_KEY from .env" >&2
    exit 1
fi

[ -z "$WORK_DIR" ] && WORK_DIR="outputs/$MODEL/${DATASETS[0]}"

CMD=(evalscope eval
    --model "$MODEL"
    --api-url "$API_URL"
    --api-key "$API_KEY"
    --eval-type openai_api
    --datasets "${DATASETS[@]}"
    --dataset-hub huggingface
    --work-dir "$WORK_DIR"
    --eval-batch-size 1
    --ignore-errors
    --generation-config '{"do_sample": false, "temperature": 0.0, "max_new_tokens": 32768}'
    --timeout 300
)

[ -n "$LIMIT" ] && CMD+=(--limit "$LIMIT")
CMD+=("${EXTRA_ARGS[@]}")

echo "+ ${CMD[@]}"
exec "${CMD[@]}"
