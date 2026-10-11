---
name: llamafile
description: Runs and packages LLMs as single-file executables with llamafile (llama.cpp plus Cosmopolitan), with chat, CLI and OpenAI and Anthropic compatible server modes on CPU, Metal, CUDA, Vulkan and ROCm. Use for llamafile, .llamafile, zipalign, .args, whisperfile, APE loader, run-detectors error, 4GB Windows limit. Other engines go to choosing-inference-engine.
license: MIT
compatibility: Linux, macOS, Windows 10+, FreeBSD, NetBSD, OpenBSD on x86-64 (AVX required) or ARM64. Downloads of multi-GB files, system changes (binfmt, services) and exposing a port need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# llamafile

Run or ship an LLM as one portable file: the llamafile runtime (llama.cpp built with Cosmopolitan Libc) plus GGUF weights and default arguments, or the bare runtime with external weights.

**Scope:** this one product: running pre-built or self-made llamafiles, the server API, GPU setup, packaging with `zipalign`, sandboxing, updates and troubleshooting. Whisperfile and the other bundled programs are covered briefly. Other engines belong to `choosing-inference-engine`; a full llama.cpp deployment belongs to `llama-cpp`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
uname -sm; command -v llamafile; ls -lh ./*.llamafile ~/llamafile* 2>/dev/null | head
./llamafile --version 2>&1 | head -2                          # or ./Model.llamafile --version
grep -o -m1 -w -E 'avx2|avx512f|avx' /proc/cpuinfo 2>/dev/null | head -1
nvidia-smi --query-gpu=name,memory.total --format=csv 2>&1 | head -3
command -v vulkaninfo >/dev/null && vulkaninfo --summary 2>&1 | head -5
ls -d "${TMPDIR:-/tmp}"/.ape-* ~/.llamafile 2>/dev/null
cat /proc/sys/fs/binfmt_misc/APE 2>/dev/null | head -2         # APE binfmt registration, if any
ss -ltnp 2>/dev/null | grep -E ':8080\b'
curl -s -m 3 http://127.0.0.1:8080/health
```

## Decision flow

1. **Is llamafile the right tool?** Choose it for zero-install, portable, single-file distribution, offline demos, or running one model on whatever machine is at hand. For multi-user throughput, many models or tuned GPU serving use `vllm`, `llama-cpp` or `ollama`.
2. **Which file?** A pre-built `*.llamafile` (weights bundled), or the `llamafile` runtime from the release plus a GGUF (`-m`). Windows runs only executables under 4 GB, so use external weights there (`references/install.md`).
3. **Which mode?** No flag starts combined mode (terminal chat plus server on 8080). Use `--server` for a service, `--cli -p` for scripts, `--chat` for a terminal UI (`references/serve-config.md`).
4. **GPU?** `-ngl 999` offloads on NVIDIA and AMD; Metal is on by default on Apple silicon. Pick the backend with `--gpu` and note the sandbox is skipped on GPU (`references/performance-tuning.md`, `references/security-and-sandbox.md`).
5. **Serve securely.** Loopback by default; add `--api-key-file` before any `--host 0.0.0.0`; never enable `--tools` on a reachable server without a key (`references/security-and-sandbox.md`).
6. **Package your own** with `zipalign` and an `.args` file (`references/building-llamafiles.md`).
7. **Broken?** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Multi-GB downloads, `binfmt_misc` registrations, services, firewall or Gatekeeper changes and exposure need approval. Never suggest `spctl --master-disable` as a fix.
- **Only run llamafiles you trust.** A llamafile is an executable; its author controls whether it sandboxes itself. Prefer the official `mozilla-ai` releases and Hugging Face org, and check the sha256 when one is published.
- **Secrets never touch output.** Keep the API key in a `0600` file and use `--api-key-file`, not `--api-key` (the latter shows in `ps`). Keep `HF_TOKEN` in the environment.
- **Bind loopback unless needed.** Combined mode and `--tools` change the risk: see the security reference. CORS is not authentication.
- **Flags are version scoped.** Each mode has its own `--help`; use the help of the file you run. Old `--mmap`, `--no-mmap` and `--mlock` are translated to `--load-mode` with a warning.
- **Verify upstream.** Verified against llamafile 0.10.6 (main `a3ccf09`) on 2026-10-11. The 0.10.* line is a rebuild; some 0.9 features are missing (`references/updating.md`).

## Workflows

- [ ] Get a llamafile or the runtime and GGUF -> `references/install.md`
- [ ] Run in chat, CLI, server or combined mode -> `references/serve-config.md`
- [ ] Choose models and quantizations -> `references/models-and-formats.md`
- [ ] Smoke test the API -> `references/api.md`
- [ ] GPU backends, offload, multi-GPU, memory -> `references/performance-tuning.md`, `references/parallelism-multinode.md`
- [ ] Tools, multimodal, embeddings, whisperfile -> `references/features.md`
- [ ] Sandbox, auth, exposure -> `references/security-and-sandbox.md`
- [ ] Build your own llamafile -> `references/building-llamafiles.md`
- [ ] LiteLLM, SDK, systemd -> `references/integrations.md`, `templates/`
- [ ] Health, metrics, logs -> `references/observability.md`
- [ ] Update or pin a version -> `references/updating.md`
- [ ] Verify: `/health` is ok, `/v1/models` lists the model, a chat completion returns text, and the startup log shows the expected backend and layers offloaded.

## Quick smoke test

```bash
curl -LO https://huggingface.co/mozilla-ai/llamafile_0.10/resolve/main/Qwen3.5-0.8B-Q8_0.llamafile   # upstream quick start model, 1.6 GB
chmod +x Qwen3.5-0.8B-Q8_0.llamafile                                                                   # Windows: rename to .exe
./Qwen3.5-0.8B-Q8_0.llamafile --server --host 127.0.0.1 --port 8080 &
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' \
  | jq -r '.choices[0].message.content'
```

## Reference index

- `references/install.md`: release files, `llamafile` vs `-thin`, external weights, OS and CPU support, Windows 4 GB limit.
- `references/serve-config.md`: modes, common flags, `.args`, load mode, router mode.
- `references/models-and-formats.md`: GGUF, pre-built list, third-party model stores, quantization notes.
- `references/parallelism-multinode.md`: multi-GPU split, `--rpc`, what is not supported.
- `references/features.md`: tools, agent mode, multimodal, embeddings, rerank, structured output, whisperfile.
- `references/api.md`: endpoints, auth headers, tool calling shapes.
- `references/performance-tuning.md`: GPU backends and libraries, offload, context, threads, slots.
- `references/security-and-sandbox.md`: pledge, confine-reads, tools, exposure.
- `references/building-llamafiles.md`: zipalign, `.args`, source build, distribution.
- `references/integrations.md`: LiteLLM, OpenAI SDK, systemd, containers.
- `references/observability.md`: health, metrics, slots, logs.
- `references/updating.md`: versions, 0.9 to 0.10 differences, pinning.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: `llamafile.service`, `model.args`, `litellm-llamafile.yaml`.

## Companion skills

- `choosing-inference-engine`: compare engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llama-cpp`: the engine inside llamafile. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `whisper-cpp`: the engine behind whisperfile. Install: `npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp`.
- `ollama`: model-manager alternative. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `litellm`: gateway and keys. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `self-hosted-llms`: the end-to-end stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
