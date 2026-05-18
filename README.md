# 🇹🇭 Chinda-Eval: Thai LLM Chinda Evaluation Framework

<p align="center">
    <h2 align="center">Comprehensive Evaluation Framework for Thai Language Models</h2>
</p>

<p align="center">
<img src="https://img.shields.io/badge/python-%E2%89%A53.9-5be.svg">
<img src="https://img.shields.io/badge/evalscope-v2.0-blue.svg">
<a href="https://github.com/iapp-technology/chinda-eval"><img src="https://img.shields.io/badge/github-chinda--eval-green.svg"></a>
</p>

> ⭐ **Chinda-Eval** is a specialized evaluation framework designed to assess Thai Language Models (LLMs) with comprehensive benchmarks and metrics. Built on top of EvalScope v2.0, it provides a robust infrastructure for evaluating Thai language understanding, generation, and reasoning capabilities.

## 📋 Table of Contents
- [🎯 Key Features](#-key-features)
- [📊 Thai Benchmarks](#-thai-benchmarks)
- [🧳 Travel-QA Benchmark](#-travel-qa-benchmark)
- [🚀 Quick Start](#-quick-start)
- [⚙️ Installation](#️-installation)
- [📈 Evaluation Results](#-evaluation-results)
- [🛠️ Configuration](#️-configuration)
- [📝 Documentation](#-documentation)
- [🤝 Contributing](#-contributing)

## 🎯 Key Features

- **Thai-Specific Benchmarks**: Comprehensive evaluation suite tailored for Thai language models
- **Multi-Domain Coverage**: Mathematics, reasoning, code generation, and general knowledge in Thai
- **Parallel Evaluation**: Efficient parallel processing for large-scale benchmark testing
- **API Support**: Evaluate models through OpenAI-compatible APIs (vLLM, etc.)
- **Extensible Framework**: Easy to add new Thai benchmarks and evaluation metrics
- **Built on EvalScope 2.0**: Leverages the powerful EvalScope v2.0 architecture

## 📊 Thai Benchmarks

The framework includes the following Thai language benchmarks:

| Benchmark | Description | Domain |
|-----------|-------------|--------|
| **AIME24-TH** | Thai translation of AIME 2024 mathematics competition | Mathematics |
| **HellaSwag-TH** | Thai commonsense reasoning benchmark | Reasoning |
| **HumanEval-TH** | Thai code generation benchmark | Programming |
| **IFEval-TH** | Thai instruction following evaluation | Instruction Following |
| **MATH-500-TH** | 500 Thai mathematics problems across difficulty levels | Mathematics |
| **Code-Switching** | Thai-English code switching evaluation | Language Mixing |
| **LiveCodeBench-TH** | Thai code generation with test execution | Programming |
| **LiveCodeBench** | English code generation with test execution | Programming |
| **OpenThaiEval** | Thai national exam questions (O-NET, TGAT, etc.) | General Knowledge |
| **Travel-QA** | Thai/English MCQ on Thailand travel (destinations, culture, logistics) | Travel / Domain |

Each benchmark has been carefully translated and validated to ensure cultural and linguistic appropriateness for Thai language evaluation.

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

## 🚀 Quick Start

### Evaluate a Thai Model

```bash
# Evaluate using API
python run_benchmark_api.py \
    --model gpt-oss-20b \
    --api-url http://localhost:8001/v1 \
    --datasets aime24-th hellaswag-th humaneval-th \
    --limit 10

# Run all Thai benchmarks in parallel
./test_thai_benchmarks_parallel.sh
```

### Using vLLM server on Docker container to host model

```bash
# Start vLLM server with Docker
docker-compose -f docker-compose.gptoss20b.yml up -d

# Run evaluation
python run_benchmark_api.py \
    --model gpt-oss-20b \
    --api-url http://localhost:8001/v1
```

## ⚙️ Installation

### Prerequisites

- Python >= 3.9
- CUDA 11.8+ (for GPU inference)
- Conda (recommended)

### Install from Source

```bash
# Clone the repository
git clone https://github.com/iapp-technology/chinda-eval.git
cd chinda-eval

# Create conda environment
conda create -n chinda-eval python=3.10
conda activate chinda-eval

# Install dependencies
pip install -e .
```

### Install Additional Components

```bash
# For performance testing
pip install '.[perf]'

# For visualization
pip install '.[app]'

# Install all components
pip install '.[all]'
```

## 📈 Evaluation Results

Results are automatically generated in the `thai_benchmark_results_api/` directory:

```
thai_benchmark_results_api/
├── aime24-th/
│   ├── reports/
│   └── reviews/
├── hellaswag-th/
├── humaneval-th/
├── ifeval-th/
├── math_500-th/
├── code_switching/
├── livecodebench-th/
├── livecodebench/
├── openthaieval/
└── parallel_summary_*.txt
```

### Sample Results

| Model | AIME24-TH | HellaSwag-TH | HumanEval-TH | IFEval-TH | MATH-500-TH |
|-------|-----------|--------------|--------------|-----------|-------------|
| GPT-OSS-20B | 78.5% | 82.3% | 65.4% | 71.2% | 69.8% |

## 🛠️ Configuration

### Model Configuration

Edit `run_benchmark_api.py` to configure model settings:

```python
model_configs = {
    "gpt-oss-20b": {
        "model_name": "gpt-oss-20b",
        "api_url": "http://localhost:8001/v1",
        "api_key": "EMPTY"
    }
}
```

### Benchmark Selection

Specify benchmarks in the command line:

```bash
# Run specific benchmarks
--datasets aime24-th hellaswag-th

# Run all Thai benchmarks
--datasets aime24-th hellaswag-th humaneval-th ifeval-th math_500-th code_switching livecodebench-th openthaieval

# Also run English versions for comparison
--datasets aime24 hellaswag humaneval ifeval math_500 livecodebench
```

## 📝 Documentation

- [Thai Benchmarks Guide](README_THAI_BENCHMARKS.md)
- [Travel-QA Benchmark](evalscope/benchmarks/travel_qa/README.md)
- [API Evaluation Guide](docs/api_evaluation.md)
- [Custom Benchmark Creation](docs/custom_benchmarks.md)
- [EvalScope Documentation](https://evalscope.readthedocs.io/)

## 🤝 Contributing

We welcome contributions to improve and expand the Thai LLM evaluation framework!

### Adding New Thai Benchmarks

1. Create adapter in `evalscope/benchmarks/[benchmark-name]-th/`
2. Implement the adapter following existing patterns
3. Add configuration to benchmark registry
4. Test with sample data

### Reporting Issues

Please report issues at: [https://github.com/iapp-technology/chinda-eval/issues](https://github.com/iapp-technology/chinda-eval/issues)

## 📚 Citation

If you use Chinda-Eval in your research, please cite:

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
- **Thai NLP Community**: For contributions to Thai language resources
- **iApp Technology**: For supporting Thai LLM development and evaluation

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
Built with ❤️ for the Thai AI Community
</p>