# GGUF quantization: convert Hugging Face to GGUF

> Verified against llama.cpp master b11556 (convert_hf_to_gguf.py --help source, tools/quantize/README.md, tools/gguf-split/README.md), 2026-10-11

Phase 1 of two: write a 16-bit (or 32-bit) GGUF that every quant is derived from.

```bash
python convert_hf_to_gguf.py ~/models/<model> --outtype bf16 --outfile ~/models/gguf/<model>-BF16.gguf
```

Upstream notes: for a model distributed in 16-bit, `--outtype auto` (the default; highest-fidelity 16-bit type) also works. A local directory needs `config.json`, tokenizer files and `*.safetensors`.

## Options (from the argparse source)

| Option                                              | Use                                                                                                                                                                |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `model` (positional)                                | Directory, or HF repo id with `--remote`                                                                                                                           |
| `--outfile PATH`                                    | Output; `{ftype}` is replaced by the outtype                                                                                                                       |
| `--outtype`                                         | `f32`, `f16`, `bf16`, `q8_0`, `tq1_0`, `tq2_0`, `auto` (default)                                                                                                   |
| `--remote`                                          | (Experimental) read safetensors remotely without downloading them; config and tokenizer files are still downloaded. Gated repos need `HF_TOKEN` in the environment |
| `--mmproj`                                          | Export the multimodal projector; an `mmproj-` prefix is added to the file name                                                                                     |
| `--mtp`                                             | Export only the multi-token-prediction head as a separate GGUF (`mtp-` prefix), usable as a speculative draft                                                      |
| `--no-mtp` / `--no-nextn`                           | Exclude NextN/MTP tensors from the main file; pair with `--mtp` on a second run                                                                                    |
| `--dspark`                                          | Export only the DeepSeek-V4 DSpark draft tensors                                                                                                                   |
| `--split-max-size N(M\|G)`, `--split-max-tensors N` | Write shards at convert time                                                                                                                                       |
| `--no-tensor-first-split`                           | Do not put tensors in the first shard (metadata only)                                                                                                              |
| `--dry-run`                                         | Print the split plan, write nothing                                                                                                                                |
| `--use-temp-file`                                   | Use a temp file; helps when the process is killed for RAM                                                                                                          |
| `--no-lazy`                                         | Compute everything in RAM before writing; only if lazy mode is broken                                                                                              |
| `--fp8-as-q8`                                       | Store tensors dequantized from FP8 as Q8_0 instead of BF16/F16                                                                                                     |
| `--fuse-gate-up-exps`, `--fuse-qkv`                 | Fuse tensors (MoE gate/up experts; Q/K/V); check your runtime supports the fused layout before publishing                                                          |
| `--mistral-format`                                  | Source is in Mistral's native format                                                                                                                               |
| `--vocab-only`                                      | Extract only the vocabulary                                                                                                                                        |
| `--bigendian`                                       | Target a big-endian machine                                                                                                                                        |
| `--metadata FILE`, `--model-name NAME`              | Authorship metadata and name                                                                                                                                       |
| `--print-supported-models`                          | List supported architectures                                                                                                                                       |

`python convert_hf_to_gguf.py --help` for your pinned version is authoritative; flags are added often.

## Multimodal

The LLM and the multimodal encoder/projector are separate files. Upstream keeps the projector in a high-quality type because its quality directly affects generations and the size saving is negligible:

```bash
python convert_hf_to_gguf.py ~/models/<model> --mmproj --outtype q8_0 --outfile ~/models/gguf/mmproj-<model>-Q8_0.gguf   # or --outtype bf16
llama-server -m <model>-Q4_K_M.gguf --mmproj mmproj-<model>-Q8_0.gguf
```

Publish the `mmproj-*.gguf` next to the quants. Do not run `llama-quantize` on it. `--mmproj` works only on some vision models.

## Planning disk and memory

- A 16-bit GGUF is about 2 bytes per parameter; upstream notes memory and disk needs are currently about the same because models are fully loaded for quantization. Upstream example for Llama 3.1: 8B is 32.1 GB original / 4.9 GB Q4_K_M; 70B is 280.9 GB / 43.1 GB.
- Budget disk for: source + 16-bit GGUF + every quant + imatrix (+ a KLD logits file, which is very large, see `quality-checks.md`).

## Pitfalls

- "Model ... is not supported": update llama.cpp and `transformers`, or wait for upstream. Check with `--print-supported-models`.
- Wrong or missing chat template in the output breaks chat; smoke-test with `llama-server --jinja`.
- A model with a custom tokenizer or `trust_remote_code` code may need extra files; the converter reads the model directory, so download every file.
- Convert once with the final flags; changing `--fuse-*` or MTP options later requires re-converting and re-quantizing.
