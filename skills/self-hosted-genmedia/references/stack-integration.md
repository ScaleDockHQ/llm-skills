# Stack integration: LiteLLM → llama-swap → genmedia servers

> Verified against llama-swap v263 (docs/config.example.yaml, KB guides), LiteLLM v1.105.0 docs and Cloudflare "Error 524" docs (updated 2026-07-23), 2026-10-11

The LLM stack (LiteLLM gateway → llama-swap swapper → engines) belongs to the `self-hosted-llms` skill; its engine-sdcpp reference shows the generic "add a non-LLM backend" pattern with sd-server. This file covers the genmedia specifics: which endpoints route, how to group media servers next to LLMs, and how to keep long jobs alive end to end. Ready-to-merge snippets: `assets/llama-swap-genmedia.yaml` and `assets/litellm-genmedia.yaml`.

## What it is and when to choose it

Put media servers behind the same two layers as the LLMs so that clients get one base URL, one key system, one model list, and one place that decides what is loaded:

```text
client ──HTTPS──> [Cloudflare / tailnet] ──> LiteLLM :4000 ──> llama-swap 127.0.0.1:8080 ──> sd-server / whisper-server / Kokoro / ComfyUI on 127.0.0.1:${PORT}
```

Skip LiteLLM only for routes it can't carry (ComfyUI's native API, video jobs); those go through llama-swap's `/comfyui/` or `/upstream/<model>/` passthrough on a private path.

## Install

Nothing new: use the existing LiteLLM and llama-swap. llama-swap's unified container images bundle llama-server, stable-diffusion.cpp and whisper.cpp, so sd-server and whisper-server may already be on the box. Check with `command -v sd-server whisper-server` or inside the container.

## Minimal working config/command

### llama-swap: what routes

The llama-swap README lists these as routed (the `model` field picks the entry):

- `v1/images/generations` and `v1/images/edits`
- `v1/audio/transcriptions`, `v1/audio/speech` and `v1/audio/voices`
- `/sdapi/v1/txt2img`, `/sdapi/v1/img2img` and `/sdapi/v1/loras`

There are also the `/comfyui/` endpoint and `/upstream/:model_id/` passthrough. Multipart bodies (transcriptions, image edits) carry `model` as a form field; `useModelName` rewrites apply to them too.

### llama-swap: model entry keys you need

| Key                       | Use for media servers                                                                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `cmd`                     | start command; must use `${PORT}` (or set `proxy`)                                                                                                           |
| `proxy`                   | required for Docker: `http://127.0.0.1:${PORT}` with `-p 127.0.0.1:${PORT}:<inner-port>`                                                                     |
| `cmdStop`                 | `docker stop ${MODEL_ID}`. Without it, unloading stops only the `docker run` client and the container keeps the GPU                                          |
| `checkEndpoint`           | readiness path (default `/health`; `none` skips). sd-server: `/v1/models`; whisper-server: `<request-path>/health`; Kokoro/Speaches: `/health`; ComfyUI: `/` |
| `ttl`                     | idle seconds before unload (`0` = never)                                                                                                                     |
| `unloadTimeout`           | grace period on unload; raise to ~30 for Docker                                                                                                              |
| `useModelName`            | rename `model` before forwarding (Kokoro wants `kokoro`; Speaches wants the HF id)                                                                           |
| `unlisted`                | hide from `/v1/models` (ComfyUI)                                                                                                                             |
| `timeouts.responseHeader` | seconds to wait for upstream response headers. Defaults to `0` (no timeout); keep it `0` or large for synchronous image jobs                                 |
| `concurrencyLimit`        | per-model parallel requests (default 10); extra requests get 429                                                                                             |

Macros: `${PORT}`, `${MODEL_ID}`, `${PID}` (only in `cmdStop`), `${env.VAR}`; `startPort` sets the first `${PORT}` (default 5800).

### llama-swap: exclusive vs co-resident

Current configs put groups under `routing.router.settings.groups` (the schema still accepts the legacy top-level `groups:`/`matrix:` keys, but a config must not mix both styles):

