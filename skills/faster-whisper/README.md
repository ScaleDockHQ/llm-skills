# faster-whisper

An agent skill for installing, running and tuning [faster-whisper](https://github.com/SYSTRAN/faster-whisper), the CTranslate2 reimplementation of OpenAI Whisper for Python. It helps an agent pick the device and `compute_type`, set up CUDA 12 libraries, transcribe with `WhisperModel` or the batched pipeline, use VAD and word timestamps, convert fine-tuned Whisper models, and hand off to Speaches when an HTTP API is needed.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill faster-whisper
```

## Rules

- **Iterate the generator.** `transcribe()` is lazy; nothing decodes until you loop over `segments`.
- **Ask before installing.** `pip install`, GPU libraries and model downloads need approval.
- **Match compute type to device.** `int8` on CPU, `float16` or `int8_float16` on GPU; check `get_supported_compute_types`.
- **No server here.** Use the `speaches` skill for an OpenAI-compatible HTTP API.
- **Secrets stay out of output.** Hub tokens come from the environment or a CLI login.

## References

- [`references/install.md`](references/install.md): pip, CUDA 12 and cuDNN 9, Docker image, source installs.
- [`references/python-api.md`](references/python-api.md): `WhisperModel`, `transcribe()` options, batching, VAD, word timestamps.
- [`references/models.md`](references/models.md): built-in model names, distil and turbo models, conversion, licences.
- [`references/performance-memory.md`](references/performance-memory.md): compute types, batching, threads, upstream benchmarks.
- [`references/integrations.md`](references/integrations.md): Speaches, WhisperX and other projects built on it.
- [`references/updating.md`](references/updating.md): releases, CTranslate2 pairing, pin and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`scripts/doctor.sh`](scripts/doctor.sh): read-only environment check.

## Companion skills

- `speaches`: OpenAI-compatible STT and TTS server built on faster-whisper.
- `whisper-cpp`: C/C++ Whisper engine with ggml models.
- `self-hosted-genmedia`: choose and place speech and image servers.
- `hugging-face`: model downloads and cache.

## License

MIT
