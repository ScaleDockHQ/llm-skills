# Serving with vLLM on Neuron

> Verified against vllm-neuron release-0.24.0.1.1.0 (README, setup guide, features guide), Neuron docs "AI Inference on Neuron" and "vLLM User Guide for NxD Inference", Neuron SDK 2.32.0, 2026-10-11

Two lines exist. Pick by instance type (`instances-and-sdk.md`). Engine behaviour that is not Neuron-specific is in the `vllm` skill.

## Line 1: vLLM Neuron plugin (Beta, Trn2 and Trn3)

Model implementations live in the plugin. Tested models per the README: Llama 3 (1B, 8B, 70B), GPT-OSS (20B, 120B), Qwen3-VL 32B and Qwen3-Embedding 8B on Trn2 and Trn3. Check the README table for the tag you pin.

```bash
vllm serve openai/gpt-oss-20b \
  --tensor-parallel-size 8 \
  --max-model-len 8192 \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 4
curl -s localhost:8000/v1/models | jq -r '.data[].id'
```

Features marked supported in the README (check per model): continuous batching, OpenAI-compatible APIs, embeddings, streaming, structured outputs, tool calling, TP, SP, DP, EP, CP, paged KV cache, prefix caching, segmented prefill, disaggregated inference (1P1D, xPyD), async scheduling, on-device sampling, EAGLE3, BF16 and FP8 (MXFP4 and MXFP8 weights on Trn3), `/metrics`. Marked not supported: LoRA adapters, pipeline parallelism, chunked prefill, KV cache offloading, MTP, audio input.

### Parallelism

```bash
vllm serve meta-llama/Llama-3.3-70B-Instruct --tensor-parallel-size 64
vllm serve openai/gpt-oss-20b --tensor-parallel-size 8 --data-parallel-size 8          # replicas
vllm serve openai/gpt-oss-20b --tensor-parallel-size 8 --enable-expert-parallel          # MoE
```

Use the smallest TP that fits the model and latency target; add DP for throughput with spare cores. TP counts logical NeuronCores (LNC=2 gives four per Trainium2 chip).

### Compilation, buckets and the cache

Neuron compiles static-shape programs (NEFFs) per bucket, so the first start of a model and shape set compiles for minutes.

- `VLLM_CACHE_ROOT` (default `~/.cache/vllm`): compile cache root; put it on local NVMe, not a network filesystem.
- `NEURON_COMPILED_ARTIFACTS=<dir>`: load pre-compiled models from a directory; if empty, the model is compiled and saved there.
- Buckets via `--additional-config '{"neuron_config": {"num_batched_tokens_buckets": [...], "num_seqs_buckets": [...]}}'`; `decode_context_length_buckets` is optional. More buckets mean slower startup and less padding waste. Start minimal in development (one prefill bucket, one decode bucket), then add buckets to match traffic.
- `VLLM_NEURON_LOG_LEVEL` (`DEBUG`, `INFO`, `WARNING`, `ERROR`) sets plugin log verbosity.
- Pre-compile for production on a Neuron instance or CPU so serving nodes never compile at startup.

### Disaggregated inference

Needs the NIXL LIBFABRIC backend over EFA, plus `libcuda.so.1` (a stub is enough; a `CUDA driver is a stub library (Error 34)` warning is expected) and `libfabric.so.1`. See the plugin's setup guide before attempting it.

## Line 2: vLLM with NxD Inference (Inf2, Trn1, and Trn2/Trn3 maintenance)

Plugin 0.5.x, vLLM 0.16.0, models implemented in `neuronx-distributed-inference`. Supported models per the user guide: Llama 2/3.1/3.3, Llama 4 Scout and Maverick, Qwen 2.5, Qwen 3, Qwen2-VL, Qwen3-VL, Pixtral.

```bash
git clone --branch "0.5.3" https://github.com/vllm-project/vllm-neuron.git
cd vllm-neuron && pip install --extra-index-url=https://pip.repos.neuron.amazonaws.com -e .
vllm serve meta-llama/Meta-Llama-3-8B-Instruct --tensor-parallel-size 32 \
  --max-num-seqs 4 --max-model-len 128 --block-size 32 --num-gpu-blocks-override 256
```

NxD Inference settings go through `--additional-config '{"override-neuron-config": {...}}'`, for example `enable_bucketing`, `context_encoding_buckets`, `token_generation_buckets`, `is_prefix_caching` with `is_block_kv_layout`, `pa_num_blocks` and `pa_block_size` (16 or 32 recommended), `async_mode`, `sequence_parallel_enabled`, `fused_qkv`, and NKI kernel flags such as `attn_kernel_enabled` and `mlp_kernel_enabled`. On-device sampling is on by default and supports only `temperature`, `top_k` and `top_p`; `top_k=-1` becomes 256 and `temperature=0` becomes greedy. Warm-up is skipped by default on Trn2 and enabled on Trn1 and Inf2 per the troubleshooting guide, so send a few dummy requests before real traffic.

## Gateway and clients

The server speaks the OpenAI API on port 8000. For LiteLLM use `hosted_vllm/<model>` with `api_base: http://<host>:8000/v1` (see the `litellm` skill). Keep it private; add `--api-key` or an authenticating proxy.
