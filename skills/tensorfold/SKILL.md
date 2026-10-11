---
name: tensorfold
description: Installs, serves, tunes and troubleshoots TensorFold (`tensorfold-native`), a Zig LLM inference engine for Apple Silicon and NVIDIA GPUs with exact speculative decoding. Use for ashhart/TensorFold, `tensorfold serve`, qualified models (Nemotron 3.5 Lightning, Qwen3.8), GB10 or DGX Spark, MiaAI-Lab recipes, dual-Spark TP=2, Living Weights, and errors such as CUDA_ERROR_NO_BINARY_FOR_GPU. For other engines use vllm, sglang or llama-cpp.
license: MIT
compatibility: macOS on Apple Silicon (Metal) or Linux with an NVIDIA driver (aarch64 GB10, x86_64 Ampere sm_86 / Blackwell sm_120). Needs curl and jq. Installs, services, network exposure and any model weight download need explicit user approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# TensorFold

TensorFold ([ashhart/TensorFold](https://github.com/ashhart/TensorFold), Apache-2.0, Zig, homepage tensorfold.dev) serves a short list of **qualified** model and platform pairs from one native binary with no Python in the serving path. Accepted speculative drafts must equal what the plain engine would emit. This skill gets an agent from "is my model and box supported?" to a verified OpenAI-compatible endpoint, then through tuning, multi-node, updates and failures.

**Scope:** this one product (release line 1.0.x, verified against v1.0.7). Choosing between engines belongs to `self-hosted-llms`; routing and model swapping belong to `llm-gateway` and `llama-swap`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secrets.

```bash
uname -sm; command -v tensorfold tensorfold-native
for b in tensorfold tensorfold-native; do command -v "$b" >/dev/null && "$b" --version; done
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv 2>/dev/null   # Linux CUDA
free -g 2>/dev/null | head -2; df -h . | tail -1
ss -ltnp 2>/dev/null | grep -E ':(8080|8888)\b'                                   # default ports
curl -fsS http://127.0.0.1:8080/health 2>/dev/null; curl -fsS http://127.0.0.1:8080/v1/models 2>/dev/null | jq .
tensorfold-native capabilities --json 2>/dev/null | jq . | head -40              # authoritative flags and env vars
```

## Decision flow

1. **Model and platform must be qualified.** Check `references/models-and-formats.md`. If the pair is not listed, stop and say so; do not try to force it. Other engines: `vllm`, `sglang`, `llama-cpp`.
2. **Mac (Apple Silicon):** `brew install ashhart/tensorfold/tensorfold` or the macOS archive (`references/install.md`).
3. **Linux CUDA, one GPU:** release archive `linux-aarch64` (GB10) or `linux-x86_64` (RTX 30 series / RTX PRO 6000 class). Native CUDA serves **Nemotron 3.5 Lightning only** in 1.0.7.
4. **DGX Spark and a different model (Qwen3.8-27B, Flash Next, two Sparks):** those run via community MiaAI-Lab recipes on older or patched engine builds. Read `references/combos/miaai-lab-recipes.md` and, for two nodes, `references/combos/dgx-spark-dual.md`.
5. **Behind a gateway or llama-swap:** pass an explicit `--port` (the default 8080 collides) and `--host 127.0.0.1`; see `references/integrations.md`.
6. **Something broke:** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Downloads (checkpoints are tens of GB), services, firewall, `--host 0.0.0.0` and model-folder writes need approval and an undo path.
- **Secrets never touch output.** Use `--api-key-file` (mode `0600`, startup refuses looser) or `TENSORFOLD_API_KEY`, never `--api-key` on a command line. Do not echo `HF_TOKEN`.
- **Do not extrapolate support.** "Runs on Metal" does not mean CUDA; the Python 0.6.6 engine's families are not the native binary's.
- **`capabilities --json` beats this skill.** If it disagrees with a flag here, trust the binary and note the version.
- **Always pass `--port` and `--name`** when more than one server or a gateway exists.
- **Living Weights (`--slide`) rewrites the model folder.** Only ever on a copy; nothing undoes a learned fact.
- **Do not quote recipe benchmark tables as your baseline.** Measure with `scripts/bench.sh` from `self-hosted-llms` if you need numbers.

## Workflows

- [ ] Qualify the pair -> `references/models-and-formats.md`
- [ ] Install and check the version -> `references/install.md`
- [ ] Fetch the checkpoint (`tensorfold pull`, `models`, `info`) -> `references/models-and-formats.md`
- [ ] Serve with explicit `--name --host --port --context --parallel` -> `references/serve-config.md`
- [ ] Verify: `/health`, `/v1/models`, one chat completion with the served name
- [ ] Wire a client, gateway or llama-swap -> `references/integrations.md`, `references/api.md`
- [ ] Run as a service -> `templates/tensorfold.service`, `templates/llama-swap.yaml`
- [ ] Monitor -> `references/observability.md`
- [ ] Tune context, `--parallel`, prompt cache -> `references/performance-tuning.md`
- [ ] Two nodes -> `references/parallelism-multinode.md`
- [ ] Update or roll back -> `references/updating.md`

## Minimal commands

```bash
tensorfold pull TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit   # Hugging Face cache, sha-verified
tensorfold-native serve ~/models/nemotron-lightning --name local-model \
  --host 127.0.0.1 --port 8090 --context 8192 --parallel 1 --temperature 0 --no-thinking
curl -fsS http://127.0.0.1:8090/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Say hello."}],"max_tokens":64}'
```

## Reference index

- `references/install.md`: macOS (Homebrew, archive), Linux CUDA archives, Python 0.6.6 legacy line, building from source.
- `references/serve-config.md`: every serve flag, defaults, env vars, auth, service wrappers.
- `references/models-and-formats.md`: qualified matrix, checkpoint formats, `pull`/`models`/`info`, what is not supported.
- `references/parallelism-multinode.md`: lanes, `--parallel`, two-Mac `--speed-up`, two-Spark TP=2 via recipes.
- `references/features.md`: exact decoding, prompt cache, `--learn`, compaction, Living Weights, vision, `tensorfold service`/`tui`.
- `references/api.md`: routes, request fields, Responses, Messages, decisions, tokenize.
- `references/performance-tuning.md`: memory fitting, context vs parallel, cache, thermals, FP8 trade-offs.
- `references/integrations.md`: llama-swap, LiteLLM, OpenAI/Anthropic clients, Claude Code, systemd.
- `references/observability.md`: `/health`, `/metrics`, `--dashboard`, `/memory`, logs.
- `references/updating.md`: Homebrew, archives, recipes, rollback, release line caveats.
- `references/troubleshooting.md`: symptoms, causes, fixes, known issues.
- `references/combos/miaai-lab-recipes.md`: MiaAI-Lab DGX Spark recipes built on TensorFold.
- `references/combos/dgx-spark-dual.md`: Qwen3.8-Flash-Next on two DGX Sparks.
- `templates/`: systemd unit and llama-swap entry.

## Companion skills

- `nvidia-dgx-spark`: GB10 hardware, CX7 links, memory behaviour. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
- `llama-swap`: model swapping in front of engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: gateway entries and keys. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `self-hosted-llms`: engine choice, stack and benchmarking. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `multi-node-inference`: general multi-node concerns. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference`.
- `speculative-decoding`: draft concepts. Install: `npx skills add ScaleDockHQ/llms-skills --skill speculative-decoding`.
