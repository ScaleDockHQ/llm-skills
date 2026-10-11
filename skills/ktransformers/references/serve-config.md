# Serve configuration

> Verified against KTransformers v0.7.1 (kt-kernel README, `kt-cli.md`, `kt-kernel/python/cli`, and `--kt-*` flags in kvcache-ai/sglang `server_args.py`), 2026-10-11

## `kt` CLI

| Command                                                                       | Use                                                                                            |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `kt run <model>`                                                              | Start the server with auto-tuned parameters; `--dry-run` prints the command without running it |
| `kt chat`                                                                     | Terminal chat against a running server (needs the `openai` package)                            |
| `kt quant <model>`                                                            | Convert weights to CPU INT4/INT8 (`--method int4                                               | int8`, `--input-type fp8 | fp16 | bf16`, `--output`) |
| `kt model`                                                                    | Manage models and storage paths                                                                |
| `kt doctor`, `kt version`, `kt config`, `kt bench`, `kt microbench`, `kt sft` | Diagnose, version, settings, benchmarks, fine-tuning                                           |

The CLI is described upstream as under active development: use `kt <command> --help` on your version.

`kt run` accepts a registry name or alias, or a path. Registered models in 0.7.1 include DeepSeek-V3-0324 (`v3`), DeepSeek-V3.2 (`v3.2`),
DeepSeek-R1-0528 (`r1`), DeepSeek-V4-Flash (`v4`), Kimi-K2-Thinking (`k2`), MiniMax-M2 (`m2`), M2.1, M2.7 and M3 (`m3`). Upstream notes that only some
models run through `kt run`; others use `sglang.launch_server` directly.

```bash
kt run m2 --dry-run                                  # inspect the generated command first
kt run m2 --host 127.0.0.1 --port 30000 --gpu-experts 8 --cpu-threads 64 --numa-nodes 2
kt run /path/to/model --kt-method FP8 --kt-gpu-prefill-threshold 2048
kt run V3.2 --kt-enable-dynamic-expert-update        # unknown options pass straight to SGLang
```

`kt run` options: `--host/-H`, `--port/-p`, `--gpu-experts`, `--cpu-threads`, `--numa-nodes` (a count, or explicit ids by repeating the flag),
`--tensor-parallel-size/--tp`, `--model-path`, `--weights-path`, `--kt-method`, `--kt-gpu-prefill-threshold`, `--attention-backend`, `--max-total-tokens`,
`--max-running-requests`, `--chunked-prefill-size`, `--mem-fraction-static`, `--watchdog-timeout`, `--served-model-name`,
`--disable-shared-experts-fusion` / `--enable-shared-experts-fusion`, `--quantize/-q`, `--advanced`, `--dry-run`. Defaults live in
`~/.ktransformers/config.yaml`: host `0.0.0.0`, port `30000`, env `PYTORCH_ALLOC_CONF=expandable_segments:True` and `SGLANG_ENABLE_JIT_DEEPGEMM=0`.
Always override the host.

## `--kt-*` flags (sglang-kt `server_args.py`)

| Flag                                      | Meaning                                                                                                                                                        |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--kt-method`                             | CPU backend: `AMXINT4` (flag default), `AMXINT8`, `RAWINT4`, `FP8`, `FP8_PERCHANNEL`, `BF16`, `LLAMAFILE`, also `GPTQ_INT4` (AVX2 docs), `MOE_INT8` (AMD BLIS) |
| `--kt-weight-path`                        | Folder with CPU expert weights: converted AMX weights, a GGUF folder (LLAMAFILE), or the original native checkpoint                                            |
| `--kt-cpuinfer`                           | CPU inference threads: physical cores, not hyperthreads                                                                                                        |
| `--kt-threadpool-count`                   | Thread pools: one per NUMA node (flag default 2)                                                                                                               |
| `--kt-numa-nodes`                         | Explicit NUMA ids per pool; length must equal the pool count                                                                                                   |
| `--kt-num-gpu-experts`                    | GPU experts per MoE layer (multiplied by the layer count); ignored if the ratio flag is set                                                                    |
| `--kt-gpu-experts-ratio`                  | Fraction (0 to 1) of all experts on GPU; overrides the count                                                                                                   |
| `--kt-max-deferred-experts-per-token`     | Experts deferred per token for pipelining (0 disables; 1 to 4 recommended; the last MoE layer always runs synchronously)                                       |
| `--kt-gpu-prefill-token-threshold`        | Above this token count, native methods use layerwise GPU prefill (about 1024 to 4096)                                                                          |
| `--kt-enable-dynamic-expert-update`       | Re-place GPU experts from routing statistics during layerwise prefill; needs the prefill threshold                                                             |
| `--kt-expert-placement-strategy`          | `uniform`, `frequency`, `front-loading`, `random`. README says uniform is default, the fork help text says frequency; set it explicitly                        |
| `--init-expert-location`                  | Path to a `.pt` statistics file for `frequency` placement                                                                                                      |
| `--record-kt-gpu-expert-distribution`     | Record which experts are on GPU per forward pass                                                                                                               |
| `--kt-lora-path`, `--kt-expert-lora-path` | Experimental static PEFT adapters for KT-served MoE models (`references/features.md`)                                                                          |

## SGLang flags used with KT in upstream recipes

`--model`, `--host`, `--port`, `--served-model-name`, `--trust-remote-code` (executes model-repo code: only for repos you trust),
`--attention-backend flashinfer|triton`, `--mem-fraction-static 0.80-0.92`, `--chunked-prefill-size 4096-16384`,
`--max-running-requests 4`, `--max-total-tokens`, `--enable-mixed-chunk`, `--tensor-parallel-size`, `--enable-p2p-check`,
`--disable-shared-experts-fusion`, `--fp8-gemm-backend cutlass`, `--tool-call-parser`, `--reasoning-parser`, `--api-key`, `--enable-metrics`.
Full list: `python -m sglang.launch_server --help`. Concurrency stays low (4 in the recipes) because decode is CPU-bound.

## Environment variables

| Variable                                     | Meaning                                                                    |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| `KT_KERNEL_CPU_VARIANT`, `KT_KERNEL_DEBUG`   | Force a CPU variant; print detection                                       |
| `KT_INT8_VNNI_BACKEND`, `KT_RAWINT4_BACKEND` | Pick the INT8 VNNI and RAWINT4 backends (`auto`/`onednn`/`native`, `avx2`) |
| `CUDA_VISIBLE_DEVICES`                       | GPU selection                                                              |
| `HF_TOKEN`, `HF_HOME`                        | Hugging Face auth and cache (never print the token)                        |
| `PYTORCH_ALLOC_CONF`                         | Set to `expandable_segments:True` by `kt run`                              |
| `SGLANG_ENABLE_JIT_DEEPGEMM`                 | `0` in the `kt run` defaults                                               |
| `NCCL_SOCKET_IFNAME`                         | NCCL interface for multi-GPU TP on multi-NIC hosts                         |

## Direct Python API (embedding)

`kt_kernel.KTMoEWrapper(layer_idx, num_experts, num_experts_per_tok, hidden_size, moe_intermediate_size, num_gpu_experts, cpuinfer_threads,
threadpool_count, weight_path, chunked_prefill_size, method, ...)` exposes `load_weights`, `forward`, `submit_forward` and `sync_forward`; it is
for framework authors, not for serving.