| Flag         | Default | Meaning                                                   |
| ------------ | ------- | --------------------------------------------------------- |
| `swap`       | `true`  | members take turns (`true`) or all run together (`false`) |
| `exclusive`  | `true`  | loading a member unloads every other group                |
| `persistent` | `false` | other groups can never unload this group                  |

Patterns:

- **Heavy media in the LLM's exclusive group** (`swap: true, exclusive: true`): FLUX, ComfyUI and video take turns with the big LLM. Use this when memory can't hold both.
- **Speech as a persistent side group** (`persistent: true, swap: false, exclusive: false`): whisper and Kokoro stay loaded and are never evicted by an LLM swap. Use this when the small footprint fits next to your largest model (see `memory-planning.md`).
- **Small LLM plus image together** (`swap: false, exclusive: true`): an assistant model and an image model load as a pair.
- The **matrix** router (`routing.router.use: matrix`) expresses rules like "any LLM plus TTS" or "LLM plus image but no video", with `evict_costs` for slow-loading members. Use it when groups get awkward.

Preload what must be warm: `hooks.on_startup.preload: [whisper, tts]`. Preloading several models needs them in a non-swapping group, or they evict each other.

### ComfyUI under llama-swap

Name the entry exactly `comfyui_auto` and use `http://<llama-swap>/comfyui/`. llama-swap then forces `compat.ignoreWebsockets: true` and `concurrencyLimit` ≥ 999 and ignores UI polling (`/ws`, `/api/jobs`, static assets) so an open tab doesn't pin the model. Set `checkEndpoint: /`. A `POST /api/prompt` (queueing a job) still starts the model. Websocket traffic doesn't reset the TTL, so watching a long render can look idle; use a longer `ttl`. For a second ComfyUI instance, use `/upstream/<id>/`, set `compat.ignoreWebsockets: true` and `concurrencyLimit: 999` yourself, and add `upstream.ignorePaths`. Listing any pattern there replaces the default static-asset pattern, so repeat it.

### LiteLLM entries

Route to llama-swap as an OpenAI-compatible provider: `model: openai/<llama-swap-id>` and `api_base` ending in `/v1`. Set `model_info.mode` so health checks hit the right API:

| Route                      | `model_info.mode`     | Extra                                           |
| -------------------------- | --------------------- | ----------------------------------------------- |
| `/v1/images/generations`   | `image_generation`    | —                                               |
| `/v1/images/edits`         | `image_edit`          | —                                               |
| `/v1/audio/transcriptions` | `audio_transcription` | —                                               |
| `/v1/audio/speech`         | `audio_speech`        | `health_check_voice` required for health checks |

LiteLLM's `GET /health` sends a real request to every model. For image models that means a full generation, possibly a cold swap. Exclude them from background checks with `model_info.disable_background_health_check: true`, or scope checks with `general_settings.background_health_check_model_groups`.

## How it plugs into the stack

### Timeouts end to end

A synchronous image request, or any request that triggers a cold swap, holds one HTTP connection open through every hop. The shortest timeout wins:

| Hop              | Setting                                                                                             | Default                                                                                    | Set it to                                                         |
| ---------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
| Client           | OpenAI SDK timeout                                                                                  | 600 s (Python SDK, per LiteLLM docs)                                                       | above your slowest job                                            |
| Cloudflare proxy | Proxy Read Timeout → **524**                                                                        | **125 s**; Enterprise can raise it up to 6,000 s; Proxy Write Timeout 30 s, not adjustable | can't change on non-Enterprise plans: avoid the hop for long jobs |
| LiteLLM          | `litellm_params.timeout` (per model), `router_settings.timeout`, `litellm_settings.request_timeout` | `request_timeout` 6000 s                                                                   | per-model `timeout` above the slowest job + cold load             |
| llama-swap load  | `healthCheckTimeout`                                                                                | 120 s (min 15; restarts when the server reports progress)                                  | above the slowest cold load (big video/ComfyUI weights)           |
| llama-swap proxy | `timeouts.responseHeader` per model                                                                 | 0 (none)                                                                                   | leave `0` for media                                               |
| Server           | sd-server and ComfyUI have no request timeout flag                                                  | —                                                                                          | —                                                                 |

