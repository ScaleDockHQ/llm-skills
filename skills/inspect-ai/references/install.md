# Inspect AI: install

> Verified against inspect-ai 0.3.278 and inspect-evals 0.24.0 (PyPI, docs at inspect.aisi.org.uk, GitHub), 2026-10-11

## Requirements

- inspect-ai 0.3.278 (released 2026-10-09) declares `requires_python >=3.10`. inspect-evals 0.24.0 declares `>=3.11`; its README recommends 3.11 or 3.12 (3.13 works except one eval, 3.14 unsupported).
- Provider SDKs are separate packages and installed on demand: `openai` (also used by Ollama, llama-cpp-python, vLLM server mode and any `openai-api/...`), `anthropic`, `google-genai`, and `torch transformers` for the `hf` provider. `vllm` is needed only when Inspect itself starts a vLLM server.
- The docs' own install line is `pip install inspect-ai`. `pip install inspect-ai[math]` adds the dependencies for the `math()` scorer.

## Install pinned, per project

```bash
python3.11 -m venv .venv && . .venv/bin/activate     # or: uv venv --python 3.11
pip install "inspect-ai==0.3.278" openai              # pin; bump deliberately
inspect --version
inspect eval --help | sed -n 1,40p
```

With uv: `uv add inspect-ai==0.3.278 openai`. Commit the lockfile.

## Published benchmarks

```bash
pip install inspect-evals                      # tasks are registered as inspect_evals/<name>
inspect eval inspect_evals/simpleqa --model <provider/model> --limit 5
```

Some evals need extra dependencies or Docker; each eval's README in the inspect_evals repo lists them, and the docs site shows the Usage section per eval. Dataset downloads happen on first run (ask first).

## Environment and `.env`

`inspect` reads a `.env` file from the cwd (searching parents) with python-dotenv. Every CLI option can be set as `INSPECT_EVAL_<OPTION>` (for example `INSPECT_EVAL_MODEL`, `INSPECT_EVAL_MAX_CONNECTIONS`, `INSPECT_EVAL_MAX_RETRIES`), plus `INSPECT_LOG_DIR`, `INSPECT_LOG_LEVEL`, `INSPECT_LOG_FORMAT`. A relative `INSPECT_LOG_DIR` in `.env` resolves relative to the `.env` file. Never commit `.env`; commit a keys-only `.env.example`.

## Maintenance and ownership

- inspect_ai: github.com/UKGovernmentBEIS/inspect_ai, MIT, not archived, pushed 2026-10-10. The docs describe Inspect as developed by the UK AI Security Institute and Meridian Labs.
- inspect_evals: maintained by Generality Labs per its README; it accepts PRs only from pre-approved contributors, so report problems as issues with `.eval` logs attached.
- A `inspect-skills` plugin from Meridian Labs exists for coding agents that monitor evals and read logs (https://github.com/meridianlabs-ai/inspect-skills); this skill does not depend on it.

Official sources: https://inspect.aisi.org.uk/, https://pypi.org/project/inspect-ai/, https://github.com/UKGovernmentBEIS/inspect_evals
