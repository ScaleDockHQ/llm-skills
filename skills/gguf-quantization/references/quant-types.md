# GGUF quantization: types, options and recipes

> Verified against llama.cpp master b11556 (tools/quantize/quantize.cpp, tools/quantize/README.md, tools/perplexity/README.md), 2026-10-11

`llama-quantize [options] model-f32.gguf [model-quant.gguf] type [nthreads]`. The output name is optional (default `ggml-model-<type>.gguf` in the input's directory per the README example). Always input a 16-bit or 32-bit GGUF.

## Types (from `QUANT_OPTIONS`)

| Family          | Types                                                                                                                                       | Notes                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| K-quants        | `Q2_K`, `Q2_K_S`, `Q3_K_S`, `Q3_K_M` (alias `Q3_K`), `Q3_K_L`, `Q4_K_S`, `Q4_K_M` (alias `Q4_K`), `Q5_K_S`, `Q5_K_M` (alias `Q5_K`), `Q6_K` | Mixed per-tensor types; `_M` keeps more tensors at higher precision than `_S` |
| I-quants        | `IQ1_S`, `IQ1_M`, `IQ2_XXS`, `IQ2_XS`, `IQ2_S`, `IQ2_M`, `IQ3_XXS`, `IQ3_XS`, `IQ3_S`, `IQ3_M`, `IQ4_XS`, `IQ4_NL`                          | Best size per quality at low bits; benefit most from an imatrix               |
| Legacy          | `Q4_0`, `Q4_1`, `Q5_0`, `Q5_1`, `Q8_0`                                                                                                      | Simple blocks; `Q8_0` is the near-lossless choice                             |
| Newer / special | `Q1_0`, `Q2_0`, `MXFP4_MOE`, `TQ1_0`, `TQ2_0`                                                                                               | `MXFP4_MOE` for MoE; `TQ*` are ternarization for ternary models               |
| Passthrough     | `F16`, `BF16`, `F32`, `COPY`                                                                                                                | `COPY` only copies tensors (used with pruning/metadata edits)                 |

Run `llama-quantize --help` on your build for the exact list and bpw text; it changes between releases.

## Reference numbers (upstream, Llama-3.1-8B, from the quantize README)

| Type    | bits/weight | size GiB |     | Type   | bits/weight | size GiB |
| ------- | ----------- | -------- | --- | ------ | ----------- | -------- |
| IQ1_S   | 2.0042      | 1.87     |     | Q3_K_M | 3.9960      | 3.74     |
| IQ2_XXS | 2.3824      | 2.23     |     | IQ4_XS | 4.4597      | 4.17     |
| IQ2_M   | 2.9294      | 2.74     |     | Q4_K_M | 4.8944      | 4.58     |
| IQ3_XXS | 3.2548      | 3.04     |     | Q5_K_M | 5.7036      | 5.33     |
| Q2_K    | 3.1593      | 2.95     |     | Q6_K   | 6.5633      | 6.14     |
| IQ3_M   | 3.7628      | 3.52     |     | Q8_0   | 8.5008      | 7.95     |

These are for an 8B dense model including the unquantized/embedding overhead; other models differ (bpw is measured, not the nominal bit width). Use `--dry-run` for your model.

KLD scoreboard (Llama-3-8B, from the perplexity README): `q8_0` 0.0014, `q6_K` 0.0055, `q5_K_M` 0.0108, `q4_K_M` 0.031 (0.028 with a 10M-token Wikitext imatrix), `iq4_XS` 0.036 (imatrix), `q3_K_M` 0.10 (0.084 with imatrix), `q2_K` 0.445. Lower is better. Other models differ; measure yours.

## Options

| Option                                              | Effect                                                                    |
| --------------------------------------------------- | ------------------------------------------------------------------------- |
| `--imatrix FILE`                                    | Use an importance matrix (`references/imatrix.md`)                        |
| `--include-weights NAME` / `--exclude-weights NAME` | Apply the imatrix to only / all-but these tensors (cannot be mixed)       |
| `--output-tensor-type TYPE`                         | Type for `output.weight`                                                  |
| `--token-embedding-type TYPE`                       | Type for token embeddings                                                 |
| `--tensor-type NAME=TYPE`                           | Per-tensor override; regex allowed; repeatable                            |
| `--tensor-type-file FILE`                           | Same, from a file (space or newline separated)                            |
| `--leave-output-tensor`                             | Leave `output.weight` unquantized (bigger, maybe better)                  |
| `--pure`                                            | No k-quant mixtures: all tensors the same type                            |
| `--allow-requantize`                                | Allow quantizing already-quantized tensors; severely reduces quality      |
| `--keep-split`                                      | Output the same shards as the (split) input                               |
| `--prune-layers L0,L1,...`                          | Remove layers (advanced; validate quality)                                |
| `--override-kv KEY=TYPE:VALUE`                      | Override metadata, e.g. `qwen3moe.expert_used_count=int:16`               |
| `--dry-run`                                         | Compute and print final size without quantizing                           |
| `--max-buffer-size MiB`                             | Rows kept in memory per tensor, default 8192; lower it on small-RAM hosts |

## Recipes

```bash
# default: imatrix + K-quant
llama-quantize --imatrix m.imatrix.gguf m-BF16.gguf m-Q4_K_M.gguf Q4_K_M

# keep embeddings and head better on a small model
llama-quantize --imatrix m.imatrix.gguf --token-embedding-type q8_0 --output-tensor-type q8_0 m-BF16.gguf m-Q4_K_M.gguf Q4_K_M

# regex mix: attn_v and ffn_down at q5_k
llama-quantize --imatrix m.imatrix.gguf --tensor-type attn_v=q5_k --tensor-type ffn_down=q5_k m-BF16.gguf m-mix.gguf Q4_K_M

# MoE: experts lower than the rest (tensor names differ per arch; list them first, see below)
llama-quantize --imatrix m.imatrix.gguf --tensor-type 'ffn_.*_exps=q3_k' m-BF16.gguf m-moe.gguf Q4_K_M
```

Tensor names are architecture specific. List them from the 16-bit file before writing a pattern:

```bash
python ~/src/llama.cpp/gguf-py/gguf/scripts/gguf_dump.py --no-tensors m-BF16.gguf | head -60   # metadata
python ~/src/llama.cpp/gguf-py/gguf/scripts/gguf_dump.py m-BF16.gguf | grep -E 'blk\.0\.' | head -40
```

(`gguf_dump.py` is also installed as `gguf-dump` when the `gguf` PyPI package is installed; (unverified) which options your pinned copy takes: run `--help`.)

## Choosing

- **Fit first:** pick the largest type whose file plus KV cache fits the memory budget (`choosing-hardware`), then check quality.
- **Default:** `Q4_K_M` with an imatrix. Go `Q5_K_M`/`Q6_K` when quality matters and memory allows; `Q8_0` is the reference-grade choice.
- **Below 4 bpw:** I-quants with an imatrix, and measure KLD; `IQ1_*` and `IQ2_XXS` degrade strongly on small models.
- **Speed:** upstream's Llama-3.1-8B table shows text-generation throughput is not monotonic in bpw (it depends on the kernel and hardware); benchmark on your device with `llama-bench` rather than assuming smaller is faster.
- **Custom mixes** must be justified by KLD against the stock type of similar size, not by intuition.
