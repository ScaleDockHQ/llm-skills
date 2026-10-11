# GGUF with llama.cpp

> Verified against llama.cpp v0.6.0 and master b11556 for the server default port (convert_hf_to_gguf.py, tools/quantize, tools/imatrix, tools/perplexity, docs/build.md), 2026-10-11

## What it is and when to choose it

GGUF is llama.cpp's model file format: tensors plus tokenizer, chat template and metadata in one file (or a few split shards). Choose it when the target engine is llama.cpp / llama-server, Ollama or LM Studio, when you need CPU or Apple Metal inference, or when you want many bit widths (1.5 to 8 bpw) from one BF16 conversion. Upstream: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp).

Two phases: (1) convert the HF checkpoint to a 16-bit GGUF, (2) quantize that GGUF with `llama-quantize`, optionally guided by an importance matrix from `llama-imatrix`.

## Install

You need the Python conversion script (from the source tree) and the compiled tools. Build from source so both match.

DGX Spark (arm64, CUDA) and generic x86 + NVIDIA:

```bash
git clone https://github.com/ggml-org/llama.cpp ~/src/llama.cpp
cd ~/src/llama.cpp
git checkout <release-tag>            # pin; record it in the model card
cmake -B build -DGGML_CUDA=ON
systemd-run --user --scope -p MemoryMax=48G -p MemorySwapMax=0 -- \
  cmake --build build --config Release -j 8
ls build/bin/llama-quantize build/bin/llama-imatrix build/bin/llama-perplexity build/bin/llama-server
```

- A native build (default) targets the GPU present. For a portable binary use `-DGGML_NATIVE=OFF` or set `-DCMAKE_CUDA_ARCHITECTURES=...`. Non-native builds include a `121a-real` target (GB10) with CUDA >= 12.9 and `120a-real` with CUDA >= 12.8.
- CPU-only or macOS (Metal is on by default on Apple Silicon): `cmake -B build && cmake --build build --config Release -j 8`.

Python side for conversion (use a venv):

```bash
cd ~/src/llama.cpp
python3 -m venv .venv && . .venv/bin/activate
python3 -m pip install -r requirements.txt
# some newer architectures need: pip install -U transformers
```

The convert requirements pin a CPU build of torch; conversion does not need a GPU.

## Minimal working config/command

```bash
# 1. Convert HF -> BF16 GGUF (local dir with config.json, tokenizer, *.safetensors)
python convert_hf_to_gguf.py ~/models/<model> --outtype bf16 --outfile ~/models/gguf/<model>-BF16.gguf

# 2. (recommended for <= 4-bit) importance matrix from calibration text
./build/bin/llama-imatrix -m ~/models/gguf/<model>-BF16.gguf -f calibration.txt \
  -o ~/models/gguf/<model>.imatrix.gguf -ngl 99

# 3. Quantize
./build/bin/llama-quantize --imatrix ~/models/gguf/<model>.imatrix.gguf \
  ~/models/gguf/<model>-BF16.gguf ~/models/gguf/<model>-Q4_K_M.gguf Q4_K_M
```

Wrap steps 1-3 in a memory-capped scope (see `memory-safety.md`).

### convert_hf_to_gguf.py arguments (v0.6.0)

| Arg                                                  | Meaning                                                                                                 |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `model` (positional)                                 | Model directory, or HF repo id with `--remote`                                                          |
| `--outfile PATH`                                     | Output file; `{ftype}` in the name is replaced by the outtype                                           |
| `--outtype`                                          | `f32`, `f16`, `bf16`, `q8_0`, `tq1_0`, `tq2_0`, `auto` (default `auto` = highest-fidelity 16-bit)       |
| `--remote`                                           | Stream safetensors from the Hub instead of downloading (experimental; needs `HF_TOKEN` for gated repos) |
| `--mmproj`                                           | Export the multimodal projector as a separate `mmproj-` GGUF (keep it at `bf16`/`q8_0`)                 |
| `--split-max-size N(M\|G)` / `--split-max-tensors N` | Write split shards                                                                                      |
| `--dry-run`                                          | Print the split plan only                                                                               |
| `--use-temp-file`                                    | Use a temp file while processing (helps when RAM is short; incompatible with splitting)                 |
| `--no-lazy`                                          | Compute everything in RAM before writing (uses more memory; only if lazy mode is broken)                |
| `--metadata FILE`                                    | Authorship metadata override                                                                            |
| `--model-name NAME`                                  | Name stored in metadata                                                                                 |
| `--print-supported-models`                           | List supported architectures                                                                            |
| `--mtp` / `--no-mtp`                                 | Export only the MTP draft head / exclude it                                                             |
| `--fp8-as-q8`                                        | Store tensors dequantized from FP8 as Q8_0 instead of BF16/F16                                          |
| `--mistral-format`                                   | Source is in Mistral's native format                                                                    |

### llama-quantize

Usage: `llama-quantize [options] model-f32.gguf [model-quant.gguf] type [nthreads]`