### Long jobs need a long path

Cloudflare in front of LiteLLM ends any request that doesn't respond within ~125 s with a 524. Typical victims are a high-step FLUX render, a video, a long transcription, and the first request after a swap. Options, best first:

1. **Async + polling.** Submit and return immediately, then poll: sd-server `/sdcpp/v1/img_gen` + `/sdcpp/v1/jobs/{id}`, ComfyUI `POST /prompt` + `/history/{id}`. Each poll is a short request. This is what Cloudflare itself recommends.
2. **Private long path.** Clients on a tailnet or VPN call LiteLLM directly (for example `http://10.0.0.1:4000`), with no Cloudflare read timeout in the way. Keep Cloudflare for short chat traffic.
3. **Preload / keep warm.** `hooks.on_startup.preload`, `ttl: 0`, or a persistent group, so no request pays for a cold swap. This removes swap latency, not generation time.
4. **Shrink the job.** Fewer steps, distilled models (schnell/turbo variants), smaller size.

Streaming doesn't help image endpoints: no bytes are sent until the image is done.

### Same endpoint, same rules

- Every media server binds `127.0.0.1` (`--listen-ip`, `--host`, `--listen`, `-p 127.0.0.1:...`). Only LiteLLM (and maybe llama-swap) are reachable from outside the host.
- Keys:
  - llama-swap `apiKeys` (default-allow when empty; `${env.VAR}` keeps keys out of the file).
  - LiteLLM `master_key` plus virtual keys.
  - Upstream servers mostly have no auth: sd-server, whisper-server, Kokoro-FastAPI and ComfyUI have none; Speaches has `API_KEY`.
- Health checks must not trigger loads. llama-swap's `/health` returns OK without touching models, and `/running` lists loaded ones. Don't point external monitors at a media model's endpoint through llama-swap: that cold-starts it and evicts your LLM.

## Operating

- `curl -s http://127.0.0.1:8080/running` shows what is loaded; `POST /api/models/unload/<id>` frees one model; `POST /api/models/unload` frees all.
- `GET /logs/stream/<model_id>` tails one upstream's output; the upstream log is where sd-server/ComfyUI load errors show up.
- After adding entries, test each hop separately: upstream directly on its port, then llama-swap with `model`, then LiteLLM with a virtual key (see the smoke tests in SKILL.md).

## Tuning knobs worth knowing

- `globalTTL` and per-model `ttl`: unload idle image models so memory goes back to LLMs.
- `routing.scheduler.settings.fifo.priority`: let chat requests jump ahead of queued media requests.
- `globalConcurrencyLimit` / `concurrencyLimit`: one image job at a time is usually right for a single GPU.
- LiteLLM `router_settings` fallbacks: fall back from a local image model to a cloud one when the local one times out (see the `llm-gateway` skill).

## Known pitfalls

- Docker entry without `cmdStop`: the container survives the unload and holds memory; the next swap OOMs.
- Docker `-p ${PORT}:8880` without `127.0.0.1:` publishes an unauthenticated server on all interfaces.
- `checkEndpoint` left at `/health` for sd-server or ComfyUI: neither serves it, so the load times out after `healthCheckTimeout`.
- `api_base` without `/v1` in LiteLLM returns Not Found errors.
- An uptime monitor hitting `/v1/images/generations` (or LiteLLM `/health` with image models included) keeps loading the image model and evicting the LLM.
- A model listed in two groups is a config error: a model can belong to only one group.

## Official links

- llama-swap config reference: https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml
- llama-swap groups and matrix: https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/routing/groups-and-matrix.md
- llama-swap ComfyUI: https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/upstreams/comfyui.md
- llama-swap TTL and unloading: https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/model-runtime/ttl-and-unloading.md
- LiteLLM OpenAI-compatible: https://docs.litellm.ai/docs/providers/openai_compatible
- LiteLLM image generation: https://docs.litellm.ai/docs/image_generation
- LiteLLM timeouts: https://docs.litellm.ai/docs/proxy/timeout
- LiteLLM health and modes: https://docs.litellm.ai/docs/proxy/health
- Cloudflare 524: https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-524/
