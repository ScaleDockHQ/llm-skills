# F5-TTS: models and licences

> Verified against F5-TTS 1.1.22 (README, configs/, infer/SHARED.md, api.py) and the SWivid/F5-TTS Hugging Face repo, 2026-10-11

## Licences (read before recommending)

- **Code:** MIT (`pyproject.toml` and the README).
- **Pretrained models:** CC-BY-NC, because the Emilia training data is an in-the-wild dataset. The Hugging Face card for `SWivid/F5-TTS` lists `cc-by-nc-4.0`. Non-commercial use only unless you train or obtain other weights. Community checkpoints in `SHARED.md` have their own licences; read each card.
- Voice cloning needs the speaker's consent (`inference.md`).

## Official model names and checkpoints

Configs in `src/f5_tts/configs`: `F5TTS_v1_Base`, `F5TTS_v1_Small`, `F5TTS_Base`, `F5TTS_Small`, `E2TTS_Base`, `E2TTS_Small`.

Files in the `SWivid/F5-TTS` Hub repo on 2026-10-11:

| Folder                       | Files                                                        |
| ---------------------------- | ------------------------------------------------------------ |
| `F5TTS_v1_Base`              | `model_1250000.safetensors`, `vocab.txt`                     |
| `F5TTS_v1_Base_no_zero_init` | `model_1250000.safetensors`                                  |
| `F5TTS_Base`                 | `model_1200000.pt`, `model_1200000.safetensors`, `vocab.txt` |
| `F5TTS_Base_bigvgan`         | `model_1250000.pt`                                           |

`F5TTS_v1_Base` is the current default (v1 release 2025-03-12 with better training and inference). E2 TTS weights come from the separate `SWivid/E2-TTS` repo (`E2TTS_Base`, step 1200000), per `api.py`. The default vocoder is Vocos (`charactr/vocos-mel-24khz`); BigVGAN is supported only for `F5TTS_Base`.

Use your own checkpoint: `--ckpt_file path/to/model.safetensors --vocab_file path/to/vocab.txt` (CLI) or `F5TTS(ckpt_file=..., vocab_file=...)`.

## Languages

The base models cover Chinese and English (Emilia ZH and EN). For other languages upstream points to `src/f5_tts/infer/SHARED.md`, a community table of fine-tunes. Languages listed in the table of contents on 2026-10-11: Arabic, English, Finnish, French, German, Hindi, Italian, Japanese, Latvian, Mandarin, Russian, Spanish and more. Each entry names a Hugging Face repo, vocab and licence. Quality varies; test with your own text, and respect the creator's terms ("use of models must be conditioned on respect for the respective creators").

Using a community model:

```bash
f5-tts_infer-cli --model F5TTS_Base --ckpt_file <downloaded>/model.safetensors --vocab_file <downloaded>/vocab.txt \
  --ref_audio ref.wav --ref_text "..." --gen_text "..."
```

Match `--model` to the architecture the checkpoint was trained with (the card says which config).

## Other implementations (named in the README)

`f5-tts-mlx` (Apple MLX), `F5-TTS-ONNX` (ONNX Runtime) and the Triton/TensorRT-LLM runtime in the repo. They are separate projects with their own licences and maintenance; this skill did not verify them.

## Cache

Weights land in the Hugging Face hub cache (`HF_HOME`). The Docker examples mount a volume at `/root/.cache/huggingface/hub/` so downloads persist.
