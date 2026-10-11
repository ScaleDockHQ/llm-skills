# AIPerf: install

> Verified against AIPerf 0.13.0 (PyPI, GitHub README and docs at tag v0.13.0), 2026-10-11

## Status

- Repository: https://github.com/ai-dynamo/aiperf (NVIDIA, under the `ai-dynamo` organisation). Apache-2.0, not archived, actively maintained: release v0.13.0 on 2026-09-24 (previous v0.12.0 on 2026-08-06, v0.11.0 on 2026-07-08) and commits to `main` on 2026-10-11.
- PyPI package `aiperf`, `requires-python >=3.11,<3.14`.
- It is the successor of GenAI-Perf (see `updating.md`).

## Install (isolated venv, pinned)

```bash
python3.12 -m venv ~/.venvs/aiperf-0.13.0       # any of 3.11, 3.12, 3.13
. ~/.venvs/aiperf-0.13.0/bin/activate
pip install "aiperf==0.13.0"
aiperf --version
aiperf profile --help | head -40
```

Optional extras (upstream README):

| Extra      | Adds                                                              |
| ---------- | ----------------------------------------------------------------- |
| `tdigest`  | Bounded-memory t-digest list-metric backend (`crick`)             |
| `mlflow`   | MLflow uploads and live telemetry streaming                       |
| `otel`     | OpenTelemetry metric streaming                                    |
| `wandb`    | Weights & Biases result uploads                                   |
| `accuracy` | Sympy-based math grader for `--accuracy-benchmark` (docs mention) |

Combine as `pip install "aiperf[mlflow,otel,wandb]==0.13.0"`. `crick` has wheels for Linux x86_64/i686, macOS arm64 and Windows; elsewhere (Linux aarch64, Intel macOS) it builds from source and needs a C compiler. A plain `pip install aiperf` does not pull it.

If the system Python is outside 3.11-3.13, install a supported one with your usual manager (Homebrew, pyenv, uv, the distro) and ask first.

## First run (Ollama example from upstream, small CPU model)

```bash
aiperf profile --model "granite4:350m" --streaming --endpoint-type chat \
  --tokenizer ibm-granite/granite-4.0-micro --url http://localhost:11434 --request-count 10
```

Results land in `artifacts/<model>-<service>-<endpoint>-<stimulus>/`, for example `artifacts/granite4:350m-openai-chat-concurrency1/`, with `profile_export_aiperf.csv`, `profile_export_aiperf.json` and `logs/aiperf.log`.

## Network use

- The tokenizer is downloaded from the Hugging Face Hub on first use (set `HF_TOKEN` for gated repos; pin `--tokenizer-revision`). For offline use pass a local path or `--tokenizer builtin` (tiktoken `o200k_base`, no network), but token counts then differ from the model's real tokenizer.
- Public datasets (`--public-dataset`) download on first use.
- AIPerf also scrapes the server's `/metrics` endpoint by default and tries local DCGM endpoints (`localhost:9400` and `9401`) for GPU telemetry; both are optional and can be disabled with `--no-server-metrics` and `--no-gpu-telemetry`.

## Kubernetes

AIPerf ships a `kube` command group (`kube init`, `kube profile`, `kube sweep`, `kube results`, `kube preflight`, ...) and an operator. Upstream docs: `docs/kubernetes/getting-started.md` in the repository. Installing an operator changes the cluster: ask first.

Official sources: https://github.com/ai-dynamo/aiperf#readme, https://pypi.org/project/aiperf/
