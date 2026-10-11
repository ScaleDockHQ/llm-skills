# Chatterbox: models

> Verified against resemble-ai/chatterbox master (README, src/chatterbox/*.py) and Hugging Face model repos, 2026-10-11

| Model                      | Size      | Languages | Class and call                                                           | Hub repo                                  |
| -------------------------- | --------- | --------- | ------------------------------------------------------------------------ | ----------------------------------------- |
| Chatterbox-Turbo           | 350M      | English   | `ChatterboxTurboTTS.from_pretrained(device)`                             | `ResembleAI/chatterbox-turbo` (mit)       |
| Chatterbox-Nano            | 110M      | English   | `ChatterboxTurboTTS.from_pretrained(device, nano=True)`                  | `ResembleAI/chatterbox-nano` (mit)        |
| Chatterbox-Multilingual V3 | 500M      | 23+       | `ChatterboxMultilingualTTS.from_pretrained(device, t3_model="v3")`       | `ResembleAI/chatterbox` (mit)             |
| Multilingual V2 (legacy)   | 500M      | 23        | same class, omit `t3_model` or pass `"v2"`                               | `ResembleAI/chatterbox`                   |
| Single Language Pack       | 500M each | 6         | dedicated finetunes; see the README table for per-model code             | `ResembleAI/Chatterbox-Multilingual-<id>` |
| Chatterbox (original)      | 500M      | English   | `ChatterboxTTS.from_pretrained(device)`; `exaggeration` and `cfg_weight` | `ResembleAI/chatterbox`                   |
| Voice conversion           | n/a       | n/a       | `ChatterboxVC.from_pretrained(device)`                                   | `ResembleAI/chatterbox`                   |

## Choosing

- **Voice agents, English, low latency and low VRAM:** Turbo (README: distilled for efficiency; native paralinguistic tags).
- **On-device or CPU English:** Nano (README: 3x faster than realtime on 8 CPU cores, same architecture as Turbo).
- **Many languages, one cloning model:** Multilingual V3 (README: improved speaker similarity, fewer hallucinations than V2).
- **Language-specific quality:** a Single Language Pack model: Chinese (`zh-cmn`), Latam Spanish (`es-mx-latam`), Brazilian Portuguese (`pt-br`), Spain Spanish (`es-es`), Portugal Portuguese (`pt-pt`), Hindi (`hi`).
- **Emotion dials in English:** the original model with `exaggeration` and `cfg_weight`.

## Languages (multilingual `SUPPORTED_LANGUAGES` in source)

`ar, da, de, el, en, es, fi, fr, he, hi, it, ja, ko, ms, nl, no, pl, pt, ru, sv, sw, tr, zh`. Pass one as `language_id`; an unsupported code raises a `ValueError` listing the supported ones.

## Hub files

The `ResembleAI/chatterbox` repo on 2026-10-11 lists `t3_cfg.safetensors`, `t3_23lang.safetensors`, `t3_mtl23ls_v2.safetensors`, `t3_mtl23ls_v3.safetensors`, `s3gen.safetensors`, `s3gen_v3.safetensors`, `ve.safetensors`, `conds.pt`, tokenizer files and legacy `.pt` copies. Turbo has `t3_turbo_v1.safetensors` and Nano `t3_nano_v1.safetensors`, each with `s3gen.safetensors`, `s3gen_meanflow.safetensors`, `ve.safetensors`, `conds.pt` and tokenizer files. Check sizes with `curl -s "https://huggingface.co/api/models/<repo>?blobs=true" | jq "[.siblings[]|{rfilename,size}]"` before downloading; the README publishes no VRAM figures.

## Sample rate

Read it from the object: `model.sr` (Turbo, Nano and the others set it from the S3Gen decoder rate). Do not hardcode.
