# F5-TTS: updating

> Verified against F5-TTS 1.1.22 (GitHub releases, PyPI, pyproject.toml), 2026-10-11

## What is current

```bash
pip index versions f5-tts 2>/dev/null | head -1
curl -s https://pypi.org/pypi/f5-tts/json | jq -r .info.version
gh api repos/SWivid/F5-TTS/releases --jq '.[:6][]|[.tag_name,.published_at]|@tsv'
pip list 2>/dev/null | grep -iE '^(f5-tts|torch|torchaudio|gradio|transformers) '
```

On 2026-10-11 the newest release was 1.1.22 (2026-07-23), after 1.1.21 (2026-07-05), 1.1.20 (2026-04-20), 1.1.19 (2026-04-16) and 1.1.18 (2026-03-24). The repository had a commit the same day (seed clamp fix), so the default branch can be ahead of PyPI.

## Upgrade

```bash
pip install --upgrade f5-tts            # inside the virtualenv, with PyTorch already installed
f5-tts_infer-cli --help | head -5
```

- Release notes and `git log` first: model names, defaults and the Gradio major version (`gradio>=6.15.0`) change.
- Editable installs: `git pull && pip install -e .`.
- Do not mix the `eval` extra's old `faster_whisper==0.10.1` pin into a normal environment.
- The Docker tag `main` floats; pull again to update, or build a tag you control.

## Pin and roll back

```bash
pip freeze | grep -iE '^(f5-tts|torch|torchaudio|gradio|transformers)' > constraints.txt
pip install 'f5-tts==1.1.22'
```

Checkpoints are separate files in the Hugging Face cache; upgrading the package does not change them. Pin a checkpoint with `--ckpt_file` to a local path. After any upgrade, regenerate a fixed sentence with a fixed seed (`F5TTS.infer(seed=...)`) and compare by ear.
