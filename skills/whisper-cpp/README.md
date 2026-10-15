# whisper.cpp

An agent skill for building, running and tuning whisper.cpp, the C/C++ Whisper speech-to-text engine. It helps an agent pick a backend build (Metal, Core ML, CUDA, Vulkan, CPU), download or quantize ggml models, transcribe with `whisper-cli`, run `whisper-server` on loopback, mount it at the OpenAI `/v1/audio/transcriptions` path, and put it behind llama-swap and LiteLLM. Built on [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill whisper-cpp
```

## Rules

- **Loopback only.** `whisper-server` has no auth and accepts uploads and a `/load` route that reads server-side paths.
- **Set the language.** The default is `en`; use `-l auto` or the language code.
- **Verify upstream.** README and source disagree in places (flash attention default, `quantize` vs `whisper-quantize`); trust `-h` of the installed build.
- **Secrets stay out of output.** Tokens come from environment variables or `0600` files.

## References

- [`references/install.md`](references/install.md): CMake builds per backend, Docker platform caveat, binaries produced.
- [`references/cli.md`](references/cli.md): `whisper-cli` flags, outputs, VAD, benchmarking.
- [`references/serve-configuration.md`](references/serve-configuration.md): `whisper-server` flags, path mapping, concurrency, security, service unit.
- [`references/api.md`](references/api.md): routes, form fields, response formats, error bodies, OpenAI gaps.
- [`references/models.md`](references/models.md): model names, sizes, quantization, tinydiarize, VAD files.
- [`references/performance-memory.md`](references/performance-memory.md): backends, Core ML, threads, memory.
- [`references/integrations.md`](references/integrations.md): OpenAI SDKs, llama-swap, LiteLLM.
- [`references/updating.md`](references/updating.md): releases, rebuild, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/llama-swap-litellm.md`](references/combos/llama-swap-litellm.md): whisper-server in llama-swap with LiteLLM in front.
- [`templates/`](templates): systemd unit, llama-swap and LiteLLM entries.
- [`scripts/transcribe.sh`](scripts/transcribe.sh): transcribe a file through a running server (bash, curl, jq).

## Companion skills

- `self-hosted-genmedia`: compare Speaches and vLLM for STT, plus image and speech servers.
- `llama-swap`: hot-swap whisper with LLMs on one GPU.
- `litellm`: keys, budgets and routing in front.
- `hugging-face`: model weights and cache.
- `nvidia-dgx-spark`: arm64 unified-memory platform notes.

## License

MIT
