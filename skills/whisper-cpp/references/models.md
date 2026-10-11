# whisper.cpp: models, quantization and VAD files

> Verified against whisper.cpp v1.9.5 (models/README.md, download-ggml-model.sh, README quantization section) and the ggerganov/whisper.cpp Hugging Face repo, 2026-10-11

whisper.cpp loads **ggml** files (`ggml-<name>.bin`), not the original PyTorch or safetensors weights. Models are multilingual unless the name has `.en`.

## Download

```bash
sh ./models/download-ggml-model.sh large-v3-turbo [models_path]   # fetches from huggingface.co/ggerganov/whisper.cpp
./models/download-vad-model.sh silero-v6.2.0                      # Silero VAD, see cli.md
```

The script validates the name against a built-in list and exits with a usage message when called without one. The list at v1.9.5:

```text
tiny tiny.en tiny-q5_1 tiny.en-q5_1 tiny-q8_0
base base.en base-q5_1 base.en-q5_1 base-q8_0
small small.en small.en-tdrz small-q5_1 small.en-q5_1 small-q8_0
medium medium.en medium-q5_0 medium.en-q5_0 medium-q8_0
large-v1 large-v2 large-v2-q5_0 large-v2-q8_0 large-v3 large-v3-q5_0
large-v3-turbo large-v3-turbo-q5_0 large-v3-turbo-q8_0
```

`small.en-tdrz` comes from `akashmjn/tinydiarize-whisper.cpp` instead (tinydiarize, speaker-turn marks with `-tdrz`).

## Sizes

README disk and memory table (full-precision files):

| Model  | Disk    | Mem     |
| ------ | ------- | ------- |
| tiny   | 75 MiB  | ~273 MB |
| base   | 142 MiB | ~388 MB |
| small  | 466 MiB | ~852 MB |
| medium | 1.5 GiB | ~2.1 GB |
| large  | 2.9 GiB | ~3.9 GB |

File sizes I measured from the Hugging Face repo on 2026-10-11 (`content-length` of `resolve/main/ggml-<name>.bin`):

| File                  | Size                      |
| --------------------- | ------------------------- |
| `large-v3-turbo`      | 1,624,555,275 B (1.5 GiB) |
| `large-v3-turbo-q8_0` | 874,188,075 B (834 MiB)   |
| `large-v3-turbo-q5_0` | 574,041,195 B (547 MiB)   |
| `large-v3-q5_0`       | 1,081,140,203 B (1.0 GiB) |
| `medium-q5_0`         | 539,212,467 B (514 MiB)   |
| `small-q5_1`          | 190,085,487 B (181 MiB)   |

Check free disk before downloading; runtime memory is above the file size (the table is the upstream guide).

## Which one

- **Default for quality per cost: `large-v3-turbo`**, or `large-v3-turbo-q5_0` when memory or disk is tight. Turbo is a pruned `large-v3` for speed. It does not translate to English (the OpenAI model's behaviour, noted for vLLM in `self-hosted-genmedia`); use a non-turbo multilingual model with `-tr`.
- **English only, small hardware:** `base.en` or `small.en`; `.en` models are better than the same-size multilingual model on English.
- **Highest accuracy, multilingual:** `large-v3` or `large-v3-q5_0`.
- **Raspberry-class CPU:** `tiny*` or `base*` quantized.
- Distilled models: upstream says initial support exists but the chunk-based strategy is not implemented, so quality can be sub-optimal (models/README).

## Quantize your own

```bash
./build/bin/whisper-quantize models/ggml-small.bin models/ggml-small-q5_1.bin q5_1
```

Types: `q4_0 q4_1 q5_0 q5_1 q8_0 q2_k q3_k q4_k q5_k q6_k` (`common-ggml.cpp`). The README example calls the binary `quantize`; the CMake target at v1.9.5 is `whisper-quantize`. `q8_0` is nearest to full quality, `q5_x` is the usual compromise (what upstream ships for the large models), and Q4 or lower is for when nothing else fits; **test your own audio**, because I found no upstream accuracy table. Core ML replaces only the encoder, so a quantized `.bin` still holds the decoder (`performance-memory.md`). Quantized-model support per backend was not tested here.

## Other model sources

- Convert OpenAI checkpoints with `models/convert-pt-to-ggml.py`, or Hugging Face fine-tunes with `convert-h5-to-ggml.py` (documented in models/README; they need Python, which this skill does not ship).
- The Hugging Face repo lists more files than the script (`tree/main`), for example other turbo and q8 variants; fetch with `curl -fL -o models/<file> https://huggingface.co/ggerganov/whisper.cpp/resolve/main/<file>` and compare size to the listing.
- Parakeet: the repo also ships `parakeet-cli` for NVIDIA Parakeet models (a separate model family and format); not covered here.

## Hygiene

- Keep models outside the repo checkout (`~/models/whisper/`) so rebuilds and `git clean` do not remove them.
- Re-download when a file is truncated: check size against the Hugging Face listing.
- Licenses: OpenAI Whisper weights are MIT per the upstream repo; check any third-party ggml file's card.
