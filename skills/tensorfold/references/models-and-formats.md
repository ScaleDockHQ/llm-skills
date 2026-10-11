# TensorFold: models, checkpoints and formats

> Verified against TensorFold v1.0.7, 2026-10-11

README "Qualified models", docs/recipes/cuda.md

TensorFold admits only **qualified** model, checkpoint and platform combinations. A flag or checkpoint the native engine does not serve is refused with the Python 0.6.6 install line. Model weights have separate downloads and licenses.

## Qualified in 1.0.7

| Model                                         | Checkpoint format                                                      | Qualified platform                                             |
| --------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------- |
| Nemotron 3.5 Lightning 30B-A3B                | MLX affine 4-bit, group 64, included MTP head                          | Metal M1 to M5; CUDA on GB10, RTX 3090, RTX PRO 6000 Blackwell |
| Nemotron 3.5 Lightning 30B-A3B (NVIDIA NVFP4) | ModelOpt NVFP4 experts and head, FP8 Mamba projections, bf16 attention | CUDA on GB10 (sm_90 or newer)                                  |
| Qwen3.8 Flash Next                            | MLX affine 6-bit, group 32                                             | Metal on M5 Ultra                                              |
| GLM-5.3-Flash                                 | MLX affine 4-bit, group 64                                             | Metal, two M5 Ultras                                           |
| Qwen3.5-2B                                    | pinned MLX affine 4-bit, group 64, tied embeddings                     | Metal on M5 Max                                                |
| Qwen3.8-27B                                   | MLX affine 4-bit, group 64, own head; DFlash2 drafter                  | Metal on M5 Max and M3 Ultra                                   |

Checkpoint IDs: `TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit`; `nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4` (served as stored on CUDA; its bf16 MTP head is quantized to 4-bit at load for drafts); `mlx-community/Qwen3.5-2B-MLX-4bit` at revision `93760be4f1f69842a46bc13dbdc0f19e291392a3`; `TensorFold/Qwen3.8-27B-MLX-4bit` with drafter `z-lab/Qwen3.8-27B-DFlash2` (`--drafter`; without it the 27B is slower than mlx_lm).

Native CUDA registers **only Nemotron** in 1.0.7. Qualified GPUs: GB10 (`linux-aarch64`, greedy and sampled), Ampere cc 8.6 (`linux-x86_64`, greedy), Blackwell cc 12.0 (tested on RTX PRO 6000). A100 (cc 8.0) is not supported yet.

Under qualification for 1.0.x (not served natively): Bonsai, Gemma 4, Qwen3.6, DeepSeek-V4. Tracker issues for CUDA ports exist (GLM #593, Flash Next #472, DeepSeek-V4.1 #559, Qwen3.8-27B on sm_86 #603); they are proposals, not features.

Known model-specific limits (v1.0.7 release notes): Qwen3.8-27B on M1 to M4 trails 1.0.5 by about 3% after drafted sampled requests; Qwen3.5-2B with a JSON schema on an integer field can keep adding digits until `max_tokens`.

## Python 0.6.6 line (not the native support matrix)

Per `docs/recipes/cuda.md`, the Python engine serves on CUDA: Qwen3.8-27B (one or two ranks, DFlash2), Flash Next (one or two ranks, MTP chains), Nemotron (one or two ranks), GLM-5.3-Flash (two ranks), Qwen3.6-35B-A3B (one rank). Formats there: NVFP4, EXL3 (any codebook, width 1 to 8) and MLX 4-bit. TensorFold reads **no GGUF**. These are Python-engine features and not native upgrade paths. Mia-AiLab EXL3/NVFP4 repos named in that doc include `Mia-AiLab/Qwen3.8-Flash-Next-NVFP4` and `Mia-AiLab/GLM-5.3-Flash-EXL3-TR3-4bpw` (check licenses before use).

## Managing checkpoints

```bash
tensorfold pull TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit
tensorfold models      # cached checkpoints 1.0.7 can serve
tensorfold info TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit   # family, format, context, memory floor
tensorfold serve TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit   # by cached repo name
```

`pull` downloads into the Hugging Face cache, verifies large files by sha256 and small files by git blob sha1, fetches in pieces over up to 16 connections and resumes interrupted pulls. It refuses a model no 1.0.7 family serves, and fetches the 27B's drafter for `--drafter`. Plan disk first and ask before pulling. On Linux, copy a snapshot to a plain folder with `cp -RL` (cache entries are symlinks); on macOS Living Weights docs use `cp -cRL`.

Flash Next builds weight packs locally under `$HOME/.cache/tensorfold/packs/<identity>/` (the model dir may be read-only; the cache dir must be writable). Its runtime kernels require 6-bit affine, group size 32; other widths are refused before device preparation.

## Choosing

- Mac, Nemotron 3.5 Lightning or listed Qwen/GLM: native 1.0.x.
- GB10 or RTX 3090 / PRO 6000, Nemotron: native archive.
- Spark, Qwen3.8 family: MiaAI-Lab recipes (`combos/miaai-lab-recipes.md`).
- Anything else: another engine (`vllm`, `sglang`, `llama-cpp`).
