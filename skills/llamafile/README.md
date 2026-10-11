# llamafile

Agent skill for running and packaging LLMs as single-file executables with llamafile (llama.cpp plus Cosmopolitan Libc): pre-built and self-made `.llamafile` files, the `llamafile` runtime with external GGUF, chat, CLI and server modes with OpenAI and Anthropic compatible APIs, GPU backends (Metal, CUDA, Vulkan, ROCm), `zipalign` and `.args` packaging, the pledge and unveil sandbox, built-in tools, whisperfile, and troubleshooting.

Verified against llamafile 0.10.6 (main `a3ccf09`) on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill llamafile
```

## Rules

- **Ask before changing the system.** Multi-GB downloads, `binfmt_misc`, services and exposure need approval.
- **A llamafile is a program.** Run only trusted files; prefer official `mozilla-ai` releases.
- **Secrets never touch output.** Use `--api-key-file` with a `0600` file.
- **Bind loopback.** Add a key and TLS before any network exposure; keep `--tools` off reachable servers.
- **GPU mode is not sandboxed.** Know which mode you run.

## References

- [`references/install.md`](references/install.md): release files, external weights, supported systems.
- [`references/serve-config.md`](references/serve-config.md): modes, flags, `.args`, router mode.
- [`references/models-and-formats.md`](references/models-and-formats.md): GGUF, pre-built list, third-party stores.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): multi-GPU and limits.
- [`references/features.md`](references/features.md): tools, multimodal, embeddings, whisperfile.
- [`references/api.md`](references/api.md): endpoints and auth.
- [`references/performance-tuning.md`](references/performance-tuning.md): GPU libraries, offload, memory.
- [`references/security-and-sandbox.md`](references/security-and-sandbox.md): sandbox, exposure, supply chain.
- [`references/building-llamafiles.md`](references/building-llamafiles.md): zipalign and source builds.
- [`references/integrations.md`](references/integrations.md): LiteLLM, SDKs, systemd.
- [`references/observability.md`](references/observability.md): health, metrics, logs.
- [`references/updating.md`](references/updating.md): versions and 0.9 to 0.10 differences.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`templates/`](templates): systemd unit, `.args` file, LiteLLM config.

## Companion skills

- `choosing-inference-engine`: compare engines.
- `llama-cpp`, `whisper-cpp`: the engines inside llamafile and whisperfile.
- `litellm`: gateway.
