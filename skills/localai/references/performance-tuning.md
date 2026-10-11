# Tune LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

## Multi-model memory

By default models stay loaded once used. On limited VRAM that blocks loading the next one.

| Control                                            | Setting                                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------------- |
| Keep at most N backends, evict least recently used | `LOCALAI_MAX_ACTIVE_BACKENDS=N` (`0` unlimited, `1` single backend)             |
| Unload idle backends                               | `LOCALAI_WATCHDOG_IDLE=true`, `LOCALAI_WATCHDOG_IDLE_TIMEOUT=15m`               |
| Kill stuck backends                                | `LOCALAI_WATCHDOG_BUSY=true`, `LOCALAI_WATCHDOG_BUSY_TIMEOUT=5m`                |
| Check cadence                                      | `LOCALAI_WATCHDOG_INTERVAL=500ms`                                               |
| Evict even with active calls                       | `LOCALAI_FORCE_EVICTION_WHEN_BUSY=true` (default false, interrupts requests)    |
| Wait for busy models before eviction               | `LOCALAI_LRU_EVICTION_MAX_RETRIES=30`, `LOCALAI_LRU_EVICTION_RETRY_INTERVAL=1s` |

LRU and watchdogs combine. The Settings page can change watchdog values without a restart. A watchdog kill is expected behavior, not a crash; the busy timeout is a trap for long generations, so size it above your longest request.

`LOCALAI_SINGLE_ACTIVE_BACKEND` is deprecated; use `--max-active-backends=1`.

By default LocalAI counts all detected GPU memory as available. On a shared machine, cap it with `LOCALAI_VRAM_BUDGET=80%` (or an absolute `12GB`); the same variable works on distributed workers. `LOCALAI_VRAM_WARM_LIMIT=0` disables the startup gallery size probing (the upstream compose files set it).

## Concurrency

- `LOCALAI_MAX_CONCURRENT_BACKEND_REQUESTS` (default 1024): process-wide ceiling for backend inference. Extra requests get a retryable error (docs say 429; the flag help text says 503, so handle both).
- Per-model `max_concurrent` in the model YAML rejects extra requests with 429 and `Retry-After` instead of queueing.
- llama.cpp slots: option `parallel:N` (or `LLAMACPP_PARALLEL`) enables continuous batching across N slots; each slot divides the context.

## llama.cpp options (`options:` in model YAML)

| Option                                                   | Effect                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `parallel:N`                                             | N concurrent slots                                                                                              |
| `use_jinja:true`                                         | Use the model's Jinja chat template                                                                             |
| `cache_ram:N`                                            | Host RAM prompt cache in MiB (default 8192; `0` off; `-1` unlimited, which can grow with many distinct prompts) |
| `kv_unified:true`, `cache_idle_slots:true`               | Prerequisites for idle-slot prompt caching; on by default since v4.3                                            |
| `cache_reuse:N`                                          | Minimum chunk for KV shifting reuse (default off)                                                               |
| `slot_prompt_similarity:F`                               | Prefix match needed to reuse a slot (default 0.1)                                                               |
| `context_shift:true`                                     | Allow context shifting                                                                                          |
| `fit_params`, `fit_target`, `fit_ctx`                    | Auto-fit to free memory (defaults true, 1024 MiB, 4096 minimum context)                                         |
| `devices`, `split_mode`                                  | Multi-GPU placement                                                                                             |
| `swa_full`, `ctx_checkpoints`, `warmup`, `no_op_offload` | Advanced cache and startup behavior                                                                             |

Hardware auto-tuning raises defaults like batch size on Blackwell and a VRAM-scaled slot count. Anything set in the YAML wins; `LOCALAI_DISABLE_HARDWARE_DEFAULTS=true` turns the auto values off. The effective values are logged at INFO when a model loads.

Model YAML essentials: `gpu_layers` (use a large number for all), `context_size`, `threads` at physical cores, `mmap: false` when models sit on an HDD, and keep models on SSD.

## Speculative decoding

llama.cpp options pass through: `spec_type:draft-mtp`, `spec_n_max:3`, `spec_p_min:0.75` (MTP-capable GGUFs). Python engines take their own settings via `engine_args`.

## Slow checklist

1. `DEBUG=true` and read token timing and the offloaded-layer count in the backend log.
2. Confirm the GPU backend was selected (a CPU build serving a GPU model is the common cause). Use `LOCALAI_FORCE_META_BACKEND_CAPABILITY` if detection is wrong.
3. Stream a request and watch the first-token delay: a long gap is model load or prefill, not decode.
4. Check that the model fits (lower `context_size` or `gpu_layers` before blaming the engine).

Engine-level tuning (ik_llama.cpp, vLLM and so on) belongs to those skills, since LocalAI only passes options through.
