# Lighteval: install

> Verified against lighteval 0.13.0 (PyPI, docs installation page) and main 0.13.1.dev0 (pyproject.toml), 2026-10-11

## Requirements

- Python 3.10 or higher, PyTorch >=2.0 and <3.0 (docs). The package depends on `inspect-ai>=0.3.140`, `transformers>=4.54.0`, `datasets>=4.0.0`, `openai`, `accelerate`, `typer`; the base install is large because `torch` is a hard dependency.
- Windows is untested upstream; macOS and Linux are expected to work.
- Backend extras: `vllm` (0.13.0 pins `vllm>=0.10.0,<0.10.2`; main has `vllm>=0.11.0`), `litellm` (`litellm[caching]>=1.66.0`, `diskcache`), `tgi`, `optimum`, `quantization`, `adapters`, `nanotron`. Task extras: `extended_tasks`, `multilingual`, `math`. Logging extras: `s3`, `tensorboardX`, `wandb`, `trackio`.

## Install pinned, per project

```bash
python3.11 -m venv .venv && . .venv/bin/activate
pip install "lighteval==0.13.0"                    # core + inspect-ai backend (`lighteval eval`)
pip install "lighteval[litellm]==0.13.0"           # only if using `lighteval endpoint litellm`
pip install "lighteval[vllm]==0.13.0"              # only for local vLLM; needs a CUDA GPU
lighteval --help
```

`pip install lighteval[extra]` conflicts are common with a separately installed `vllm`; give vLLM its own venv when you also serve with it (see the `vllm` skill). From source: `git clone https://github.com/huggingface/lighteval && pip install -e .`.

## Tokens and environment

- `HF_TOKEN` (or `hf auth login`) is needed for gated datasets and models and for `--push-to-hub`. Keep it in the environment; do not paste it into configs.
- Provider keys follow the backend: `<PROVIDER>_API_KEY` for Inspect `openai-api/<provider>/...`, provider-specific names for LiteLLM (`OPENAI_API_KEY`), or `api_key` in a LiteLLM YAML (stored as a secret string; keep that file `0600` and out of git).
- Results are saved under `--output-dir` (default `results`); Inspect logs under `--log-dir` for `lighteval eval`.

## Maintenance and ownership

- github.com/huggingface/lighteval, MIT, not archived; main pushed 2026-10-06. The latest PyPI and GitHub release is v0.13.0 (2025-11-24), so `main` runs ahead of the release: examples copied from main may need a newer install than PyPI offers. Build from a tag or main only when you need unreleased features, and pin the commit.
- Built by the Hugging Face Leaderboard and Evals team; the README says `lighteval eval` (Inspect backend) is the preferred entry point.
- Benchmark index: https://huggingface.co/spaces/OpenEvals/open_benchmark_index.

Official sources: https://huggingface.co/docs/lighteval/installation, https://github.com/huggingface/lighteval, https://pypi.org/project/lighteval/
