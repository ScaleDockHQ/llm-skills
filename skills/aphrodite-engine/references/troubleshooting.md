# Aphrodite Engine troubleshooting

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

Capture first: full command, version/commit, model revision, platform, Python, PyTorch, CUDA/ROCm. Keep the
first error in the log; later ones are often cleanup noise.

| Symptom                                      | Cause and fix                                                                                                                                                                                |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CUDA OOM at startup                          | Lower `--max-num-seqs`, set a smaller `--max-model-len` or `auto`, lower `--gpu-memory-utilization` when sharing the GPU (it applies to total capacity and fails if that amount is not free) |
| OOM during requests                          | Check preemptions and lengths, reduce concurrency or context, try `--kv-cache-dtype fp8`, set `--limit-mm-per-prompt` for large media                                                        |
| Unsupported architecture                     | Read `architectures` in config.json, compare with the model table; try `--model-impl` Transformers backend; pin `--revision`                                                                 |
| Missing native extension or undefined symbol | Wheel does not match Python/PyTorch; rebuild native code with `cmake --build --preset release --target install`                                                                              |
| Requests hang                                | `/health` locally; inspect waiting requests; distributed: all ranks joined, firewall, `NCCL_DEBUG=INFO` (turn off after)                                                                     |
| Tool or reasoning text not parsed            | Parser must match the model family; test at temperature 0; disable auto tool choice to separate parser from model                                                                            |
| Slow TTFT                                    | Prefill, queueing or media preprocessing; slow inter-token: decode kernels, communication or low speculative acceptance                                                                      |
| Speculation slows things                     | High concurrency or low acceptance; reduce depth or disable                                                                                                                                  |
| Multi-node init timeout                      | Compare `HEAD_IP`, `--master-port`, `--nnodes`, `--node-rank` across nodes; same GPU count everywhere                                                                                        |
| 401                                          | `--api-key` or `APHRODITE_API_KEY` set: send `Authorization: Bearer`                                                                                                                         |
| Gated model download fails                   | `HF_TOKEN` in the environment (read scope)                                                                                                                                                   |
| Video requests fail with GPU decode          | `pynvvideocodec` needs CUDA MPS and `--mm-ipc-gpu-memory-gb`                                                                                                                                 |
| Docker image missing or stale                | No current registry image found; build `docker/Dockerfile` (`install.md`)                                                                                                                    |

Read-only discovery: `aphrodite --version`, `aphrodite serve --help`, `nvidia-smi topo -m`, `/health`, `/version`,
`/openapi.json`. Report bugs at https://github.com/dphnAI/sonar/issues with a minimal public-model command,
the first traceback and the result with optional features disabled; remove secrets and prompts.
