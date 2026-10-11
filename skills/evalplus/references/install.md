# EvalPlus: install

> Verified against EvalPlus 0.3.1 (PyPI, GitHub README and docs, source at tag v0.3.1), 2026-10-11

## Status

- Repository: https://github.com/evalplus/evalplus. Apache-2.0, not archived. Latest release v0.3.1 (2024-10-20); the last commit to `master` was 2025-10-02 (Ollama and Intel Gaudi backends, CI), about 78 open issues.
- Maintenance is slow: no release in a year. For a fixed benchmark that is acceptable (the datasets are versioned and rarely change), but expect backends and dependencies to lag: the `vllm` extra declares `vllm>=0.5.1`, and the code was written against the 2024 vLLM and transformers APIs. If the `vllm` or `hf` backend breaks with a new vLLM or transformers, use a separate venv, or run generation yourself and score with `evalplus.evaluate`/`--samples` (the scorer has no GPU dependency).
- Datasets (as of the docs): HumanEval+ and MBPP+ v0.2.0 (378 tasks, after removing broken ones from 399), EvalPerf version `20240328` (118 tasks). A "mini" HumanEval+ test subset exists (`--mini`).

## Install

```bash
python3 -m venv ~/.venvs/evalplus-0.3.1 && . ~/.venvs/evalplus-0.3.1/bin/activate
pip install "evalplus==0.3.1"                 # scorer + API backends
pip install "evalplus[vllm]==0.3.1"           # adds vLLM for local generation
pip install "evalplus[perf]==0.3.1"           # adds EvalPerf deps (Pympler, cirron)
evalplus.evaluate --help | head -20
```

`requires-python >=3.9`. Core dependencies include openai, anthropic, google-generativeai, transformers, datasets, tree-sitter. Do not install from `git+https://github.com/evalplus/evalplus` for decisions: it follows an unreleased `master`.

Running from a clone: `git clone https://github.com/evalplus/evalplus && cd evalplus && export PYTHONPATH=$PYTHONPATH:$(pwd) && pip install -r requirements.txt`.

## Docker image (for executing generated code)

```bash
docker pull ganler/evalplus:latest
docker image ls ganler/evalplus
```

Pin a tag or digest for decisions (`docker image inspect --format '{{index .RepoDigests 0}}' ganler/evalplus:latest`) and record it. Upstream's examples use `--pull=always` and `:latest`; the image's own version is whatever was last pushed, so compare it with the pip version you generated with if dataset versions might differ.

## Network use

- Datasets download on first use (cached under the user cache directory); models from Hugging Face for `vllm`/`hf` (set `HF_TOKEN` for gated repos).
- Backend keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `BEDROCK_ROLE_ARN`.

Official sources: https://github.com/evalplus/evalplus#-quick-start, https://pypi.org/project/evalplus/
