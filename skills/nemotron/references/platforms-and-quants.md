# Nemotron platforms and quants

> Verified against the NVIDIA model cards (hardware matrix, deployment tables), Hugging Face repo file listings, the NVIDIA DGX Spark Nemotron playbook, Ollama library pages and TensorFold v1.0.7 README, 2026-10-11

## Pick by platform

| Platform                                | Recommended model and format                                                                    | Engine                                                                                       | Why                                                                                                                                                                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DGX Spark (GB10, 128 GB unified)**    | Lightning NVFP4 (21.5 GB) with DSpark drafter; Super NVFP4 (80 GB) if you want the bigger model | vLLM (card recipe); TensorRT-LLM or SGLang also have Spark recipes; TensorFold for Lightning | Cards list Spark as single-device deployment for both. Spark has no native FP4 tensor-core path in the Lightning matrix: it runs W4A16 through Marlin (`--moe-backend marlin`)                                |
| **RTX 5090 / RTX PRO 6000 (Blackwell)** | Lightning NVFP4, or GGUF                                                                        | llama.cpp, Ollama; vLLM possible                                                             | Lightning card lists RTX 5090 as supported hardware but "no recipe published" for vLLM, validated context "confirm". The Local AI section lists RTX 5090, DGX Spark and RTX 6000 Pro for Ollama and llama.cpp |
| **Apple Silicon**                       | Lightning MLX 4-bit; Nano 4B GGUF for small Macs                                                | TensorFold (Metal, M1 to M5), MLX, llama.cpp, Ollama, LM Studio                              | See Apple section                                                                                                                                                                                             |
| **1x H100 80 GB**                       | Lightning NVFP4 (W4A16 on Hopper, `humming` backend)                                            | vLLM, TensorRT-LLM, SGLang                                                                   | Card: one H100 deploys it with up to 1M context                                                                                                                                                               |
| **A100 80 GB (Ampere)**                 | Lightning NVFP4 via W4A16, or BF16                                                              | vLLM (`--quantization modelopt_fp4`)                                                         | Card lists Ampere W4A16                                                                                                                                                                                       |
| **2x H100**                             | Super FP8                                                                                       | vLLM                                                                                         | Super FP8 card: minimum 2x H100-80GB. Recipes there use TP4 + expert parallel                                                                                                                                 |
| **1x B200**                             | Super NVFP4                                                                                     | vLLM                                                                                         | Super NVFP4 card: 1x B200 or 1x DGX Spark                                                                                                                                                                     |
| **4x B200 or 4x GB300 / 8x H100**       | Ultra NVFP4 (352 GB)                                                                            | vLLM (v0.22.0 container in the card), SGLang, TensorRT-LLM                                   | Ultra NVFP4 card minimums: 4x GB200 / B200 / GB300 / B300 or 8x H100. BF16 needs 8x B200-class or 16x H100 or 8x H200                                                                                         |
| **Jetson Thor / edge**                  | Nano 4B (BF16, FP8, GGUF)                                                                       | vLLM, llama.cpp, TensorRT-LLM                                                                | Nano 4B card targets Jetson Thor, RTX and DGX Spark                                                                                                                                                           |

Context: size memory for the context you will actually use, not 1M. Hybrid models need little KV cache, but the card
recipes still fix `--gpu-memory-utilization` and Mamba cache dtypes; copy them first, tune later.

## NVFP4 in practice

NVFP4 stores 4-bit weights with block scales. The Lightning card's hardware table says only Blackwell data-center parts
(GB200) take the native FP4 compute path. DGX Spark runs W4A16 via Marlin, Hopper and Ampere run W4A16 via the `humming`
backend. So NVFP4 is a memory saver on Spark and Hopper, not a speed-up by itself. Lightning's NVFP4 checkpoint quantizes
routed and shared experts to NVFP4 (W4A16 recipe), keeps FP8 per-tensor scales on Mamba projections and the KV cache, and
NVIDIA's own table shows near-parity with BF16 (for example MMLU-Pro 81.62 vs 81.94, SWE-bench Verified 52.80 vs 51.56).
Other NVFP4 or FP8 recipes and quantization tooling live in the `nvidia-modelopt` and `model-quantization` skills.

Per-model official quants (Hub listing on 2026-10-11):

