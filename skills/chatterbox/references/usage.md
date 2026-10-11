# Chatterbox: usage and tuning

> Verified against resemble-ai/chatterbox master (README, example__.py, src/chatterbox/_.py), 2026-10-11

All examples save with `torchaudio.save(path, wav, model.sr)`. `generate` returns a `(1, samples)` tensor, already watermarked.

## Turbo and Nano

```python
import torchaudio as ta
from chatterbox.tts_turbo import ChatterboxTurboTTS

model = ChatterboxTurboTTS.from_pretrained(device="cuda")        # nano=True for Nano; "cpu" works
wav = model.generate("Oh, that's hilarious! [chuckle] Anyway, shall we start?")
ta.save("turbo.wav", wav, model.sr)

# clone a voice (reference clip: you have permission to use it)
wav = model.generate("Hello there.", audio_prompt_path="ref.wav")
```

Without `audio_prompt_path` the model uses the built-in voice from `conds.pt`. The upstream example comment says a reference clip is "required for voice cloning", not for generation.

Signature (source): `generate(text, repetition_penalty=1.2, min_p=0.00, top_p=0.95, audio_prompt_path=None, exaggeration=0.0, cfg_weight=0.0, temperature=0.8, top_k=1000, norm_loudness=True)`. Per the README, `exaggeration`, `cfg_weight` and `min_p` are ignored by Turbo; do not tune with them.

### Paralinguistic tags

Written inline in the text. The Gradio Turbo app's tag buttons list: `[clear throat]`, `[sigh]`, `[shush]`, `[cough]`, `[groan]`, `[sniff]`, `[gasp]`, `[chuckle]`, `[laugh]`. The README says "and more" for the model; treat other tags as unverified and test them.

## Multilingual

```python
from chatterbox.mtl_tts import ChatterboxMultilingualTTS
m = ChatterboxMultilingualTTS.from_pretrained(device="cuda", t3_model="v3")   # omit for legacy V2
wav = m.generate("Bonjour, comment ça va ?", language_id="fr", audio_prompt_path="ref_fr.wav")
```

Signature: `generate(text, language_id, audio_prompt_path=None, exaggeration=0.5, cfg_weight=0.5, temperature=0.8, repetition_penalty=1.2, min_p=0.05, top_p=1.0)`. `t3_model` accepts `"v2"`, `"v3"` or a `.safetensors` filename in the repo. `t3_model` is absent from the PyPI 0.1.7 wheel (checked by reading its `mtl_tts.py`), so V3 needs a source install (`install.md`).

Single Language Pack models have their own Hub repos and README snippets; read the model card for the exact load call.

## Original English

```python
from chatterbox.tts import ChatterboxTTS
m = ChatterboxTTS.from_pretrained(device="cuda")
wav = m.generate("Text.", audio_prompt_path="ref.wav", exaggeration=0.5, cfg_weight=0.5)
```

Signature: `generate(text, repetition_penalty=1.2, min_p=0.05, top_p=1.0, audio_prompt_path=None, exaggeration=0.5, cfg_weight=0.5, temperature=0.8)`. Without a prompt you must have called `prepare_conditionals` first or the call asserts.

## Tuning (upstream tips)

- Defaults `exaggeration=0.5`, `cfg_weight=0.5` suit most prompts.
- Reference speaker talks fast: lower `cfg_weight` to about 0.3.
- Expressive or dramatic: `cfg_weight` about 0.3 and `exaggeration` 0.7 or higher. Higher exaggeration speeds speech up; lower `cfg_weight` slows it back down.
- Reference language differs from the target: set `cfg_weight=0` to reduce accent carry-over.
- Reference clip: upstream's examples name it `your_10s_ref_clip.wav`; the conditioning code truncates the decoder reference to the first 10 seconds. Use clean, single-speaker audio.

## Long text

The classes do not chunk for you. Split on sentences in your own code, generate each, and concatenate with `torch.cat`. Keep one loaded model; reloading per request is slow.

## Voice conversion

```python
from chatterbox.vc import ChatterboxVC
vc = ChatterboxVC.from_pretrained("cuda")
wav = vc.generate(audio="source.wav", target_voice_path="target.wav")
```

Output is watermarked too. Same consent rules apply to the target voice.
