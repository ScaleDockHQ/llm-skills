# EXL3 quantization: publishing a bitrate ladder

> Verified against exllamav3 v1.6.1, 2026-10-11

Publishing redistributes derivative weights: confirm the source license, and get explicit approval before any upload.

## Convention

EXL3 repos conventionally use one repository per model with **one branch per bitrate** (for example `turboderp/Llama-3.1-8B-Instruct-exl3` has branches `2.0bpw`, `2.25bpw`, `2.5bpw`, `3.0bpw`, `3.5bpw`, `4.0bpw`, `5.0bpw`, `6.0bpw`, `8.0bpw` plus `main`), tagged `exl3` and with `base_model:quantized:<source>` metadata. Users download with `--revision 4.0bpw`.

## Upload one branch per bitrate

```bash
hf auth whoami                                    # token from env or cache; never print it
hf repos branch create <user>/<model>-exl3 4.0bpw     # create the branch (from main)
hf upload <user>/<model>-exl3 ~/models/<model>-exl3-4.0bpw . --revision 4.0bpw
```

(Create the repository first if it does not exist, with `hf repos create`; check `hf repos --help` and `hf upload --help` for your version.) Put the model card on `main`.

## Card checklist

- Source model and revision, license, derivative note.
- ExLlamaV3 version (tag or commit) and the exact `convert.py` command per branch: `-b`, `-hb`, `-hq`, `-eb`, `-vb`, `-mb`, recipe, calibration data.
- Table: bitrate (achieved, from the real file size), size in GB, perplexity or KLD vs the original with the evaluation setup.
- Serving: the `exllamav3` / TabbyAPI minimum version and an example `config.yml` snippet; supported architectures need a minimum ExLlamaV3 version.
- Chat template, tool-calling format, recommended sampling from the source card.

## Files to include

Everything `convert.py` writes: `config.json` (with `tie_word_embeddings` false if the source tied it), tokenizer files, EXL3 `.safetensors` shards, `quantization_config.json` (created by the converter or `util/add_quant_config.py`). Do not upload the work dir.
