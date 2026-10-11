# Chatterbox

An agent skill for installing and running [Chatterbox](https://github.com/resemble-ai/chatterbox), Resemble AI's MIT-licensed open text-to-speech family. It helps an agent choose between Turbo, Nano, Multilingual V3, the Single Language Pack and the original model, install them without breaking PyTorch pins, generate and tune speech with zero-shot cloning, and keep the PerTh watermark and voice consent in place.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill chatterbox
```

## Rules

- **Ask before changing the system.** Installs pin torch 2.6.0 and transformers 5.2.0; use a dedicated virtualenv.
- **Source for Nano and V3.** PyPI 0.1.7 lacks both.
- **Consent.** Clone only voices you have permission to use; never strip the watermark.
- **Demos are not safe defaults.** Two call `share=True` and one starts an MCP server.
- **Match model and class.** Turbo and Nano ignore `exaggeration` and `cfg_weight`.

## References

- [`references/models.md`](references/models.md): model zoo, classes, Hub repos, languages.
- [`references/install.md`](references/install.md): PyPI versus source, pins, devices, downloads.
- [`references/usage.md`](references/usage.md): code per model, signatures, tags, tuning, voice conversion.
- [`references/serving.md`](references/serving.md): demo apps and their exposure, writing a service.
- [`references/safety-and-licences.md`](references/safety-and-licences.md): watermark check, licences, consent.
- [`references/updating.md`](references/updating.md): release state, upgrade, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/requirements-lock.txt.example`](templates/requirements-lock.txt.example): freeze recipe.
- [`scripts/say.sh`](scripts/say.sh): one-shot WAV generation.

## Companion skills

- `f5-tts`: another zero-shot cloner (CC-BY-NC weights).
- `kokoro-fastapi`: fixed-voice TTS with an OpenAI-compatible API.
- `speaches`: OpenAI-compatible speech server.
- `self-hosted-genmedia`: choose and place speech stacks.
- `hugging-face`: model cache and tokens.

## License

MIT
