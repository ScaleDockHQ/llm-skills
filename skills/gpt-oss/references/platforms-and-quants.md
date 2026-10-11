# gpt-oss platforms and quants

> Verified against vLLM recipes (GPT-OSS), llama.cpp guide #15396 and DGX Spark discussion #16578, TensorRT-LLM gpt-oss deployment guide, NVIDIA DGX Spark playbooks (vLLM), Ollama gpt-oss page, SGLang gpt-oss docs, Hugging Face repos, 2026-10-11

## Pick the format first

The official weights are already 4-bit on the MoE part, so extra quantization buys little and has no official quality data.
llama.cpp's guide says always use the original MXFP4 files; Unsloth notes that any quant smaller than F16 only touches a
few tensors, so sizes stay close to F16. No NVFP4 or FP8 checkpoint of gpt-oss from OpenAI or NVIDIA was found
(NVIDIA's `gpt-oss-puzzle-88B` is the only NVIDIA derivative with weights; it keeps MXFP4 and adds FP8 KV scales). For a
conversion tool see the `model-quantization` skill; ModelOpt has a bit-exact MXFP4 to NVFP4 cast flag, but no gpt-oss NVFP4
quality or speed claim was verified (unverified).

| Format                        | Where                                    | Source                                                                                |
| ----------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------- |
| MXFP4 safetensors (official)  | vLLM, SGLang, TensorRT-LLM, Transformers | `openai/gpt-oss-120b`, `openai/gpt-oss-20b`                                           |
| MXFP4 GGUF                    | llama.cpp, LM Studio, Ollama             | `ggml-org/gpt-oss-120b-GGUF` (59.02 GiB), `ggml-org/gpt-oss-20b-GGUF` (11.27 GiB)     |
| MLX MXFP4-Q8 / Q4             | mlx-lm on Apple Silicon                  | `mlx-community/gpt-oss-20b-MXFP4-Q8`, `...-Q4`, `mlx-community/gpt-oss-120b-MXFP4-Q8` |
| Quark MXFP4 weights, FP8 acts | vLLM on AMD MI355x                       | `amd/gpt-oss-120b-w-mxfp4-a-fp8`                                                      |

## Memory (llama.cpp guide, model data + compute buffers + KV)

| Model | Model data | Total at 8,192 ctx | At 32,768 | At 131,072 |
| ----- | ---------- | ------------------ | --------- | ---------- |
| 20b   | 12.0 GB    | 14.9 GB            | 15.5 GB   | 17.9 GB    |
| 120b  | 61.0 GB    | 64.0 GB            | 64.9 GB   | 68.5 GB    |

KV is small because of the 128-token sliding window on half the layers. Add engine overhead on top of these.

## NVIDIA DGX Spark (GB10, 128 GB unified)

- **120b fits comfortably**; 20b is a poor use of the box unless it is a fast side model.
- **Ollama**: NVIDIA's vibe-coding playbook uses `ollama pull gpt-oss:120b` (65 GB, 128K). Easiest path.
- **vLLM**: NVIDIA's [vLLM playbook](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/vllm/README.md) lists
  `openai/gpt-oss-20b` and `openai/gpt-oss-120b` (MXFP4) as supported on the NGC `nvcr.io/nvidia/vllm` image. Start from
  `vllm serve openai/gpt-oss-120b` in that image and add flags only if needed.
- **llama.cpp**: CUDA build, `ggml-org/gpt-oss-120b-GGUF`, `--jinja`. Discussion
  [#16578](https://github.com/ggml-org/llama.cpp/discussions/16578) tracks Spark benchmarks.
- **Community reports, not upstream (treat as unverified for your version):** stock vLLM on SM121 needs the Marlin MXFP4 MoE
  backend (`VLLM_MXFP4_BACKEND=marlin` / `--moe-backend=marlin`) and `--attention-backend=TRITON_ATTN`, because the CUTLASS FP4
  path produced a wrong first Harmony token ([vllm#37030](https://github.com/vllm-project/vllm/issues/37030), open) and
  FlashInfer failed on attention sinks ([write-up](https://conselara.dev/notes/gpt-oss-120b-single-dgx-spark/), vLLM 0.20.1
  on NGC 26.05). Forks add CUTLASS MXFP4 kernels for roughly 57-69 tok/s single stream
  ([spark-vllm-mxfp4-docker](https://github.com/christopherowen/spark-vllm-mxfp4-docker),
  [gptoss-spark](https://github.com/luka-loehr/gptoss-spark)); they are not in upstream vLLM and pin their own builds, so
  review and benchmark before adopting. With `HF_HUB_OFFLINE=1` or no internet, harmony's vocab download fails: see
  `known-issues.md`.
- Do not use `--distributed-executor-backend ray` for a single-GPU instance (NVIDIA forum stack write-up: Ray overhead pushed
  memory past its OOM threshold).
- Follow the `self-hosted-llms` skill for memory planning, llama-swap and the gateway.

## Consumer NVIDIA RTX (llama.cpp)

- 20b (11.27 GiB) fits on 16 GB cards (RTX 4080 SUPER, 5060 Ti, 5070 Ti and 5080 appear in the guide's benchmarks).
- 120b does not fit in 24-32 GB VRAM; offload experts: `--n-cpu-moe N` keeps N MoE layers on CPU. The guide reports about
  30 t/s at zero context on an RTX 5090 with `--n-cpu-moe 21` and needs about 8 GB VRAM minimum, plus ~64 GB system RAM.
  On Windows, check that GPU memory does not exceed VRAM or it swaps and slows down.
- Typical: `llama-server -hf ggml-org/gpt-oss-20b-GGUF --ctx-size 0 --jinja -ub 2048 -b 2048 --temp 1.0 --top-p 1.0`.
  `-fa` enables flash attention where the backend supports it. For several parallel agents add `-np 4` and a larger
  `--ctx-size` (more memory).
- vLLM on Ada, Ampere and RTX 5090: vLLM's recipe says Ampere works by default (`TRITON_ATTN` plus Marlin MXFP4) and that
  Ada and RTX 5090 support is still in progress.

## Apple Silicon

- **llama.cpp (Metal)**: `llama-server -hf ggml-org/gpt-oss-20b-GGUF --ctx-size 0 --jinja -ub 2048 -b 2048`. The guide measured
  gpt-oss-20b MXFP4 at about 116 tok/s decode on M2 Ultra and 115 on M3 Ultra, and 120b at about 80 tok/s on M2 Ultra.
  Keep model plus context under about 70% of unified memory; raise the wired limit with `sudo sysctl iogpu.wired_limit_mb=...`
  only with the user's approval.
- **MLX**: `mlx-community/gpt-oss-20b-MXFP4-Q8` (about 12 GB peak on a 32 GB M1 Max in one third-party benchmark);
  `...-120b-MXFP4-Q8` needs a large-memory Mac. Quality versus the GGUF was not compared by any source read. See the
  `local-llms` skill for mlx-lm and LM Studio.
- **Ollama**: `ollama run gpt-oss:20b` (14 GB) or `gpt-oss:120b` (65 GB).

## Datacenter

| GPU                          | Engine and settings                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H100 / H200, vLLM            | Recipe config: `no-enable-prefix-caching`, `max-cudagraph-capture-size 2048`, `max-num-batched-tokens 8192`, `stream-interval 20`. TP1 on 80 GB needs `--gpu-memory-utilization 0.95 --max-num-batched-tokens 1024`; at TP2 stay below 0.95                                                                                                          |
| B200, vLLM                   | Same plus `kv-cache-dtype fp8` and `VLLM_USE_FLASHINFER_MOE_MXFP4_MXFP8=1` when compute capability is 10.0                                                                                                                                                                                                                                           |
| Throughput vs latency (B200) | TP1 with the largest batch for per-GPU throughput; TP4-8 with small batch (8) for latency; TP2 with 128 for balance                                                                                                                                                                                                                                  |
| Speculative decoding         | EAGLE3: `--speculative-config '{"model":"nvidia/gpt-oss-120b-Eagle3-v3","num_speculative_tokens":7,"method":"eagle3","draft_tensor_parallel_size":1}'`                                                                                                                                                                                               |
| TensorRT-LLM                 | Blackwell (B200/GB200/B300/GB300) MXFP8 activations with MXFP4 weights on the `TRTLLM` MoE backend; H200 uses BF16 activations on `TRITON`. `trtllm-serve openai/gpt-oss-120b --config <yaml>`; curated configs `gpt-oss-120b-latency.yaml`, `-throughput.yaml` ship in the container (guide tested `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc29`) |
| SGLang                       | `python -m sglang.launch_server --model openai/gpt-oss-120b --tp 8 --reasoning-parser gpt-oss --tool-call-parser gpt-oss` (the docs page has a hardware-specific command generator)                                                                                                                                                                  |
| AMD MI300x/MI325x            | `vllm serve openai/gpt-oss-120b` with the ROCm wheel; the recipe lists AITER settings validated on vLLM 0.17.0; MI355x uses `amd/gpt-oss-120b-w-mxfp4-a-fp8`                                                                                                                                                                                         |

Hopper small-concurrency regression: the vLLM recipe notes v0.12.0 regressed on Hopper at low concurrency
(vllm#28894, fixed by PR 30528); `VLLM_MXFP4_USE_MARLIN=1` was the workaround for the affected version only.

## Context

Native max 131,072. The vLLM recipe benchmarks 8xH100 TP8 with `--max-model-len 131072`; llama.cpp's `-c 0` selects the
model default (131072). Unsloth suggests at least 16,384 as a minimum working context. No extension beyond 131,072 was found
for the official models (NVIDIA's Puzzle variant raises its YaRN factor for stability at 128K, not beyond it).

## Sources

- https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html
- https://github.com/ggml-org/llama.cpp/discussions/15396, https://github.com/ggml-org/llama.cpp/discussions/16578
- https://nvidia.github.io/TensorRT-LLM/deployment-guide/deployment-guide-for-gpt-oss-on-trtllm.html
- https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/vllm/README.md
- https://ollama.com/library/gpt-oss
- https://docs.sglang.ai/basic_usage/gpt_oss.html
- https://unsloth.ai/docs/models/gpt-oss-how-to-run-and-fine-tune
- https://huggingface.co/mlx-community/gpt-oss-20b-MXFP4-Q8
- https://omlx.ai/benchmarks/performance/two1eeo4
- https://forums.developer.nvidia.com/t/running-a-full-llm-stack-on-dgx-spark-gb10-your-application-litellm-llama-swap-vllm-llama-cpp-ollama/367580