Types accepted (from `QUANT_OPTIONS` in `tools/quantize/quantize.cpp`):

- K-quants: `Q2_K`, `Q2_K_S`, `Q3_K_S`, `Q3_K_M` (`Q3_K`), `Q3_K_L`, `Q4_K_S`, `Q4_K_M` (`Q4_K`), `Q5_K_S`, `Q5_K_M` (`Q5_K`), `Q6_K`
- I-quants (benefit most from an imatrix): `IQ1_S`, `IQ1_M`, `IQ2_XXS`, `IQ2_XS`, `IQ2_S`, `IQ2_M`, `IQ3_XXS`, `IQ3_XS`, `IQ3_S`, `IQ3_M`, `IQ4_XS`, `IQ4_NL`
- Legacy / other: `Q1_0`, `Q2_0`, `Q4_0`, `Q4_1`, `Q5_0`, `Q5_1`, `Q8_0`, `TQ1_0`, `TQ2_0`, `MXFP4_MOE`
- Float / copy: `F16`, `BF16`, `F32`, `COPY`

Options: `--imatrix FILE`, `--include-weights NAME` / `--exclude-weights NAME` (not together), `--output-tensor-type TYPE`, `--token-embedding-type TYPE`, `--tensor-type NAME=TYPE` (regex allowed, repeatable), `--tensor-type-file FILE`, `--leave-output-tensor`, `--pure`, `--allow-requantize`, `--keep-split`, `--prune-layers L0,L1`, `--override-kv KEY=TYPE:VALUE`, `--dry-run` (show final size only), `--max-buffer-size MiB` (default 8192; lower it on small-RAM machines).

### llama-imatrix

Required: `-m model.gguf -f calibration.txt`. Useful: `-o/--output-file` (default `imatrix.gguf`), `--output-format gguf|dat`, `-ngl` (GPU offload), `--chunks N` (limit), `--chunk N` (skip first N), `-ofreq N` (save every N chunks), `--save-frequency N`, `--in-file A --in-file B` (combine), `--process-output` (also collect for `output.weight`; off by default on purpose), `--no-ppl`, `--parse-special`, `--show-statistics`.

## How it plugs into the stack

- In: HF safetensors directory (BF16/FP16; FP8 sources are dequantized). Out: `.gguf` file(s), plus `mmproj-*.gguf` for vision models.
- Serve with `llama-server -m <file>.gguf --jinja -ngl all --host 127.0.0.1 --port 9931` (9931 is the default since b11521; v0.6.0 and older default to 8080); health at `GET /health`, OpenAI-compatible `GET /v1/models` and `POST /v1/chat/completions`. Ollama and LM Studio import the same file (`local-llms` skill); llama-swap fronts multiple GGUFs (`self-hosted-llms` skill).
- Quality check with `llama-perplexity` KL divergence (`quality-checks.md`).

## Operating

- Keep the BF16 GGUF until all quants are produced and checked; every quant type is made from it, never from another quant.
- Produce several types from one imatrix (for example `Q4_K_M`, `Q5_K_M`, `Q6_K`, `Q8_0`, `IQ4_XS`).
- Use `llama-quantize --dry-run` to see final size before spending time.
- Record the llama.cpp tag or commit (`git -C ~/src/llama.cpp describe --tags`) and the exact commands in the model card.

## Tuning knobs worth knowing

- Calibration text for the imatrix: use text like the intended workload (chat transcripts, code, the model's languages). Generic Wikitext is the upstream convention for _measuring_, not necessarily the best for _calibrating_. Do not calibrate on your evaluation text.
- `--output-tensor-type` / `--token-embedding-type`: raise them (for example `q8_0`) for small models where those tensors dominate quality.
- `--tensor-type attn_v=q6_k` style overrides for mixed recipes; MoE expert tensors can go lower than attention.

## Known pitfalls

- `--allow-requantize` from an already-quantized GGUF severely reduces quality; re-convert from 16-bit instead.
- `convert_hf_to_gguf.py` fails with "Model ... is not supported" for new architectures: update llama.cpp (and `transformers`) or wait for upstream support. Do not hand-edit tensors.
- The converter loads lazily, but the BF16 output is about 2 bytes per parameter on disk; plan disk for source + BF16 + every quant.
- Vision models need the separate `--mmproj` export; without it the GGUF is text-only.
- A wrong or missing chat template in GGUF metadata breaks chat; check with a smoke prompt via `llama-server --jinja`.
- `llama-imatrix` with `-ngl` on a node that is serving can OOM the shared memory on unified-memory machines; stop serving or cap the scope.

## Official links

- Quantize README: https://github.com/ggml-org/llama.cpp/blob/master/tools/quantize/README.md
- imatrix README: https://github.com/ggml-org/llama.cpp/blob/master/tools/imatrix/README.md
- Build docs: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- GGUF on the Hub: https://huggingface.co/docs/hub/gguf
- GGUF-my-repo Space (no-setup quants): https://huggingface.co/spaces/ggml-org/gguf-my-repo
