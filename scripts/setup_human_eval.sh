#!/bin/bash
# Installs the OpenAI human-eval package required by the humaneval-th / humaneval
# benchmark adapters. Not pip-installable, so this clones the source, enables the
# (intentionally disabled) code execution line, and installs it into the active
# Python environment.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUMAN_EVAL_DIR="$REPO_DIR/human-eval"
EXEC_FILE="$HUMAN_EVAL_DIR/human_eval/execution.py"

if [ -d "$HUMAN_EVAL_DIR" ]; then
    echo "human-eval already cloned at $HUMAN_EVAL_DIR, skipping clone."
else
    git clone https://github.com/openai/human-eval.git "$HUMAN_EVAL_DIR"
fi

# OpenAI ships this line commented out by default: running it means executing
# arbitrary model-generated code on this machine with no real sandboxing beyond
# a timeout. Required for humaneval-th to produce a score at all.
if grep -qE '^\s*#\s*exec\(check_program, exec_globals\)' "$EXEC_FILE"; then
    sed -i.bak -E 's/^(\s*)#\s*exec\(check_program, exec_globals\)/\1exec(check_program, exec_globals)/' "$EXEC_FILE"
    rm -f "$EXEC_FILE.bak"
    echo "Enabled code execution in $EXEC_FILE"
else
    echo "Code execution already enabled in $EXEC_FILE"
fi

pip install -e "$HUMAN_EVAL_DIR"

python3 -c "from human_eval.data import stream_jsonl, write_jsonl; from human_eval.evaluation import check_correctness; print('human_eval OK')"
