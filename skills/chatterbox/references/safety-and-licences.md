# Chatterbox: safety and licences

> Verified against resemble-ai/chatterbox master (LICENSE, README, tts_turbo.py) and the Hub model cards, 2026-10-11

## Licences

- Code: MIT (GitHub licence field, `LICENSE`).
- Hub model cards checked: `chatterbox-turbo` is `mit`; the Single Language Pack repos for `zh-cmn`, `hi` and `pt-br` are `mit`. Read each card you actually deploy; the others were not individually opened.
- Dependencies carry their own licences (for example the `Perth` repository is MIT).

## Watermark

Every output from `generate` passes through Resemble's PerTh implicit watermarker (`apply_watermark` at the end of generation, in TTS and VC). The README says the mark survives MP3 compression and common edits; that is the vendor's claim.

Check a file:

```python
import librosa, perth
audio, sr = librosa.load("out.wav", sr=None)
print(perth.PerthImplicitWatermarker().get_watermark(audio, sample_rate=sr))   # 1.0 watermarked, 0.0 not
```

Removing or bypassing the watermark is against the project's responsible-AI intent; do not help with it.

## Consent and use

- Clone only voices you own or have written permission for. Record and store that permission with the reference clip.
- Disclose synthetic audio where law or platform rules require it.
- Reference clips are personal data; keep them out of shared caches and repos.
- Upstream disclaimer: do not use the model for anything harmful.
