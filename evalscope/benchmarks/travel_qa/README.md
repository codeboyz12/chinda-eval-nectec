# Travel-QA Benchmark

Thai/English multiple-choice questions about travel in Thailand: destinations,
accommodations, attractions, local culture, food, and travel logistics. The
benchmark was originally built to evaluate the OpenThaiGPT ThaiLLM travel
fine-tunes (see `thaillm-travel-lora.sh` in the sibling repo) and is now a
first-class dataset inside `chinda-eval`.

## What ships with the repo

| File                                                   | Purpose                                      |
| ------------------------------------------------------ | -------------------------------------------- |
| `evalscope/benchmarks/travel_qa/travel_qa_adapter.py`  | Registers the `travel_qa` benchmark         |
| `custom_eval/text/mcq/travel_qa_example_dev.jsonl`     | 3 example few-shot items (Thai + English)    |
| `custom_eval/text/mcq/travel_qa_example_val.jsonl`     | 10 example evaluation items (Thai + English) |

The **real test set is owned externally** and is not committed. The
`.gitignore` blocks the canonical filenames so they cannot be staged by
accident:

```
custom_eval/text/mcq/travel_qa_dev.jsonl
custom_eval/text/mcq/travel_qa_val.jsonl
custom_eval/text/mcq/travel_qa_v*_dev.jsonl
custom_eval/text/mcq/travel_qa_v*_val.jsonl
travel_qa_ver*.xlsx
```

## Data format

Each line is one JSON record:

```json
{"id": "ex_val_1", "question": "...", "A": "...", "B": "...", "C": "...", "D": "...", "answer": "B"}
```

- `id` — string, unique per record (any format).
- `question` — the prompt shown to the model.
- `A`, `B`, `C`, `D`, … — choice text. Up to 10 choices (`A`–`J`) are supported.
- `answer` — single uppercase letter matching one of the choice keys.

Files are resolved as `{subset}_{split}.jsonl` under the configured
`local_path`, so a subset called `travel_qa_v2` requires both
`travel_qa_v2_dev.jsonl` and `travel_qa_v2_val.jsonl`.

## Running the benchmark

### Quick smoke test (uses the bundled example subset)

```bash
evalscope eval \
    --model "$MODEL_NAME" \
    --api-url http://localhost:8801/v1/chat/completions \
    --api-key EMPTY \
    --eval-type openai_api \
    --datasets travel_qa \
    --work-dir outputs/$MODEL_NAME/travel_qa_example \
    --eval-batch-size 8 \
    --generation-config '{"do_sample": false, "temperature": 0.0, "max_new_tokens": 1024}'
```

This evaluates against `travel_qa_example` (the 10-item demo set bundled in the
repo) — useful to confirm the adapter, server, and scoring all wire together.

### Full evaluation (using the private test set)

1. Drop the real test files into `custom_eval/text/mcq/`, naming them
   `{subset}_dev.jsonl` and `{subset}_val.jsonl` — e.g.
   `travel_qa_v2_dev.jsonl` / `travel_qa_v2_val.jsonl`.
   The `.gitignore` already protects these names so they will not be committed.

2. Point the benchmark at the private subset via `--dataset-args`:

   ```bash
   evalscope eval \
       --model "$MODEL_NAME" \
       --api-url http://localhost:8801/v1/chat/completions \
       --api-key EMPTY \
       --eval-type openai_api \
       --datasets travel_qa \
       --dataset-args '{"travel_qa": {"subset_list": ["travel_qa_v2"]}}' \
       --work-dir outputs/$MODEL_NAME/travel_qa_v2 \
       --eval-batch-size 8 \
       --limit 200 \
       --generation-config '{"do_sample": false, "temperature": 0.0, "max_new_tokens": 1024}'
   ```

   You can also override the data directory if it lives elsewhere:

   ```bash
   --dataset-args '{"travel_qa": {"local_path": "/abs/path/to/mcq", "subset_list": ["travel_qa_v2"]}}'
   ```

### Backwards compatible: invoking via `general_mcq`

The previous workflow (used in `thaillm-travel-lora.sh`) calls `general_mcq`
with an inline `prompt_template`. That still works — the new `travel_qa`
benchmark just packages the same defaults so callers don't have to spell them
out every time.

## Metric

Accuracy (`acc`) — the model's first-letter answer is compared against
`answer`. The default prompt template asks the model to emit
`ANSWER: <LETTER>` on the last line; the multi-choice parser tolerates the
common variants (`Answer: B`, `**B**`, etc.).

## Tags

`MCQ`, `MultiLingual`, `Custom`
