# 🇹🇭 Chinda-Eval: Thai LLM Chinda Evaluation Framework

<p align="center">
    <h2 align="center">Comprehensive Evaluation Framework for Thai Language Models</h2>
</p>

<p align="center">
<img src="https://img.shields.io/badge/python-%E2%89%A53.9-5be.svg">
<img src="https://img.shields.io/badge/evalscope-v2.0-blue.svg">
<a href="https://github.com/codeboyz12/chinda-eval-nectec"><img src="https://img.shields.io/badge/github-chinda--eval--nectec-green.svg"></a>
</p>

> ⭐ **Chinda-Eval** is a specialized evaluation framework designed to assess Thai Language Models (LLMs) with comprehensive benchmarks and metrics. Built on top of EvalScope v2.0, it provides a robust infrastructure for evaluating Thai language understanding, generation, and reasoning capabilities.
>
> This copy is maintained by **NECTEC** as a fork of [iapp-technology/chinda-eval](https://github.com/iapp-technology/chinda-eval). See [Fork History & Local Changes](#-fork-history--local-changes) at the bottom for exactly what differs from upstream and why.

## 📋 Table of Contents
- [🎯 Key Features](#-key-features)
- [📊 Benchmarks](#-benchmarks)
- [🧳 Travel-QA Benchmark](#-travel-qa-benchmark)
- [⚙️ Installation](#️-installation)
- [🔑 Configuring Model Access](#-configuring-model-access)
- [🚀 Running an Evaluation](#-running-an-evaluation)
- [🤖 Local Models & Ports](#-local-models--ports)
- [📁 Output Structure & Reading Results](#-output-structure--reading-results)
- [📝 Script Reference](#-script-reference)
- [⚡ Performance Notes](#-performance-notes)
- [🐛 Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📚 Citation](#-citation)
- [📄 License](#-license)
- [🧩 Fork History & Local Changes](#-fork-history--local-changes)

## 🎯 Key Features

- **Thai-Specific Benchmarks**: Comprehensive evaluation suite tailored for Thai language models
- **Multi-Domain Coverage**: Mathematics, reasoning, code generation, instruction following, and general knowledge in Thai
- **Parallel Evaluation**: Run multiple benchmarks and/or multiple models concurrently
- **API Support**: Evaluate any OpenAI-compatible endpoint — local vLLM servers or remote/partner-hosted APIs
- **Extensible Framework**: Easy to add new Thai benchmarks and evaluation metrics
- **Built on EvalScope 2.0**: Leverages the powerful EvalScope v2.0 architecture

## 📊 Benchmarks

### Thai Benchmarks

| Benchmark | Description | Dataset ID | Split | Metric |
|-----------|-------------|------------|-------|--------|
| `aime24-th` | AIME 2024 math problems translated to Thai | `iapp/aime_2024-th` | train | mean_acc |
| `hellaswag-th` | Thai commonsense reasoning | `Patt/HellaSwag_TH_cleanned` | validation | acc |
| `humaneval-th` | Thai code generation, executed against test cases | `iapp/openai_humaneval-th` | test | Pass@1 |
| `ifeval-th` | Thai instruction following | `scb10x/ifeval-th` | train | prompt/inst level acc |
| `math_500-th` | 500 Thai math problems across difficulty levels | `iapp/math-500-th` | test | mean_acc |
| `code_switching` | Thai-English code switching | `airesearch/WangchanThaiInstruct` | train | language accuracy |
| `live_code_bench-th` | Thai code generation, executed against test cases | `iapp/code_generation_lite-th` | test | Pass@1 |
| `openthaieval` | Thai national exam questions (O-NET, TGAT, etc.) | `iapp/openthaieval` (subset `all`) | test | acc |
| `travel_qa` | Thai/English MCQ on Thailand travel — see [below](#-travel-qa-benchmark) | `custom_eval/text/mcq` (local files) | val | acc |

### English Benchmarks (for comparison against the Thai versions)

| Benchmark | Description |
|-----------|-------------|
| `aime24` | AIME 2024 math problems |
| `hellaswag` | Commonsense reasoning |
| `humaneval` | Code generation |
| `ifeval` | Instruction following |
| `math_500` | 500 math problems |
| `live_code_bench` | Code generation, executed against test cases |

> Dataset IDs above were read directly from each adapter in `evalscope/benchmarks/*/`. If you find one out of date, that adapter file is the source of truth — please fix it there first, then update this table.

## 🧳 Travel-QA Benchmark

Travel-QA is a Thai/English multiple-choice benchmark for evaluating LLMs on
Thailand-specific travel knowledge: destinations, accommodations, attractions,
local culture, food, and travel logistics. It was originally built to evaluate
the OpenThaiGPT **ThaiLLM travel** fine-tunes and is now a first-class
benchmark inside `chinda-eval`.

### What ships with the repo

| File                                                   | Purpose                                      |
| ------------------------------------------------------ | -------------------------------------------- |
| `evalscope/benchmarks/travel_qa/travel_qa_adapter.py`  | Registers the `travel_qa` benchmark          |
| `custom_eval/text/mcq/travel_qa_example_dev.jsonl`     | 3 example few-shot items (Thai + English)    |
| `custom_eval/text/mcq/travel_qa_example_val.jsonl`     | 10 example evaluation items (Thai + English) |

> ⚠️ The **full test set is owned externally and is _not_ committed**. The
> `.gitignore` blocks the canonical filenames so they cannot be staged by
> accident (`travel_qa_dev.jsonl`, `travel_qa_val.jsonl`,
> `travel_qa_v*_*.jsonl`, `travel_qa_ver*.xlsx`). Drop the real files into
> `custom_eval/text/mcq/` locally to run the full eval.

### Data format

Each line is one JSON record:

```json
{"id": "ex_val_1", "question": "...", "A": "...", "B": "...", "C": "...", "D": "...", "answer": "B"}
```

- `id` — string, unique per record.
- `question` — the prompt shown to the model.
- `A`, `B`, `C`, `D`, … — choice text. Up to 10 choices (`A`–`J`) supported.
- `answer` — single uppercase letter matching one of the choice keys.

Files are resolved as `{subset}_{split}.jsonl` under `custom_eval/text/mcq/`,
so a subset named `travel_qa_v2` requires both `travel_qa_v2_dev.jsonl` and
`travel_qa_v2_val.jsonl`.

### Quick smoke test (uses the bundled example subset)

```bash
./scripts/eval.sh --model "$MODEL_NAME" --api-url http://localhost:8801/v1/chat/completions --api-key EMPTY \
    --datasets travel_qa --eval-batch-size 8 \
    --generation-config '{"do_sample": false, "temperature": 0.0, "max_new_tokens": 1024}'
```

### Full evaluation (with the private test set)

1. Drop the real test files into `custom_eval/text/mcq/`, naming them
   `{subset}_dev.jsonl` and `{subset}_val.jsonl` — e.g.
   `travel_qa_v2_dev.jsonl` / `travel_qa_v2_val.jsonl`. The `.gitignore`
   already protects these names.
2. Point the benchmark at the private subset:

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

   To use a directory outside the repo, override `local_path`:

   ```bash
   --dataset-args '{"travel_qa": {"local_path": "/abs/path/to/mcq", "subset_list": ["travel_qa_v2"]}}'
   ```

### Backwards compatible: invoking via `general_mcq`

The original workflow in `thaillm-travel-lora.sh` calls `general_mcq` with an
inline `prompt_template`. That still works — the new `travel_qa` benchmark
just packages the same defaults so callers don't have to spell them out every
time.

### Metric

Accuracy (`acc`) — the model's first-letter answer is compared against
`answer`. The default prompt template asks the model to emit
`ANSWER: <LETTER>` on the last line; the multi-choice parser tolerates the
common variants (`Answer: B`, `**B**`, etc.).

See [`evalscope/benchmarks/travel_qa/README.md`](evalscope/benchmarks/travel_qa/README.md)
for the adapter-level reference.

## ⚙️ Installation

### Prerequisites

- Python ≥ 3.9 (3.10 recommended)
- CUDA 12.0+ if you're hosting models locally with vLLM (not needed if you only call remote APIs)
- Conda or a plain `venv` — both work; the commands below show conda, swap in `python -m venv .venv && source .venv/bin/activate` if you prefer venv

### Install from source

```bash
git clone https://github.com/codeboyz12/chinda-eval-nectec.git
cd chinda-eval-nectec

conda create -n chinda-eval python=3.10
conda activate chinda-eval

pip install -e .
```

### Install humaneval-th's runtime dependency

`humaneval-th` and `live_code_bench-th` score generated code by executing it
locally. The package that does this (`human_eval`) isn't on PyPI and isn't a
plain pip install, so it has its own setup script:

```bash
./scripts/setup_human_eval.sh
```

This clones [openai/human-eval](https://github.com/openai/human-eval), enables
its (intentionally disabled by default) `exec()` call, and installs it into
your active environment. Read that twice: this means **arbitrary model-generated
code runs on this machine with no real sandboxing beyond a timeout**. Don't run
it against untrusted models on a machine with anything sensitive on it.

### Optional extras

```bash
pip install '.[perf]'   # performance testing
pip install '.[app]'    # visualization
pip install '.[all]'    # everything
```

## 🔑 Configuring Model Access

Two kinds of model endpoints are supported, and both just need an OpenAI-compatible `/v1/chat/completions` URL:

1. **Local vLLM Docker server** — no API key needed (`--api-key EMPTY`), see [Local Models & Ports](#-local-models--ports).
2. **Remote / partner-hosted API** (e.g. an internal NECTEC endpoint, or a partner's hosted model) — needs a real API key.

For (2), **never hardcode the key into a script you might commit**. Put it in `.env` instead:

```bash
cp .env.example .env
# then edit .env:
#   PTM_API_URL=https://your-endpoint/v1/chat/completions
#   PTM_API_KEY=sk-...
```

`.env` is already in `.gitignore`. `scripts/eval.sh` and `run_ptm_benchmarks_parallel.sh` both load it automatically and fall back to its values when `--api-url`/`--api-key` aren't passed explicitly.

## 🚀 Running an Evaluation

### Easiest: `scripts/eval.sh` (one model, one or more benchmarks)

This wraps `evalscope eval` and fills in the flags that are easy to forget
(`--eval-type openai_api`, `--dataset-hub huggingface`, generation config,
batch size, timeout). You only specify what changes per run:

```bash
# Remote/partner API model (reads PTM_API_URL / PTM_API_KEY from .env)
./scripts/eval.sh --model ptm-minimax-2.5 --datasets aime24-th hellaswag-th --limit 10

# Local vLLM model — pass api-url/api-key explicitly
./scripts/eval.sh --model chinda-qwen3-8b \
    --api-url http://localhost:8808/v1/chat/completions --api-key EMPTY \
    --datasets aime24-th --limit 10
```

Any flag not listed above (e.g. `--dataset-args`, `--repeats`) is passed straight through to `evalscope eval`.

### Manual: raw `evalscope eval` CLI

Useful when you need full control over every flag:

```bash
evalscope eval \
    --model MODEL_NAME \
    --api-url http://localhost:8801/v1/chat/completions \
    --api-key EMPTY \
    --eval-type openai_api \
    --datasets aime24-th hellaswag-th math_500-th \
    --dataset-hub huggingface \
    --limit 100
```

Two flags are easy to miss and will silently misbehave if skipped:
- `--eval-type openai_api` — without it, EvalScope doesn't know to speak the OpenAI chat-completions protocol.
- `--dataset-hub huggingface` — the default hub is ModelScope; every Thai benchmark here is hosted on HuggingFace.

### Multiple local Docker models in parallel

```bash
./run_thai_benchmarks_parallel_4models.sh --benchmarks aime24-th math_500-th --limit 100
```

Starts each model's vLLM Docker container, runs benchmarks for all 4 models concurrently (each model also runs several benchmarks concurrently), and tears the containers down afterward. See [Local Models & Ports](#-local-models--ports) for what's pre-configured.

### Multiple remote/partner-API models in parallel

```bash
./run_ptm_benchmarks_parallel.sh --benchmarks aime24-th hellaswag-th --limit 100
```

Same idea, but for models that are already served behind one shared remote endpoint (no Docker/server lifecycle to manage). Edit the `MODELS` array at the top of the script to change which models run. Reads `.env` for the endpoint/key — see [Configuring Model Access](#-configuring-model-access).

### One Docker model, all benchmarks, sequentially or in parallel

```bash
./run_thai_benchmarks.sh --models chinda-qwen3-8b --benchmarks aime24-th hellaswag-th --limit 500
./tests/test_thai_benchmarks_parallel.sh chinda-qwen3-8b 100   # parallel, single model
./tests/test_thai_benchmarks_sequence.sh                       # sequential, single model
./tests/test_thai_single_benchmark.sh aime24-th                # one benchmark, 10 samples
```

## 🤖 Local Models & Ports

Pre-configured `docker-compose` files under `dockers/`. Ports/tensor-parallel sizes below were read directly from each compose file:

| Model | Port | Tensor Parallel | Docker Compose File |
|-------|------|------------------|----------------------|
| `chinda-qwen3-0.6b` | 8801 (shared — run one-at-a-time) | 1 | `dockers/docker-compose.chinda-qwen3-0.6b.yml` |
| `chinda-qwen3-1.7b` | 8801 (shared — run one-at-a-time) | 2 | `dockers/docker-compose.chinda-qwen3-1.7b.yml` |
| `chinda-qwen3-4b` | 8804 | 2 | `dockers/docker-compose.chinda-qwen3-4b.yml` |
| `chinda-qwen3-8b` | 8808 | 2 | `dockers/docker-compose.chinda-qwen3-8b.yml` |
| `chinda-qwen3-14b` | 8814 | 2 | `dockers/docker-compose.chinda-qwen3-14b.yml` |
| `chinda-qwen3-32b` | 8832 | 2 | `dockers/docker-compose.chinda-qwen3-32b.yml` |
| `gpt-oss-20b` | 8801 (shared — run one-at-a-time) | 8 | `dockers/docker-compose.gpt-oss-20b.yml` |
| `gpt-oss-120b` | 8801 (shared — run one-at-a-time) | 8 | `dockers/docker-compose.gpt-oss-120b.yml` |
| `qwen3-next-80b-instruct` | 8880 | 4 | `dockers/docker-compose.qwen3-next-80b-instruct.yml` |
| `qwen3-next-80b-thinking` | 8881 | 4 | `dockers/docker-compose.qwen3-next-80b-thinking.yml` |

Models sharing port 8801 are meant to be run one at a time (`run_thai_benchmarks.sh` stops/starts containers between models automatically). `chinda-qwen3-4b/8b/14b/32b` have dedicated ports specifically so they can run together via `run_thai_benchmarks_parallel_4models.sh`.

```bash
docker compose -f dockers/docker-compose.chinda-qwen3-8b.yml up -d
curl http://localhost:8808/v1/models   # confirm it's up
docker compose -f dockers/docker-compose.chinda-qwen3-8b.yml down
```

## 📁 Output Structure & Reading Results

Every eval writes to `outputs/{model_name}/{benchmark}/` (or wherever `--work-dir` points):

```
outputs/{model_name}/{benchmark}/
├── output.log         # full evalscope stdout/stderr for this run
├── status.txt         # SUCCESS or FAILED (only when run via the parallel scripts)
├── duration.txt        # seconds taken (only when run via the parallel scripts)
└── reports/{model_name}/{benchmark}.json   # the score report
```

A report JSON looks like:

```json
{
    "name": "ptm-minimax-2.5@aime24-th",
    "dataset_name": "aime24-th",
    "model_name": "ptm-minimax-2.5",
    "score": 0.2,
    "metrics": [{"name": "mean_acc", "num": 10, "score": 0.2, "categories": [...]}]
}
```

`score` (top-level) is the headline number for the benchmark. The parallel runner scripts (`run_thai_benchmarks.sh`, `run_thai_benchmarks_parallel_4models.sh`, `run_ptm_benchmarks_parallel.sh`) also write a per-model `outputs/{model_name}/score_summary.csv` aggregating every benchmark's score plus an `AVERAGE` row, and a combined `outputs/*_evaluation_*.txt` report across all models in that run.

```bash
cat outputs/{model_name}/score_summary.csv | column -t -s ','
```

## 📝 Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/eval.sh` | Wrapper around `evalscope eval` with sane defaults — the easiest way to run one model/benchmark combo |
| `scripts/setup_human_eval.sh` | One-time install of the `human_eval` package needed by `humaneval-th` |
| `run_thai_benchmarks.sh` | Run one or more **local Docker** models against one or more benchmarks, sequentially per model |
| `run_thai_benchmarks_parallel_4models.sh` | Run `chinda-qwen3-4b/8b/14b/32b` concurrently (dedicated ports), each running several benchmarks concurrently |
| `run_ptm_benchmarks_parallel.sh` | Run multiple **remote/partner-API** models concurrently against the benchmark suite |
| `tests/test_thai_benchmarks_parallel.sh [model] [limit]` | Single local model, benchmarks run in parallel |
| `tests/test_thai_benchmarks_sequence.sh` | Single local model, benchmarks run sequentially |
| `tests/test_thai_single_benchmark.sh <name>` | Quick 10-sample test of one benchmark |
| `tests/verify_benchmarks.py` | Check benchmark registration |
| `tests/verify_datasets.py` / `tests/verify_correct_datasets.py` | Verify dataset availability/configuration |
| `kill_benchmarks.sh` | Kill stray `evalscope`/benchmark processes |
| `extract_scores.sh <output_folder>` | Pull scores back out of an existing `outputs/` folder after the fact |

## ⚡ Performance Notes

- vLLM Docker configs use `--max-num-seqs=256`, `--max-num-batched-tokens=32768`, `--enable-chunked-prefill`, `--gpu-memory-utilization=0.9` for batch throughput. Reduce these if you hit out-of-memory errors.
- Running benchmarks in parallel (3 at a time is the default in most scripts here) plus vLLM's own request batching together give roughly a 6-9x speedup over fully sequential, single-request execution — actual numbers depend heavily on GPU, model size, and benchmark mix, so treat this as a rough planning guide rather than a guarantee.
- For remote/partner APIs you don't control, keep concurrency conservative (`MAX_PARALLEL_PER_MODEL` in `run_ptm_benchmarks_parallel.sh`) to avoid tripping their rate limits.

## 🐛 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: No module named 'human_eval'` | `humaneval-th`/`live_code_bench-th` need OpenAI's `human_eval` package, which isn't pip-installable | `./scripts/setup_human_eval.sh` |
| `RuntimeError: Failed to import modelscope.msdatasets ... No module named 'oss2'` | `evalscope`'s dataset loader unconditionally imports `modelscope.MsDataset`, even with `--dataset-hub huggingface` | `pip install oss2` (now in `requirements/framework.txt`, so a fresh `pip install -e .` covers it) |
| Eval silently uses the wrong hub / dataset not found | `--dataset-hub` defaults to ModelScope, but Thai benchmarks live on HuggingFace | Always pass `--dataset-hub huggingface`, or use `scripts/eval.sh` which sets it for you |
| `Creating model ... eval_type=...` looks right but the model never gets queried correctly | Missing `--eval-type openai_api` | Add the flag, or use `scripts/eval.sh` |
| Dataset/benchmark "not found" | Benchmark name typo — e.g. `livecodebench-th` instead of `live_code_bench-th` | Check the exact name in `evalscope/benchmarks/` or the table [above](#-benchmarks) |
| Docker server won't start | Check logs / restart | `docker logs <container>`; `docker compose -f dockers/docker-compose.<model>.yml restart` |
| Out of memory | vLLM batch settings too aggressive for your GPU | Lower `--max-num-seqs` / `--gpu-memory-utilization` in the relevant `dockers/docker-compose.*.yml` |
| Benchmarks seem stuck | Orphaned processes from a previous interrupted run | `./kill_benchmarks.sh`, then `ps aux \| grep evalscope` to confirm |
| Dataset not found / HF auth errors | No HuggingFace login, or dataset is gated | `huggingface-cli login` |

## 🤝 Contributing

### Adding new Thai benchmarks

1. Create an adapter in `evalscope/benchmarks/<benchmark-name>-th/`, following the `@register_benchmark(BenchmarkMeta(...))` pattern used by existing adapters.
2. Implement `record_to_sample` and `extract_answer` (see any existing `*_th_adapter.py` for reference).
3. Test it: `./tests/test_thai_single_benchmark.sh <benchmark-name>-th`.

### Reporting issues

- NECTEC-fork-specific issues (this repo's scripts, docs, tooling): [codeboyz12/chinda-eval-nectec/issues](https://github.com/codeboyz12/chinda-eval-nectec/issues)
- Upstream framework issues (EvalScope/benchmark adapters themselves): [iapp-technology/chinda-eval/issues](https://github.com/iapp-technology/chinda-eval/issues)

## 📚 Citation

```bibtex
@misc{chinda_eval_2025,
    title={{Chinda-Eval}: Thai LLM Evaluation Framework},
    author={iApp Technology Team},
    year={2025},
    url={https://github.com/iapp-technology/chinda-eval}
}

@misc{evalscope_2024,
    title={{EvalScope}: Evaluation Framework for Large Models},
    author={ModelScope Team},
    year={2024},
    url={https://github.com/modelscope/evalscope}
}
```

## 🙏 Acknowledgments

- **EvalScope Team**: For providing the robust evaluation framework foundation
- **iApp Technology**: For the original Chinda-Eval Thai benchmark suite this fork builds on
- **Thai NLP Community**: For contributions to Thai language resources
- **NECTEC**: For maintaining this fork and its tooling/reliability fixes

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🧩 Fork History & Local Changes

This repository is layered on two upstream projects:

1. **[modelscope/evalscope](https://github.com/modelscope/evalscope)** (the general evaluation framework) — this fork is based on EvalScope **v2.0.0**, commit [`5531b60`](https://github.com/modelscope/evalscope/commit/5531b60908f9b5b24b6802fd814f13a0ee8d3f31) (2025-09-15).
2. **[iapp-technology/chinda-eval](https://github.com/iapp-technology/chinda-eval)** — iApp's Thai-benchmark customization on top of EvalScope, starting at commit `f696413` (2025-09-16) and comprising 37 commits up to the commit this NECTEC fork branched from: [`c383a6b`](https://github.com/iapp-technology/chinda-eval/commit/c383a6b16c28c6857894e607856ccba1b2eb43a7) "Document Travel-QA benchmark in main README" (2026-05-18).

### Known issues in `c383a6b` (the upstream commit this fork started from)

- `README.md`'s Quick Start told you to run `python run_benchmark_api.py`, which doesn't exist anywhere in the codebase — the real entrypoint is the `evalscope eval` CLI.
- `README.md` linked to `docs/api_evaluation.md` and `docs/custom_benchmarks.md`, neither of which exist.
- Evaluating **any** Thai benchmark via `--dataset-hub huggingface` crashed with `ModuleNotFoundError: No module named 'oss2'`, because `evalscope`'s `RemoteDataLoader.load()` unconditionally does `from modelscope import MsDataset` regardless of which hub you actually asked for.
- `humaneval-th` crashed with `ModuleNotFoundError: No module named 'human_eval'` and had no setup automation — `human_eval` has to be cloned from GitHub and patched (its code-execution line ships disabled) before it's installable.
- The example `--datasets` lists in `README.md` used `livecodebench-th`, which doesn't match the registered benchmark name `live_code_bench-th`.
- `README.md`, `README_THAI_BENCHMARKS.md`, and `MULTI_MODEL_EVALUATION.md` had each drifted independently and disagreed with each other (different script names, different output directory names, some referencing scripts — e.g. `test_thai_benchmarks_multi_model.sh` — that don't exist).
- No supported pattern for evaluating remote/partner-hosted API models without hardcoding API keys into a script.

### What this fork changes

- Rewrote `README.md`'s Quick Start to use the real `evalscope eval` CLI, and merged `README_THAI_BENCHMARKS.md` + `MULTI_MODEL_EVALUATION.md` into this single file so there's one source of truth.
- Added `oss2` to `requirements/framework.txt` so a plain `pip install -e .` no longer crashes on the first HuggingFace-hub dataset load.
- Added `scripts/setup_human_eval.sh` to automate cloning, patching, and installing `human_eval`.
- Added `scripts/eval.sh`, a thin wrapper that fills in the flags (`--eval-type openai_api`, `--dataset-hub huggingface`, generation config, batch size, timeout) that are easy to forget and silently produce wrong results if missed.
- Added a `.env` / `.env.example` pattern (`.env` already covered by `.gitignore`) plus `run_ptm_benchmarks_parallel.sh`, so remote/partner-hosted API models can be evaluated in parallel without ever hardcoding a key into a committed script.
- Corrected dataset IDs in this README for `code_switching` and `live_code_bench-th`, which had been wrong even in the upstream docs.
