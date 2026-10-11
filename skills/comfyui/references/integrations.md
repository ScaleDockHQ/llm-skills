# ComfyUI: integrations

> Verified against ComfyUI v0.39.0 (server.py), llama-swap v263 (docs/kb/guides/upstreams/comfyui.md), LiteLLM v1.105.0 docs, Caddy docs (reverse_proxy) and nginx docs (websocket), 2026-10-11

## What clients can and cannot do

- ComfyUI exposes its own HTTP and websocket API (`api.md`). It has **no `/v1/images/generations`** and no auth.
- LiteLLM v1.105.0: the docs site has no `providers/comfyui` page (404 on 2026-10-11) and the `litellm/llms` directory has no ComfyUI provider. LiteLLM's `image_generation` mode expects an OpenAI-shaped upstream, so a ComfyUI server cannot be listed there directly. Either write a wrapper or use an OpenAI-shaped image server (sd-server, see the `self-hosted-genmedia` skill) for that route.
- Native API clients (scripts, `comfy` CLI, apps using the workflow JSON) talk to ComfyUI directly or through a proxy that passes websockets.

## Authentication gap

No API-key or user auth exists in core at v0.39.0 (`--multi-user` is storage separation only). Options, strongest first:

1. Keep ComfyUI on `127.0.0.1` and reach it through SSH or a tailnet.
2. Put a reverse proxy with auth (basic, forward auth, mTLS) in front, bound to the proxy's interface.
3. llama-swap `apiKeys` in front of it (`combos/llama-swap-litellm.md`).

Whatever you choose, note the origin check: browsers loading the UI through a proxy under a different hostname may get 403 (`troubleshooting.md`).

## Reverse proxy

- **Caddy**: `reverse_proxy 127.0.0.1:8188` proxies websockets without extra configuration. Caddy closes websockets when its config reloads unless `stream_close_delay` is set (Caddy docs).
- **nginx**: add `proxy_set_header Upgrade $http_upgrade;` and `proxy_set_header Connection "upgrade";` (before nginx 1.29.7 also `proxy_http_version 1.1;`), as the nginx websocket page shows. nginx closes a proxied connection that sends no data for 60 seconds unless you raise `proxy_read_timeout` or the upstream sends pings.
- Long synchronous calls are not needed: `POST /prompt` returns at once, so use polling to stay under any proxy read limit (Cloudflare's 524 is the usual one; see `self-hosted-genmedia`).
- Behind a proxy keep the upstream bound to loopback, and make the proxy preserve `Host`.

## Outline of an OpenAI-shaped wrapper

Only if clients insist on `/v1/images/generations`. A wrapper does:

1. accept the OpenAI body (`prompt`, `size`, `n`, `model`);
2. load a stored **API-format** workflow and set the prompt text, seed and size in the nodes you identified by `class_type` (not by hard-coded id);
3. `POST /prompt` with a `client_id`, then poll `GET /history/{id}` or listen on `/ws`;
4. fetch each file from `GET /view` and answer `{"created": <unix>, "data": [{"b64_json": "<base64>"}]}`;
5. bind to loopback, use a request timeout above your slowest job, and map ComfyUI's `node_errors` to an HTTP 4xx with the message.

Write it in the language your team maintains. No example wrapper ships with this skill because none was verified against a live server.

## Other integrations

- **llama-swap**: dedicated `/comfyui/` endpoint with the reserved model id `comfyui_auto` (`combos/llama-swap-litellm.md`).
- **comfy-cli**: `comfy run --workflow wf.json` runs against a local server; `COMFY_LOCAL_URL` points it elsewhere. `comfy jobs`, `comfy download` and `comfy nodes` are also available (README). Cloud routing flags spend credits, so avoid them unless the user asks.
- **Partner nodes** (paid hosted models inside a workflow): need a Comfy account API key in `extra_data` (docs.comfy.org). `--offline` or `--disable-partner-nodes` blocks them.
- **Observability**: ComfyUI has no metrics endpoint in the sources read. Watch `GET /queue`, `GET /system_stats`, `GET /api/jobs?status=failed` and the process log (`--verbose`).
