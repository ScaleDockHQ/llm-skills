# TabbyAPI configuration

> Verified against TabbyAPI main (20d66e2, config_sample.yml) with ExLlamaV3 v1.6.1, 2026-10-11

Copy `config_sample.yml` to `config.yml` in the TabbyAPI directory (or mount at `/app/config.yml`). "Every value has a default"; without a config file TabbyAPI starts with no model loaded. Do not quote values unless the comment says so. The authoritative field list is the comment text in `config_sample.yml` of the version you run; read it after each update.

CLI overrides config: `python main.py --model-name X --max-seq-len 32768`; hyphens replace underscores (sub-option names like `--gpu-split-auto`). Booleans are overrides, so with `gpu_split_auto: true` in YAML the CLI form is `--gpu-split-auto False`. Complex values (nested mappings such as `sampling`) are not on the CLI. Subcommand: `main.py download <repo_id> [--folder-name N] [--revision BRANCH] [--token T]`.

## network

| Key                      | Default     | Notes                                                        |
| ------------------------ | ----------- | ------------------------------------------------------------ |
| `host`                   | `127.0.0.1` | `0.0.0.0` exposes on all adapters (Docker CMD passes it)     |
| `port`                   | `5000`      | exits if taken; it does not pick another                     |
| `disable_auth`           | `false`     | loopback only; also expose to browser pages on the host      |
| `allowed_origins`        | `["*"]`     | CORS allowlist, not auth; set `[]` when `disable_auth` is on |
| `disable_fetch_requests` | `false`     | blocks fetching remote images by URL                         |
| `send_tracebacks`        | `false`     | debug only                                                   |
| `api_servers`            | `["OAI"]`   | `OAI`, `Kobold`                                              |
| `sse_ping_interval`      | `15`        | SSE keep-alive seconds; 0 disables                           |
| `access_log`             | `false`     | log every HTTP request                                       |

## logging

`log_prompt`, `log_generation_params`, `log_requests` (all false), `log_live_status` (true, interactive terminal only), `log_timestamps` (true), `log_chat_completion_requests` (false; writes full requests with prompts to `logs/debug/`, a privacy risk).

## model

Most options apply to the startup load only (ephemeral); add key names to `use_as_default` to make them fallbacks for API loads.

| Key                                                                                                          | Default                                    | Notes                                                                    |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------ | ------------------------------------------------------------------------ |
| `model_dir`                                                                                                  | `models`                                   | persisted across loads                                                   |
| `model_name`                                                                                                 | none                                       | folder name; required to load at startup                                 |
| `backend`                                                                                                    | auto                                       | only `exllamav3` is listed                                               |
| `inline_model_loading`                                                                                       | `false`                                    | switch by `model` in a request (strict: 404 unknown, 503 failed load)    |
| `use_dummy_models`, `dummy_model_names`                                                                      | `false`, `["gpt-3.5-turbo"]`               | fake names for clients that insist on OpenAI names                       |
| `max_seq_len`                                                                                                | `min(max_position_embeddings, cache_size)` | `-1` reads config.json                                                   |
| `cache_size`                                                                                                 | `4096`                                     | tokens, multiple of 256; the shared KV pool for all concurrent sequences |
| `cache_mode`                                                                                                 | `FP16`                                     | `k_bits,v_bits` each 2 to 8, e.g. `8,8`; legacy `Q8 Q6 Q4`               |
| `tensor_parallel`                                                                                            | `false`                                    | falls back to autosplit without `gpu_split`                              |
| `tensor_parallel_backend`                                                                                    | `native`                                   | `native` for PCIe, `nccl` for NVLink                                     |
| `gpu_split_auto`                                                                                             | `true`                                     | ignored with tensor parallel                                             |
| `autosplit_reserve`                                                                                          | `[96]`                                     | MB per GPU; negative excludes that GPU                                   |
| `gpu_split`                                                                                                  | `[]`                                       | GB per GPU                                                               |
| `cpu_moe_offload_layers`                                                                                     | 0                                          | whole MoE layers on CPU, e.g. 999; not with tensor parallel              |
| `cpu_moe_split_experts`                                                                                      | 0                                          | coldest experts per layer on CPU; mutually exclusive with the above      |
| `cpu_moe_threads`                                                                                            | unset                                      | else `EXL3_MOE_CPU_THREADS`, else half the cores                         |
| `layer_map`                                                                                                  | unset                                      | RYS layer traversal order (list or `"0..6,4..6"`)                        |
| `ngram_ram`, `embed_stream_from_disk`                                                                        | false                                      | embedding table placement (large vocab / PLE models)                     |
| `rope_scale`, `rope_alpha`                                                                                   | 1.0, unset                                 | ignored when the model has YaRN scaling                                  |
| `chunk_size`                                                                                                 | 2048                                       | prompt ingestion chunk; 512 to 4096 sensible                             |
| `output_chunking`                                                                                            | `true`                                     | allocate cache per chunk instead of whole completion                     |
| `max_batch_size`                                                                                             | unset                                      | engine default 32 for transformers, 4 for recurrent models               |
| `recurrent_checkpoint_interval`, `_pp`                                                                       | unset                                      | recurrent-layer models, multiples of 256                                 |
| `prompt_template`                                                                                            | none                                       | jinja file in `templates/`, or a named template in tokenizer_config.json |
| `vision`, `vision_offload`                                                                                   | false                                      | enable image input; keep vision weights in pinned RAM                    |
| `warmup`                                                                                                     | `false`                                    | run forward passes at load so autotune/graph capture happens early       |
| `sampling`                                                                                                   | none                                       | per-model sampler overrides                                              |
| `template_vars_default`, `template_vars_force`                                                               | `{}`                                       | e.g. `{reasoning_effort: high}`; `force_enable_thinking` is deprecated   |
| `reasoning`, `reasoning_start_token`, `reasoning_end_token`, `start_in_reasoning`, `tool_calls_in_reasoning` | true, auto, auto, auto, true               | reasoning parser (see `features.md`)                                     |
| `reasoning_budget_tokens`, `reasoning_budget_message`                                                        | unset                                      | cap thinking                                                             |
| `tool_format`                                                                                                | `auto`                                     | blank disables tool parsing                                              |
| `harmony`, `muse_glimmer`                                                                                    | auto                                       | whole-response structured formats                                        |

