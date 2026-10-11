# F5-TTS: inference

> Verified against F5-TTS 1.1.22 (README, src/f5_tts/infer/README.md, infer_cli.py, api.py, utils_infer.py), 2026-10-11

## Rules for good output (upstream guidance)

- One generation supports **30 s total**, counting the reference and the new audio. `infer_cli` and `infer_gradio` chunk longer text automatically (`chunk_text`, default 135 characters per chunk); the raw `F5TTS.infer` call does not need you to chunk but the 30 s window still applies per generation.
- Reference audio **under 12 s** with about 1 s of silence at the end; otherwise the end may be cut mid-word.
- Uppercase letters (best as `K.F.C.`) are read letter by letter; lowercase words read normally.
- Add spaces or punctuation (`,` `.`) to create pauses. After sentence-ending English punctuation keep a space, or the chunker will not split there.
- Convert digits to Chinese characters if you want them read in Chinese; otherwise they are read in English.
- Silent output means check the FFmpeg installation.
- Try `use_ema=False` for early-stage fine-tuned checkpoints.

## CLI

```bash
f5-tts_infer-cli --model F5TTS_v1_Base \
  --ref_audio ref.wav \
  --ref_text "Exact words spoken in the reference clip." \
  --gen_text "The sentence you want in that voice." \
  --output_dir out --output_file hello.wav
```

`--ref_text ""` transcribes the reference with `openai/whisper-large-v3-turbo` (extra GPU memory). Flags (from `infer_cli.py`): `--config/-c` (toml, default `infer/examples/basic/basic.toml`), `--model`, `--model_cfg`, `--ckpt_file`, `--vocab_file`, `--ref_audio`, `--ref_text`, `--gen_text`, `--gen_file`, `--output_dir`, `--output_file`, `--save_chunk`, `--no_legacy_text`, `--remove_silence`, `--load_vocoder_from_local`, `--vocoder_name` (`vocos` default, `bigvgan`), `--target_rms`, `--cross_fade_duration`, `--nfe_step`, `--cfg_strength`, `--sway_sampling_coef`, `--speed`, `--fix_duration`, `--device`.

Defaults in `utils_infer.py`: `target_rms=0.1`, `cross_fade_duration=0.15`, `nfe_step=32` (16 and 32 are the documented choices), `cfg_strength=2.0`, `sway_sampling_coef=-1.0`, `speed=1.0`, `fix_duration=None`, mel type `vocos`. BigVGAN is only supported with `F5TTS_Base` (`--model F5TTS_Base --vocoder_name bigvgan --load_vocoder_from_local`).

Speed and quality knobs: fewer `nfe_step` is faster and rougher (upstream's TensorRT benchmark uses 16); `speed` changes pace; `--remove_silence` trims long silences in the result.

## TOML config

```toml
model = "F5TTS_v1_Base"          # F5TTS_v1_Base | E2TTS_Base
ref_audio = "ref.wav"
ref_text = ""                     # empty means auto-transcribe
gen_text = "Text to speak."
gen_file = ""                     # a file of text; overrides gen_text
remove_silence = false
output_dir = "out"
```

Run with `f5-tts_infer-cli -c custom.toml`. `templates/f5-basic.toml` is this file. For several voices add `[voices.<name>]` tables with `ref_audio` and `ref_text`, and mark text with `[main]`, `[town]`, ... tags (see `src/f5_tts/infer/examples/multi/story.toml` and `story.txt`).

## Python API

```python
from f5_tts.api import F5TTS

tts = F5TTS()                                # defaults to model="F5TTS_v1_Base"; device auto: cuda, xpu, mps, then cpu
wav, sr, spec = tts.infer(
    ref_file="ref.wav",
    ref_text="Exact words spoken in the reference clip.",
    gen_text="The sentence you want in that voice.",
    file_wave="out.wav",
    seed=None,                               # None picks a random seed; set an int for repeatability
)
```

`F5TTS(model, ckpt_file, vocab_file, ode_method="euler", use_ema=True, vocoder_local_path=None, device=None, hf_cache_dir=None)`. `infer(...)` options: `target_rms`, `cross_fade_duration`, `sway_sampling_coef`, `cfg_strength`, `nfe_step`, `speed`, `fix_duration`, `remove_silence`, `file_wave`, `file_spec`, `seed`. `tts.transcribe(path, language)` runs the ASR helper. Load the model once per process and reuse it.

## Speech editing

`python src/f5_tts/infer/speech_edit.py` demonstrates speech editing (source checkout only).

## Consent and disclosure

Cloning a real person's voice requires their permission. Do not use it for deception. Keep reference clips and outputs under access control.
