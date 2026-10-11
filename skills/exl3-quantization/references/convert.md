# EXL3 quantization: convert.py

> Verified against exllamav3 v1.6.1, 2026-10-11

`convert.py` lives in the repository (it is a thin wrapper over `exllamav3.conversion.convert_model`). The PyPI package and wheels give you the library; clone the repo for the scripts (`convert.py`, `eval/`, `util/`, `sc_*.py`) and check out the tag that matches the installed version. Install steps, wheels and aarch64 builds: `exllamav3` skill.

```bash
git clone https://github.com/turboderp-org/exllamav3 ~/src/exllamav3 && cd ~/src/exllamav3
git checkout v1.6.1            # match: python -c "import exllamav3;print(exllamav3.__version__)"
python convert.py -i ~/models/<model> -o ~/models/<model>-exl3-4.0bpw -w ~/scratch/exl3-work -b 4.0
python convert.py -w ~/scratch/exl3-work -r       # resume
python convert.py -h
```

EXL3 is a streamlined variant of QTIP: Hessians are computed on the fly, so conversion is one step needing only the model and a target bitrate. Upstream gives "a couple of minutes for smaller models, up to a few hours for larger ones (70B+) on a single high-end consumer GPU".

## Input

The source directory must hold `config.json`, `tokenizer.json` and one or more `.safetensors` files, unquantized HF format. The architecture must be supported: the upstream README table (check it for the version you run) lists, for example, Llama, Mistral/Mixtral, Qwen 2/2.5/3/3-Next/3-VL/3.5 (and MoE), Gemma 2/3/4 (note: Gemma 4 E2B/E4B unsupported), GLM 4.x, GPT-OSS, DeepSeek V3/V4, MiniMax-M2, NemotronH, Phi3/4, Step 3.5/3.7 Flash and more. Always read the live table.

## Arguments (doc/convert.md)

### Basic

| Argument                                              | Meaning                                                                                                                                                                                         |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-i / --in_dir DIR`                                   | Unquantized HF model                                                                                                                                                                            |
| `-o / --out_dir DIR`                                  | Output; created, or overwritten if it exists                                                                                                                                                    |
| `-w / --work_dir DIR`                                 | Temp dir for checkpoints and quantized tensors; needs space for a full copy of the output. Only required argument with `-r`                                                                     |
| `-b / --bits FLOAT`                                   | Target average bits per weight                                                                                                                                                                  |
| `-hb / --head_bits INT`                               | `lm_head` bits, integer 1-8, default 6                                                                                                                                                          |
| `-hq / --hq`                                          | Raise the bitrate of select layers (attention, shared experts). The result may be somewhat above `--bits`; for MoE models typically +0.05-0.10 bpw for a disproportionately large fidelity gain |
| `-ss / --shard_size MB`                               | Output shard size, default 8192; 0 disables sharding (very large files need lots of system RAM)                                                                                                 |
| `-eb / --embed_bits INT`                              | Token embedding bits 1-8, or 16 (default) to keep it unquantized. Quantized tables are decoded on the GPU at inference and can sit in system RAM or stream from disk                            |
| `-vb / --vision_bits INT`                             | Vision tower bits 1-8 or 16 (copy unquantized). Default depends on the architecture: towers validated for low bitrates default to 6, others to 16. Quantized without calibration                |
| `-mb / --mtp_bits INT`                                | MTP (multi-token prediction) layer bits 1-8, or 16 to keep unquantized; default 4. Quantized without calibration                                                                                |
| `-ngb / --ngram_bits INT`, `-ngf / --ngram_file FILE` | Hashed n-gram embedding tables of PLE models (for example Qwen3.8-Flash-Next); default is `--bits` rounded; a pre-quantized table from `util/convert_ngram.py` can be copied instead            |
| `-rcp / --recipe FILE`                                | Per-tensor bitrate recipe (YAML) instead of the budgeted allocation: `references/optimized-recipes.md`                                                                                          |
| `-cd / --cal_data FILE`                               | Calibration data (safetensors with packed token rows, from `sc_trace.py`) instead of the bundled corpus mix                                                                                     |

### Performance and checkpoints

| Argument                     | Meaning                                                                                                                                                          |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-d / --devices LIST`        | Comma-separated GPU ids; default only device 0. More devices speed up encoding if PCIe bandwidth allows; memory on the first GPU is unchanged                    |
| `-dr / --device_ratios LIST` | Relative workload ratios for unequal GPUs; omit (autotuned by default)                                                                                           |
| `-pm / --parallel_mode`      | Deprecated no-op; multi-GPU runs one linear layer per GPU when a layer has at least as many tensors as devices                                                   |
| `-cpi INT`                   | Minimum seconds between checkpoints, default 120                                                                                                                 |
| `-r / --resume`              | Resume the job in `-w` from the latest checkpoint; other settings are restored from the old job, some can be overridden. Resuming is explicit (unlike ExLlamaV2) |

### Advanced (upstream: "generally disregard")

`--out_scales auto|always|never|yaqa`, `-hess/--hessians DIR`, `-h1/--hessians_one_sided`, `-hreg/--hessians_reg`, `-cb/--codebook mul1|mcg|3inst` (`mul1` default and required by some optimized inference paths such as int8 GEMV and CPU expert offload). The YAQA path uses precomputed Hessians from `util/yaqa_hessians.py` (see upstream `science/yaqa.md`); treat as experimental.

### Debug (ignore)

`-lcpi`, `-cr/--cal_rows` (default 250), `-cc/--cal_cols` (default 2048), `-v`, `--override_anyway`, `-img`, `--max_module`.

## Examples

```bash
# 3.75 bpw Llama-class model
python convert.py -i ~/models/llama3.1-70b-instruct -o ~/models/llama3.1-70b-exl3-3.75bpw -w ~/scratch/exl3 -b 3.75

# multi-GPU on devices 0,1,2
python convert.py -i ... -o ... -w ~/scratch/exl3 -b 3.75 -d 0,1,2

# MoE, attention kept higher, device 2 primary
python convert.py -i ~/models/qwen3.5-35b-a3b -o ~/models/qwen3.5-35b-a3b-4.00bpw-plus -w ~/scratch/exl3 -b 4.00 -hq -d 2,0,1
```

## Resource notes

- GPU: one GPU is enough for large models; the optimized-recipe doc says a 27B model fits comfortably in 96 GB in BF16 for the measurement stage, which is heavier than conversion. For conversion memory needs on your model, watch `nvidia-smi` on a first run and record it.
- Disk: source + work dir (a full output copy) + output.
- System RAM: shard writing needs RAM; huge `-ss` values or `-ss 0` on big models are the usual cause of host OOM.
- Set a memory-capped scope or lower `-ss` on shared machines.
- Kernels JIT-compile on first import when the extension is not prebuilt (a few minutes once per torch version, per upstream README).

## Pitfalls

- Re-running without `-r` starts over and overwrites `-o`.
- The converter always writes a separate quantized `lm_head` and sets `tie_word_embeddings` to false in the output `config.json` if the source tied them (source: `exllamav3/conversion/quant_config.py`).
- Do not point `-i` at an already quantized (GPTQ, AWQ, FP8) directory ((unverified) upstream support); use the BF16 source.
- Do not run two conversions on the same GPU while serving from it; out-of-memory kills the job (resume with `-r`).
