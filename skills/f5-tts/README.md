# F5-TTS

An agent skill for installing and running [F5-TTS](https://github.com/SWivid/F5-TTS), the flow-matching zero-shot voice-cloning text-to-speech model. It helps an agent install PyTorch for the right device, prepare a good reference clip, run `f5-tts_infer-cli` or the `F5TTS` Python class, use the Gradio app or socket server on loopback, find community language checkpoints, and flag the licence and consent limits.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill f5-tts
```

## Rules

- **Licence first.** Code is MIT; the pretrained weights are CC-BY-NC (non-commercial).
- **Consent.** Clone only voices you have permission to use.
- **Short, clean reference.** Under 12 s, trailing silence, an exact transcript.
- **Loopback only.** Gradio, `--share` and the socket server have no auth.
- **Ask before installing.** PyTorch wheels and checkpoints are large downloads.

## References

- [`references/install.md`](references/install.md): PyTorch per device, pip and editable installs, Docker.
- [`references/inference.md`](references/inference.md): CLI, TOML, multi-voice, Python API, tuning, text rules.
- [`references/serving.md`](references/serving.md): Gradio app, socket server, TensorRT-LLM, wrapping in a service.
- [`references/models-and-licences.md`](references/models-and-licences.md): checkpoints, community languages, licences.
- [`references/training.md`](references/training.md): dataset prep and fine-tuning entry points.
- [`references/updating.md`](references/updating.md): releases, pin and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/f5-basic.toml`](templates/f5-basic.toml): CLI config.
- [`scripts/clone.sh`](scripts/clone.sh): guard-railed CLI wrapper.

## Companion skills

- `kokoro-fastapi`: fixed-voice TTS with an OpenAI-compatible API.
- `chatterbox`: another zero-shot cloner with an MIT licence.
- `self-hosted-genmedia`: choose and place speech stacks.
- `faster-whisper`: transcribe reference clips.
- `hugging-face`: model cache and tokens.

## License

MIT