## draft_model

`draft_mode` (`model` default; `disabled`, `mtp`, `ngram`), `draft_model_dir`, `draft_model_name`, `draft_rope_scale`, `draft_rope_alpha`, `draft_cache_mode` (FP16), `draft_gpu_split`, `draft_num_tokens`, `dynamic_draft` (false), `ngram_match_min` (2), `hybrid_draft_tokens` (0). Drafting uses more VRAM.

## sampling, lora, embeddings

- `sampling.override_preset` (sample file sets `safe_defaults`: temperature 0.8, top_k 40, top_p 0.95, min_p 0.05 for parameters a request omits; startup fails if the named preset does not exist and warns if none is set). Clear it when benchmarking. Inline sampler overrides use `name: {override: v, force: false}`; `reasoning_override` applies only while reasoning. Files live in `sampler_overrides/`.
- `lora.lora_dir` (`loras`), `lora.loras` (list of `name`, `scaling`).
- `embeddings.embedding_model_dir`, `embeddings_device` (`cpu`, `auto`, `cuda`; cpu recommended), `embedding_model_name`. Needs the extras install (`pip install .[extras]` or `latest-extras`).

## memory

`sysmem_recurrent_cache` (4096 MB), `sysmem_kv_cache` (0, second-tier host cache), `disk_cache_dir` (third tier, experimental, needs ExLlamaV3 1.6.2 or later and `sysmem_kv_cache` > 0), `disk_cache_size` (51200 MB), `disk_cache_flush_on_idle` (true), `disk_cache_checkpoint_interval` (4096), `sysmem_multimodal_cache` (1024), `cuda_malloc_async` (false; by default expandable segments are enabled unless `PYTORCH_CUDA_ALLOC_CONF` is set).

## developer

`unsafe_launch` (skip version check; update instead), `disable_request_streaming`, `realtime_process_priority`, `seqlog*` (needs a Seq server).

## Authentication files

TabbyAPI generates `api_tokens.yml` on first start with an API key and an admin key (keep `0600`, never print). If compromised: stop the server, delete the file, restart. API key: generation and list-current endpoints. Admin key: load, unload, templates, LoRA, sampler switch, download. Admin keys list the whole model directory on `/v1/models`; API keys list only the loaded model.

## Per-model config

`<model folder>/tabby_config.yml` holds the same `model:` and `draft_model:` keys. Its values take precedence over config.yml and over load-request parameters. Used with inline loading to give each model its own defaults:

```yaml
model:
  max_seq_len: 32768
  cache_mode: 6,6
  tool_format: qwen3_coder
draft_model:
  draft_model_name: Qwen3-0.6B-exl3
```

See `templates/tabby-config.yml` for a full starting config.
