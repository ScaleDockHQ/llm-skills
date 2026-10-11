# EXL3 quantization: post-processing utilities

> Verified against exllamav3 v1.6.1 (util/*.py argparse and docstrings), 2026-10-11

Scripts in `util/` of the repository (run from the repo root with the converter venv). Read `-h` before use; some are specialized and lightly documented.

| Script                                                                     | Arguments (from source)                                                                                                    | Use                                                                                                                         |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `util/recompile.py`                                                        | `-i/--in_dir`, `-o/--out_dir`, `-ss/--shard_size` (8192), `-or/--override` (YAML), `-eb/--embed_bits` (1-8), `-d/--device` | Recompile an EXL3 model: quantize its token embedding table, or swap in tensors from other EXL3 models via an override spec |
| `util/size_estimation.py`                                                  | `-i/--in_dir`, `-or/--override`                                                                                            | Estimate output size of a (possibly overridden) model                                                                       |
| `util/add_quant_config.py`                                                 | `-m/--model_dir`                                                                                                           | Create or update `quantization_config.json` in a model directory (a tensor map of stored tensors and their formats)         |
| `util/convert_vision.py`                                                   | `-m`, `-vb/--vision_bits` (default 6; 16 unquantized), `-o`, `-d`                                                          | Quantize only the vision tower into a donor directory                                                                       |
| `util/transplant_vision.py`                                                | `-m` target, `-d/--donor_dir`, `-o`, `-ss`                                                                                 | Take the vision weights from a donor, keep the target's text weights                                                        |
| `util/add_safetensors_index.py`, `util/format_chat_template.py`            | see `-h`                                                                                                                   | Index and template housekeeping                                                                                             |
| `util/convert_mtp.py`, `util/convert_ngram.py`, `util/convert_tiktoken.py` | see `-h`                                                                                                                   | MTP layers, n-gram tables, tokenizer conversion                                                                             |
| `util/measure.py`, `util/optimize.py`                                      | see `-h`                                                                                                                   | Older measurement/optimization utilities; prefer the `sc_*` pipeline (`optimized-recipes.md`)                               |
| `util/yaqa_hessians.py`                                                    | see `-h`                                                                                                                   | Precomputed Hessians for `convert.py --hessians` (experimental)                                                             |

## Override spec (recompile, size_estimation, model_diff -or)

A YAML mapping with `sources` (each `id` and `model_dir`) and `overrides` (each `key` and `source`), per the loading code: tensors under `key` are taken from the model in `source`. Use it to build a mixed model from several bitrates, then compare by KLD. The format is read from the source of `util/recompile.py` at the version above; check it before relying on it.

## Typical flow: add a quantized embedding table

```bash
python util/recompile.py -i ~/models/<model>-exl3-4.0bpw -o ~/models/<model>-exl3-4.0bpw-eb8 -eb 8 -d 0
```

Verify with `eval/ppl.py` and a smoke test; the embedding table is quantized without calibration.
