# Serve config: LLMConfig, YAML and the serve CLI

> Verified against Ray 2.59.0 (docs `serve/llm/user-guides/configuration`, `serve/llm/quick-start`), 2026-10-11

## LLMConfig fields

Only `model_loading_config` is required. YAML keys map one to one.

| Field                    | Default  | Notes                                                                                                                                                                                                                                  |
| ------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `model_loading_config`   | required | `model_id` (name clients send), `model_source` (HF ID, local path or `{bucket_uri: s3://...}`), `tokenizer_source`                                                                                                                     |
| `engine_kwargs`          | `{}`     | vLLM engine args, snake_case: `tensor_parallel_size`, `pipeline_parallel_size`, `max_model_len`, `gpu_memory_utilization`, `max_num_seqs`, `kv_transfer_config`                                                                        |
| `accelerator_type`       | none     | `A10G`, `A100`, `H100`, `H200`, `L4`, `L40S`, `T4`, TPUs `TPU-V4/V5P/V6E`; `A10` is normalized to `A10G`; unsupported values raise                                                                                                     |
| `accelerator_config`     | none     | inferred; rarely set                                                                                                                                                                                                                   |
| `placement_group_config` | none     | `bundle_per_worker` or `bundles`, plus `strategy`: `PACK`, `STRICT_PACK`, `SPREAD`, `STRICT_SPREAD`                                                                                                                                    |
| `deployment_config`      | `{}`     | Serve options: `num_replicas`, `autoscaling_config`, `max_ongoing_requests`, `max_queued_requests`, `request_router_config`, `ray_actor_options`, health-check and graceful-shutdown timeouts, `logging_config`, `user_config`, `name` |
| `lora_config`            | none     | `dynamic_lora_loading_path`, `max_num_adapters_per_replica` (16), `download_timeout_s` (30), `max_download_tries` (3)                                                                                                                  |
| `runtime_env`            | none     | Ray runtime env for replica and engine workers (`env_vars`, ...)                                                                                                                                                                       |
| `llm_engine`             | `vLLM`   | only supported value                                                                                                                                                                                                                   |
| `server_cls`             | none     | custom server, for example `SGLangServer` (early-stage community integration)                                                                                                                                                          |
| `experimental_configs`   | `{}`     | `stream_batching_interval_ms` (50), `num_ingress_replicas`                                                                                                                                                                             |
| `log_engine_metrics`     | `True`   | export vLLM metrics on the Ray Prometheus port                                                                                                                                                                                         |
| `callback_config`        | default  | initialization callbacks (see the deployment-initialization guide)                                                                                                                                                                     |

Cloud mirror URIs: `s3://`, `gs://`, `abfss://`, `azure://`.

## Entry points

- `build_openai_app({"llm_configs": [cfg1, cfg2]})` (YAML `import_path: ray.serve.llm:build_openai_app`): one
  OpenAI-compatible app, several models, routed on `model`.
- `build_pd_openai_app({"prefill_config": ..., "decode_config": ...})`: prefill/decode (`references/features.md`).
- `build_dp_openai_app({"llm_config": ...})`: data-parallel attention (`references/parallelism-multinode.md`).
- Bind pattern for custom composition: `LLMServer.get_deployment_options(cfg)`, `OpenAiIngress`,
  `make_fastapi_ingress`.

Each model has its own `LLMServer` deployment; `OpenAiIngress` routes on the `model` field.

## Config file shape

```yaml
applications:
  - name: llm_app
    route_prefix: "/"
    import_path: ray.serve.llm:build_openai_app
    args:
      llm_configs:
        - models/qwen-0.5b.yaml # path form is supported (standalone config)
        - model_loading_config:
            { model_id: qwen-1.5b, model_source: Qwen/Qwen2.5-1.5B-Instruct }
          accelerator_type: A10G
```

## serve CLI

```bash
serve run config.yaml            # blocking, local dev; Ctrl-C tears down
serve deploy config.yaml         # submit to a running cluster (--address http://HEAD:8265)
serve status                     # app and deployment status, replica states
serve config                     # the config the cluster is running
serve shutdown -y                # remove all applications (ask first)
```

Under KubeRay the same YAML sits in `RayService.spec.serveConfigV2`. Edit the CR instead of running
`serve deploy` against a RayService-managed cluster; the operator reconciles it.

## Gated models and secrets

```yaml
runtime_env:
  env_vars:
    HF_HUB_ENABLE_HF_TRANSFER: "1"
```

Do not paste `HF_TOKEN` into YAML. On Kubernetes use `env.valueFrom.secretKeyRef` on the worker container; on a
VM export it in the shell that starts `ray start` or `serve run`. The docs pass it through `runtime_env` with
`os.environ["HF_TOKEN"]`.

## Sources

https://docs.ray.io/en/latest/serve/llm/user-guides/configuration.html
