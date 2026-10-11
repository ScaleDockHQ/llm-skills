# vLLM-Omni: serving, deploy configs and stages

> Verified against vLLM-Omni v0.30.0 (vLLM 0.30.0), 2026-10-11

## Command

```bash
vllm serve Tongyi-MAI/Z-Image-Turbo --omni --host 127.0.0.1 --port 8091
```

`vllm` owns the CLI; `--omni` hands the model to vLLM-Omni. Inherited vLLM flags apply (`--api-key`, `--served-model-name`, `--tensor-parallel-size`, `--quantization` and so on; the vLLM config guide for the paired version covers engine options). List the vLLM-Omni arguments from your install with `vllm serve --help` or the docs' generated omni_serve page.

## Pipelines and deploy configs

A model's **PipelineConfig** (Python, fixed topology: stages such as an AR thinker, a talker and a code2wav, or a single DiT) is paired with a **deploy config** YAML (runtime placement and sizing). Bundled deploy YAMLs live in `vllm_omni/deploy/` (Qwen2.5-Omni, Qwen3-Omni, Qwen3-TTS, BAGEL, Cosmos3, CosyVoice3, many TTS models and more) and load automatically for migrated models; pass `--deploy-config file.yaml` only to override. Some models need the flag explicitly in their guide (the Qwen3-TTS example passes `--deploy-config vllm_omni/deploy/qwen3_tts.yaml`). Top-level YAML keys include `base_config` (overlay parent), `async_chunk` (default true; chunked streaming between stages), `session_mode` (`turn` or `duplex`), `connectors`, `edges`, `stages` (per-`stage_id` overrides: `devices`, `gpu_memory_utilization` and engine arguments), `platforms` (`npu`, `rocm`, `xpu` overrides), `pipeline`, `trust_remote_code`, `distributed_executor_backend` (`mp`, `ray`, `external_launcher`), `dtype`, `quantization`, `enable_prefix_caching` and `data_parallel_size`. Topology changes need a new registered pipeline, not YAML. `trust_remote_code: true` executes model-repo code: only for repos you trust.

Per-stage overrides from the CLI: `--stage-overrides '{"1": {"gpu_memory_utilization": 0.5}}'`.

## Multi-stage launch (one stage per process or host)

```bash
CUDA_VISIBLE_DEVICES=0 vllm serve Qwen/Qwen3-Omni-30B-A3B-Instruct --omni --port 8091 \
  --stage-id 0 --omni-master-address 127.0.0.1 --omni-master-port 26000
CUDA_VISIBLE_DEVICES=1 vllm serve Qwen/Qwen3-Omni-30B-A3B-Instruct --omni \
  --stage-id 1 --headless --gpu-memory-utilization 0.5 \
  --omni-master-address 127.0.0.1 --omni-master-port 26000
```

Stage 0 hosts the orchestrator and API; others run `--headless`. On separate hosts the master address must be reachable by the workers: bind it to a private interface, not a public one. One chip can host only one autoregressive stage (unified KV cache); non-AR stages can share a chip. Qwen3-Omni-30B was verified upstream on 2 x H100. Sum of `gpu_memory_utilization` on one GPU must stay below 1.0.

## Throughput options

- `--max-num-seqs N` lets compatible diffusion requests batch in one forward (request mode); only pipelines that declare batch support accept values above 1, otherwise engine init fails. `--request-batch-max-wait-ms` (default 0) adds an admission window and latency.
- `--step-execution` lets the scheduler advance or abort requests between denoise steps (use with `--max-num-seqs 1` as in the docs).
- `--api-server-count N` starts several API frontend processes sharing the stage engines, for CPU-bound frontends with local EngineCore multi-process pipelines. It cannot combine with diffusion, headless or remote stages, Ray, sleep mode or runtime LoRA, and async video jobs return HTTP 409 across workers. Benchmark 1 versus 2 before keeping it.
- `--num-weight-load-threads N` or `--disable-multithread-weight-load` control parallel safetensors loading (faster startup).

## Systemd sketch

Run as a dedicated user, `ExecStart=/path/.venv/bin/vllm serve MODEL --omni --host 127.0.0.1 --port 8091`, `EnvironmentFile=/etc/vllm-omni.env` (mode 0600, holds `HF_TOKEN` and `VLLM_API_KEY`, so the key is not on the command line), `Restart=on-failure`, `TimeoutStartSec=1800` for cold loads. Put TLS and auth at `caddy` or another gateway.