| Model     | BF16 | FP8                                | NVFP4 | GGUF (NVIDIA)                                               | Drafters                                                   |
| --------- | ---- | ---------------------------------- | ----- | ----------------------------------------------------------- | ---------------------------------------------------------- |
| Lightning | yes  | no (RedHatAI community FP8 exists) | yes   | `ggml-org` repo: BF16, Q4_0, Q8_0 and `mtp-*` heads         | DSpark, DFlash (NVFP4), MTP built in                       |
| Super     | yes  | yes                                | yes   | none from NVIDIA (community: unsloth)                       | MTP built in; `Nemotron-3-Super-120B-A12B-BF16-MTPv2` head |
| Ultra     | yes  | no                                 | yes   | none from NVIDIA (community: unsloth, `mlx-community` 4bit) | MTP built in                                               |
| Nano 30B  | yes  | yes                                | yes   | `ggml-org` repo: BF16, Q4_K_M (22 GB), Q8_0                 | none                                                       |
| Nano 4B   | yes  | yes                                | no    | `nvidia/...-GGUF` Q4_K_M (2.8 GB)                           | none                                                       |
| Nano Omni | yes  | yes                                | yes   | community (lmstudio-community, unsloth)                     | none                                                       |

## GGUF sizes (community, for planning)

| Model                            | Files seen on the Hub (size)                                                            |
| -------------------------------- | --------------------------------------------------------------------------------------- |
| Lightning, `ggml-org`            | BF16 63 GB, Q8_0 33 GB, Q4_0 18 GB                                                      |
| Lightning, `unsloth`             | MXFP4_MOE 23 GB, UD-Q4_K_XL 25 GB, UD-Q5_K_XL 30 GB, Q8_0 35 GB, down to UD-IQ1_M 19 GB |
| Nano 30B, `unsloth` / `ggml-org` | Q4_K_M 24 / 22 GB, Q8_0 33 GB, BF16 about 62 GB                                         |
| Super, `unsloth`                 | split files, for example BF16 about 238 GB total; MXFP4_MOE about 81 GB                 |
| Ultra, `unsloth`                 | split files, BF16 24 parts of about 45 GB                                               |

Unsloth and other community quants are not NVIDIA-tested. For Lightning the `mtp-*.gguf` files are separate
draft heads; whether your llama.cpp build uses them depends on its MTP support (see `known-issues.md`).

## Apple Silicon

- **TensorFold** `TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit` (18.5 GB, includes an MTP head): qualified on
  Metal M1 through M5 per the TensorFold README. `tensorfold serve` downloads the model and head on first run.
- **MLX**: `mlx-community/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-4bit` and `-OptiQ-4bit`, and
  `TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-oQ6` (26 GB, oMLX recipe) exist. `mlx-community/Nemotron-3-Ultra-550B-A55B-4bit` exists. These are community conversions.
- **GGUF** via llama.cpp, Ollama or LM Studio. Sizes: Nano 4B Q4_K_M is 2.8 GB; Lightning Q4 files are 18 to 25 GB before context, so plan a Mac with
  clearly more unified memory than that (not tested here).

## TensorFold qualified list (v1.0.7, 2026-10-11)

From the README "Qualified models":

| Model                          | Checkpoint                                                            | Qualified platform                                                |
| ------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Nemotron 3.5 Lightning 30B-A3B | MLX affine 4-bit, group 64, included MTP head                         | Metal M1 to M5; CUDA on GB10, RTX 3090 and RTX PRO 6000 Blackwell |
| Nemotron 3.5 Lightning 30B-A3B | NVIDIA's NVFP4 (`nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4`) | CUDA on GB10 (sm_90 or newer)                                     |

So the existing note in the `self-hosted-llms` TensorFold reference is confirmed. Nano, Super, Ultra, Nano 4B and
Llama-Nemotron: not qualified, no upstream support found in the README. The README says the Linux x86_64 archive adds
Ampere cards of compute capability 8.6 (tested on an RTX 3090) and Blackwell 12.0 (tested on an RTX PRO 6000); A100 (8.0)
is not supported yet.

## DGX Spark notes

- NVIDIA's playbook `https://build.nvidia.com/spark/nemotron` covers Nano (Omni weights, `vllm/vllm-openai:v0.20.0`) and
  Super NVFP4 (vLLM `cu130-nightly` or TensorRT-LLM `release:1.3.0rc9`), last updated 2026-07-01. Memory is shared with
  the OS: do not give vLLM more than the card's 0.85 to 0.90 utilization, and stop other engines first
  (`nvidia-dgx-spark` and `self-hosted-llms` skills).
- Super NVFP4 at 80 GB leaves under 50 GB for KV cache, Mamba state, the OS and everything else on a 128 GB Spark. Keep
  `--max-num-seqs` small (the playbook uses 4).
- vLLM on Spark has open regressions for these models: see `known-issues.md`.

## Cloud

Nemotron is also hosted (NVIDIA NIM at `build.nvidia.com`; Ollama `nemotron-3-ultra:cloud`). For hosted use see the
`cloud-llms` skill.

## Sources

- https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF
- https://huggingface.co/ggml-org/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF
- https://huggingface.co/unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF
- https://huggingface.co/TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit
- https://build.nvidia.com/spark/nemotron
- https://github.com/ashhart/TensorFold
- https://ollama.com/library/nemotron-3.5-lightning
