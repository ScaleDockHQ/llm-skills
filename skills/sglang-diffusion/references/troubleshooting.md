# SGLang Diffusion: troubleshooting

> Verified against SGLang Diffusion v0.5.21 (docs CLI, deployment, parallelism, installation and OpenAI API pages), 2026-10-11

Start with the server log, `pip list | grep -i sglang`, `nvidia-smi` and `curl /v1/models`.

| Symptom                                              | Cause                                              | Fix                                                                                                                         |
| ---------------------------------------------------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Install resolves a pre-release error                 | extra pins need pre-releases                       | add `--prerelease=allow`                                                                                                    |
| `sglang generate` unknown model or wrong pipeline    | path not in the registry                           | use a catalogued ID, set `--model-id`, or `--backend diffusers`                                                             |
| CUDA OOM at load or first request                    | DiT, encoder or VAE too big for the least-free GPU | `--performance-mode memory`, component or layerwise offload, quantization, smaller size or frames (`performance-memory.md`) |
| OOM only at VAE decode of video                      | spatial-shard decode on big shapes                 | tiled VAE (`vae_tiling`), `--vae-config.parallel-decode-mode` back to tiled                                                 |
| `/health` returns 503 for minutes                    | server warmup or compile in progress               | wait; probes use `/liveness` for liveness and a big startup budget                                                          |
| First request very slow                              | compile or lazy init                               | `--warmup-mode server`, or accept once                                                                                      |
| Server unreachable from host in Docker               | bound to loopback inside the container             | `--host 0.0.0.0` inside, publish on host loopback                                                                           |
| Anyone can reach the API                             | no built-in auth, CORS open                        | gateway with auth; keep loopback (`serving-and-ops.md`)                                                                     |
| HTTP 400 on request                                  | task not supported or missing conditioning         | read `supported_task_types`, send `task_type`, give an image for I2V                                                        |
| Model-specific field has no effect                   | active model does not declare it                   | check the model's cookbook field list                                                                                       |
| `--layerwise-resident-layers dit=4` ignored          | group alias in a component map                     | use the loaded component key, e.g. `transformer=4`                                                                          |
| Offload fails at startup naming a component          | component lacks a layer-structure declaration      | choose another residency mode for it                                                                                        |
| SP or TP start fails with shape errors               | head or sequence count not divisible               | adjust degrees (`parallelism` page); `num_gpus` must equal the product                                                      |
| Cache-DiT with FSDP error                            | unsupported combination                            | drop one                                                                                                                    |
| Output changes after enabling caches or quantization | lossy options                                      | disable, or use `--quality lossless`                                                                                        |
| Video request times out client side                  | long generation                                    | raise timeouts; poll `/v1/videos`                                                                                           |
| Gated model download fails                           | missing licence or token                           | accept the licence, export `HF_TOKEN` (see `hugging-face`)                                                                  |
| `/metrics` 404                                       | metrics are off by default                         | `--enable-metrics`                                                                                                          |

File bugs at sgl-project/sglang with version, command line (redact tokens) and log.
