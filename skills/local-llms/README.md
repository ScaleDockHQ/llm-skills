# Local LLMs Skill

An agent skill for running open-weight LLMs on your own laptop or desktop with [Ollama](https://github.com/ollama/ollama), [LM Studio](https://lmstudio.ai), [llama.cpp](https://github.com/ggml-org/llama.cpp), or [MLX](https://github.com/ml-explore/mlx-lm). It discovers the hardware first (Apple Silicon unified memory, NVIDIA, AMD, Intel, CPU-only). It then picks the native accelerator path, sizes the model and context to fit, and serves an OpenAI- or Anthropic-compatible endpoint on localhost. It also covers sharing that endpoint safely, benchmarking it with a fixed protocol, and fixing it when it gets slow or breaks. Covers macOS, Windows (native and WSL2), and Linux desktops. For dedicated servers, use the companion `self-hosted-llms` skill.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill local-llms
```

## Rules

- **Size before you download.** Weights + KV cache + OS headroom must fit in GPU or unified memory.
- **Bind to localhost unless you mean it.** Change the bind only with explicit consent and auth in place.
- **One runtime per port.** Ollama 11434, LM Studio 1234, llama-server 9931 (8080 on older builds), mlx_lm.server 8080.
- **Measure before and after.** Same fixed benchmark protocol for every change.
- **Prefer the native accelerator path.** Metal/MLX on Apple Silicon, CUDA on NVIDIA, ROCm or Vulkan on AMD.
- **Confirm it's on the GPU.** Check before blaming the model.
- **Ask before changing the system.** Installers, sysctl, firewall rules, and services need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables, never in logs or chat.

## References

`SKILL.md` holds the discovery commands, decision flow, rules, and workflow checklists. The references are loaded only when a step needs them.

- [`references/choosing-a-runtime.md`](references/choosing-a-runtime.md): Ollama vs LM Studio vs llama.cpp vs MLX, plus Jan.
- [`references/sizing.md`](references/sizing.md): bits per weight by quant, KV cache formula, headroom, offloading.
- [`references/macos-apple-silicon.md`](references/macos-apple-silicon.md): unified memory, Metal, MLX, the `iogpu.wired_limit_mb` sysctl and its risks, thermals.
- [`references/windows.md`](references/windows.md): CUDA, AMD ROCm/Vulkan, WSL2 vs native, firewall prompts.
- [`references/linux-desktop.md`](references/linux-desktop.md): drivers, CUDA/ROCm/Vulkan builds, systemd user services.
- [`references/ollama.md`](references/ollama.md): install, environment variables, endpoints, pitfalls.
- [`references/lm-studio.md`](references/lm-studio.md): GUI, `lms` CLI, llmster headless daemon, API tokens.
- [`references/llamacpp.md`](references/llamacpp.md): `llama-server` install, flags, auth, router mode.
- [`references/mlx.md`](references/mlx.md): `mlx-lm` install and `mlx_lm.server` flags.
- [`references/sharing-on-lan.md`](references/sharing-on-lan.md): SSH tunnel, Tailscale Serve, API keys, firewall rules.
- [`references/benchmarking.md`](references/benchmarking.md): a fixed protocol with `scripts/bench.sh`, and fair comparisons.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom → cause → fix.
- [`templates/`](templates/): systemd user unit and launchd plist for `llama-server`, plus an Ollama Modelfile.

`scripts/bench.sh` is shared with `self-hosted-llms`. It's bash 3.2-compatible and needs `curl` and `jq`.

Credit: the commands and defaults come from the upstream docs for [Ollama](https://docs.ollama.com), [LM Studio](https://lmstudio.ai/docs), [llama.cpp](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md), [mlx-lm](https://github.com/ml-explore/mlx-lm), and [Tailscale](https://tailscale.com/kb/1312/serve).

## Companion skills

From [ScaleDockHQ/llms-skills](https://github.com/ScaleDockHQ/llms-skills); install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `choosing-llm-hosting`: local vs self-hosted vs cloud.
- `self-hosted-llms`: your own servers, DGX Spark, vLLM/SGLang, multi-user serving.
- `cloud-llms`: hosted APIs and GPU clouds.
- `llm-clients`: connect Claude Code, Codex, OpenCode, Aider, Cursor, Continue, Cline/Roo/Kilo, Open WebUI, LobeHub, SDKs.
- `llm-gateway`: one endpoint over several backends.
- `model-quantization`: produce GGUF/MLX/EXL3 quants.
- `fine-tuning-llms`, `llm-evals`, `llm-observability`, `self-hosted-genmedia`.

## License

MIT
