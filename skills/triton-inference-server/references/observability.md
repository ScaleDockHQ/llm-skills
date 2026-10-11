# Triton observability

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

`curl localhost:8002/metrics` (port `--metrics-port`, bind `--metrics-address`). `--allow-metrics=false` disables all,
`--allow-gpu-metrics=false` GPU only, `--metrics-interval-ms` sets GPU/CPU polling.

| Group                   | Metrics                                                                                                                                                                                                                                                        |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Counts (per model)      | `nv_inference_request_success`, `nv_inference_request_failure`, `nv_inference_count`, `nv_inference_exec_count`, `nv_inference_pending_request_count`                                                                                                          |
| Latency (cumulative us) | `nv_inference_request_duration_us`, `nv_inference_queue_duration_us`, `nv_inference_compute_input_duration_us`, `nv_inference_compute_infer_duration_us`, `nv_inference_compute_output_duration_us` (turn off with `--metrics-config counter_latencies=false`) |
| Histograms              | `nv_inference_first_response_histogram_ms` (`--metrics-config histogram_latencies=true`)                                                                                                                                                                       |
| Summaries               | `nv_inference_*_summary_us` (`--metrics-config summary_latencies=true`)                                                                                                                                                                                        |
| GPU                     | `nv_gpu_utilization`, `nv_gpu_memory_used_bytes`, `nv_gpu_memory_total_bytes`, `nv_gpu_power_usage`, `nv_energy_consumption`                                                                                                                                   |
| CPU                     | `nv_cpu_utilization`, `nv_cpu_memory_used_bytes`, `nv_cpu_memory_total_bytes`                                                                                                                                                                                  |
| Response cache          | `nv_cache_num_hits_per_model`, `nv_cache_num_misses_per_model`, hit/miss duration                                                                                                                                                                              |

Average queue time = delta(`queue_duration_us`) / delta(`inference_count`). Rising `pending_request_count` and queue time
mean the model instances are saturated. Limits: no GPU metrics on MIG devices; a separate DCGM agent can break them; with
an NVSwitch shutdown segfault use `--allow-gpu-metrics false`.

Logging: `--log-verbose=1` and the logging extension (`/v2/logging`). Tracing: the trace extension and `docs/user_guide/trace.md`
(`--trace-config`). Per-model stats: `GET /v2/models/<model>/stats`.
