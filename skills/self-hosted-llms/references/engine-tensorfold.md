# TensorFold

> Verified against TensorFold v1.0.7, 2026-10-11

## What it is and when to choose it

TensorFold (by Ash Hart, Apache-2.0) serves language models from a native Zig binary,
`tensorfold-native`, on Apple Silicon (Metal) and NVIDIA GPUs (CUDA), with no Python in the serving path.
It focuses on exact decoding (accepted drafts equal the plain reference), shared-lane concurrency and
retained prompt prefixes. Choose it when your model and platform are on its **qualified** list.

Qualified limits matter: release 1.0.7 admits only specific model/checkpoint/platform combinations. On
CUDA that is Nemotron 3.5 Lightning 30B-A3B (MLX 4-bit, or NVIDIA's NVFP4 checkpoint) on GB10, plus
selected Ampere (sm_86) and Blackwell (sm_120) x86 cards. Other families (Qwen3.8, GLM, Gemma 4 and more)
are Metal-only or still under qualification in 1.0.7. Check the README table before planning.

**Community DGX Spark recipes.** MiaAI-Lab publishes ready-made Spark recipes built on TensorFold, for
example [Qwen3.8-27B on one DGX Spark](https://github.com/MiaAI-Lab/Qwen3.8-27B-DGX-Spark-TensorFold)
and [Qwen3.8-Flash-Next on two DGX Sparks](https://github.com/MiaAI-Lab/Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold).
Credit and follow them upstream; do not copy them into your stack. Note they do not run the 1.0.7
archive: the 27B recipe runs TensorFold v0.6.0 plus its own patches in an NVIDIA PyTorch container, and the
dual recipe builds `tensorfold-native` from the `zig-flashnext` branch at a pinned commit. Treat every
recipe default (port, host, context, KV dtype, memory reserve, patches) as upstream-owned.

## Install (DGX Spark/arm64 and generic x86)

Release archives (`linux-aarch64` for GB10, `linux-x86_64` for x86) need glibc 2.28+ and an NVIDIA driver
providing `libcuda.so.1`; CUDA kernels are embedded in the binary.

```bash
V=1.0.7; A=linux-aarch64          # linux-x86_64 on x86 hosts
cd /opt && sudo mkdir -p tensorfold && sudo chown "$USER" tensorfold && cd tensorfold
curl -fLO "https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-$A.tar.gz"
curl -fLO "https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-$A.tar.gz.sha256"
sha256sum -c "tensorfold-$V-$A.tar.gz.sha256" && tar -xzf "tensorfold-$V-$A.tar.gz"
ln -sfn "tensorfold-$V-$A" current && current/bin/tensorfold-native --version
current/bin/tensorfold-native capabilities --json | jq .   # supported flags, env vars, platform values
```

Keep `bin`, `lib` and `share` together. Archives named `host-only` are CPU verification builds and cannot
serve CUDA. Recipes install themselves (`git clone` + `./start.sh`); read their README first.

## Minimal working config

Engine command (single binary, loopback is the default bind):

```bash
/opt/tensorfold/current/bin/tensorfold-native serve ~/models/nemotron-lightning \
  --name nemotron-tf --host 127.0.0.1 --port 8090 --context 32768 --parallel 4
curl -fsS http://127.0.0.1:8090/health && curl -fsS http://127.0.0.1:8090/v1/models | jq .
```

llama-swap entry (direct `cmd`, no container needed):

```yaml
models:
  nemotron-tf:
    cmd: |
      /opt/tensorfold/current/bin/tensorfold-native serve /srv/models/nemotron-lightning
      --name ${MODEL_ID} --host 127.0.0.1 --port ${PORT}
      --context 32768 --parallel 4
    checkEndpoint: /health
    ttl: 0
```

For a recipe, call its own launcher from the wrapper instead (`models.d/<id>.sh`, `model_run()` runs the
recipe's `start.sh` with the recipe's documented overrides). Both MiaAI-Lab recipes read `HOST`, `PORT` and
`CONTAINER_NAME` from the environment and default to `HOST=0.0.0.0`, `PORT=8888`: set
`HOST=127.0.0.1 PORT="$PORT" CONTAINER_NAME="$MODEL_ID"`, and confirm with `ss -ltnp` that nothing listens
on 0.0.0.0. Recipe containers do not carry the `llm-stack.role=engine` label unless the recipe adds it.

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (native default `127.0.0.1:8080`, which collides with
  llama-swap, so always pass `--port`). Recipes default to 8888.
- **Health:** `GET /health` (no model load; one model per process). `/metrics` reports CUDA and pinned memory.
- **Auth:** loopback accepts local clients without a key; do not set `--api-key`/`--api-key-file` behind
  the gateway. If you must, use `--api-key-file` (restricted permissions), never `--api-key` on a command line.
- **APIs:** OpenAI chat completions, completions and Responses, plus Anthropic `/v1/messages`.
  `/v1/models` (also `/models`) includes `context_length` and `max_model_len` when the window is finite.
- **LiteLLM entry:**

```yaml
- model_name: nemotron-tf
  litellm_params:
    model: openai/nemotron-tf
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Operating

- Start/stop via llama-swap; for recipes, `./start.sh`, `./start.sh restart` and `./stop.sh`.
- Logs: llama-swap `/logs/stream/<id>` for the native binary; `docker logs -f <container>` for recipes. The
  dual recipe saves each rank's log on stop and logs rank 1 on the worker (`ssh node-b docker logs ...`).
- The dual recipe documents `FOREGROUND=1 ./start.sh` for running under a systemd unit.
- Update (archive): download and verify the new archive next to the old one, repoint `current`, restart,
  benchmark; keep the previous directory for rollback.
- Update (recipe): `git fetch`, read the log and diff `scripts/config.sh`, patches and the pinned TensorFold
  ref before pulling; re-check that your overrides still apply (see updating.md).

## Tuning knobs worth knowing

- `--context N`: prompt + reply bound; startup prints the capacity and memory it fitted.
- `--parallel N`: requests sharing lanes (`auto` default). Recipes set their own values.
- `--max-tokens N`: default reply limit (4096); requests override.
- `--reasoning-effort low|medium|high|xhigh`, `--thinking` / `--no-thinking`, `--thinking-budget N`.
- `--prompt-cache-gib GIB`: retained-prefix budget (16 GiB default on CUDA, inside the memory budget; `0` off).
- `--alias NAME` (repeatable) for extra model IDs; `--compact-at auto` opts into context compaction.
- `--no-drafts` serves the plain reference, useful for A/B quality gates.
- Recipe knobs such as `PARALLEL`, `KV_DTYPE`, `KV_POOL_GB`, `TENSORFOLD_MEMORY_RESERVE_GIB` are recipe
  settings, not TensorFold flags; change them only through the recipe's config.

## Known pitfalls

- Unqualified model/platform pairs are refused or unsupported; "it runs on Metal" does not mean CUDA.
- Port 8080 default collides with llama-swap; recipe `HOST=0.0.0.0` default bypasses the gateway.
- Recipes that pin a large KV pool or set a zero memory reserve hold most of a Spark's memory from the first
  second: put them in an exclusive llama-swap group and never co-locate other engines.
- The dual recipe needs key-based SSH to node-b, a RoCE-capable CX7 link and matching images on both nodes.
- Recipe READMEs contain their own performance tables; do not quote them as your baseline, measure yours.

## Official links

- Repo, README (qualified models, serve flags): https://github.com/ashhart/TensorFold
- Install runbook: https://github.com/ashhart/TensorFold/blob/main/RUNBOOK.md
- Releases: https://github.com/ashhart/TensorFold/releases
- MiaAI-Lab recipes: https://github.com/MiaAI-Lab/Qwen3.8-27B-DGX-Spark-TensorFold,
  https://github.com/MiaAI-Lab/Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold
