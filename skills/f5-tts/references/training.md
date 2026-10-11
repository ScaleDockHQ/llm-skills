# F5-TTS: training and fine-tuning pointers

> Verified against F5-TTS 1.1.22 (README and src/f5_tts/train/README.md), 2026-10-11

Training is out of this skill's depth; these are the entry points upstream documents. Use an editable install (`pip install -e .`) and check `ffmpeg -version`.

## Dataset

- Ready-made preparation scripts: `src/f5_tts/train/datasets/prepare_emilia.py`, `prepare_wenetspeech4tts.py`, `prepare_libritts.py`, `prepare_ljspeech.py` (fill in the dataset paths first).
- Custom data: a CSV with header `audio_file|text` and absolute audio paths, then `python src/f5_tts/train/datasets/prepare_csv_wavs.py /path/to/metadata.csv /path/to/output`.

## Training and fine-tuning

```bash
accelerate config                                              # multi-GPU, mixed precision, etc.
accelerate launch src/f5_tts/train/train.py --config-name F5TTS_v1_Base.yaml
accelerate launch --mixed_precision=fp16 src/f5_tts/train/train.py --config-name F5TTS_v1_Base.yaml ++datasets.batch_size_per_gpu=19200
f5-tts_finetune-gradio                                         # Gradio training and fine-tuning UI
```

Config files live in `src/f5_tts/configs`. Fine-tuning practice is discussed in the repo's discussion #57 and the Gradio UI in #143. To fine-tune a variant such as `F5TTS_v1_Base_no_zero_init`, download its checkpoint manually and enter the path in the UI. Early fine-tuned checkpoints may sound better with `use_ema` off.

## Logging

Weights & Biases logging is off unless you `wandb login` or set `WANDB_API_KEY` in the environment (never in a file you commit or echo). `wandb` is a declared dependency. TensorBoard needs `pip install tensorboard`.

## Licence reminder

Treat checkpoints fine-tuned from the released weights as carrying the non-commercial terms unless you have confirmed otherwise (this is not legal advice), and train only on data you are allowed to use.
