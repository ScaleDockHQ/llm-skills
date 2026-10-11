# Scaling and tuning

> Verified against Ray 2.59.0 (docs `serve/advanced-guides/advanced-autoscaling`, `serve/llm/user-guides/configuration`), KubeRay v1.7.1 sample `ray-service.llm-serve.yaml`, 2026-10-11

## Two autoscalers

1. **Serve replica autoscaler**: `deployment_config.autoscaling_config` adds or removes replicas by ongoing requests.
2. **Ray cluster autoscaler** (KubeRay): adds worker pods when pending replicas need GPUs; bounded by the worker group's
   `minReplicas`/`maxReplicas`. If replicas stay pending, check this second layer.

## autoscaling_config defaults (Serve docs)

| Key                                       | Default        | Meaning                                                   |
| ----------------------------------------- | -------------- | --------------------------------------------------------- |
| `min_replicas` / `max_replicas`           | 1 / 1          | `min_replicas: 0` allows scale to zero, with a cold start |
| `initial_replicas`                        | `min_replicas` |                                                           |
| `target_ongoing_requests`                 | 2              | average in-flight requests per replica to steer to        |
| `upscale_delay_s`                         | 30             |                                                           |
| `downscale_delay_s`                       | 600            | raise it if cold start is expensive                       |
| `downscale_to_zero_delay_s`               | optional       | separate delay for 1 to 0                                 |
| `upscaling_factor` / `downscaling_factor` | 1.0            | gain; `*_smoothing_factor` are deprecated names           |

`max_ongoing_requests` defaults to 5; set it 20 to 50% above `target_ongoing_requests`. LLM replicas batch many
requests, so the KubeRay sample uses `target_ongoing_requests: 64` and `max_ongoing_requests: 128`: start there,
then measure TTFT and throughput at the real concurrency and adjust. `max_queued_requests` caps the queue.

## Tuning order

1. Fit one replica: `max_model_len`, `gpu_memory_utilization`, TP size (flags: skill `vllm`).
2. Set `max_ongoing_requests` near the engine's useful concurrency (`max_num_seqs`).
3. Pick `target_ongoing_requests` for the latency objective; lower for tighter latency.
4. Choose a router for the workload (`references/features.md`).
5. Cold start: weights from a mirror or volume, image preloaded on GPU nodes, long `downscale_delay_s`,
   probe and health-check timeouts above model load time (`health_check_timeout_s`).

## Pod-level autoscaling alternative

Ray Serve scales Serve replicas inside the Ray cluster. Scaling plain vLLM Deployments on queue depth or GPU
metrics is a different layer: skill `keda`.

## Sources

https://docs.ray.io/en/latest/serve/advanced-guides/advanced-autoscaling.html
