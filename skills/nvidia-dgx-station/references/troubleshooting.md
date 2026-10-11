# Troubleshooting DGX Station

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

| Symptom                                                                     | Cause                                          | Fix                                                                                                    |
| --------------------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Model runs on the wrong GPU                                                 | Default selection with an RTX PRO card present | `nvidia-smi topo -m`; `docker run --gpus '"device=N"'` with the GB300 index                            |
| vLLM EngineCore fails, FlashInfer "Buffer overflow ... batch_prefill_tmp_v" | CUDA graph capture failure                     | Use NVIDIA's recommended image `nvcr.io/nvidia/vllm:26.01-py3` (playbook); check for a newer tag first |
| CUDA out of memory                                                          | Context or concurrency too large               | Lower `--max-model-len`, `--max-num-seqs` or `--gpu-memory-utilization`                                |
| Memory pressure within capacity                                             | Cached pages                                   | Diagnostic `drop_caches` (ask first), restart the app                                                  |
| `memory` fields N/A in `nvidia-smi --query-gpu`                             | Unified memory reporting                       | Use plain `nvidia-smi`, `free -h`                                                                      |
| Slow decode on huge models                                                  | Weights spilled to LPDDR5X                     | Quantise or shrink context; see `memory-and-coherency.md`                                              |
| `exec format error`                                                         | amd64 image                                    | Use arm64 or multi-arch image                                                                          |
| Rail down or jumbo ping fails                                               | Cable, crossed rails, MTU                      | `two-station-fabric.md`                                                                                |
| `mlx5dv_reg_dmabuf_mr` error 524                                            | ACS/Data Direct prerequisites                  | `two-station-fabric.md`                                                                                |
| No desktop on the BMC mini DP                                               | BMC output is management only                  | Use the add-in GPU's outputs or SSH                                                                    |

## Sources

- <https://build.nvidia.com/station/vllm/troubleshooting>
- <https://build.nvidia.com/station/connect-two-stations/troubleshooting>
