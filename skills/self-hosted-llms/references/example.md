# Worked example: 2x DGX Spark, 4 models, one endpoint

> Verified against llama-swap v263, LiteLLM v1.105.0, vLLM v0.31.0, llama.cpp v0.6.0, stable-diffusion.cpp master-956-1b0ba10, Caddy v2.11.7, cloudflared 2026.10.0, 2026-10-11

An anonymized deployment that uses every template in this skill. Names, addresses and hosts are
placeholders; adapt sizes to your own memory plan.

## Layout

| Item         | Value                                                                                 |
| ------------ | ------------------------------------------------------------------------------------- |
| Nodes        | node-a (head, all services), node-b (worker only)                                     |
| Link         | ConnectX-7 direct cable, node-a 10.0.0.1, node-b 10.0.0.2                             |
| Service user | `llm` on both nodes, same UID, member of `docker`, passwordless SSH node-a -> node-b  |
| Public host  | `llm.example.com` (Cloudflare Tunnel); dashboards on `dash.example.com` behind Access |
| Private path | `node-a.<tailnet>.ts.net` via Tailscale Serve, for long image jobs                    |

| Public name                                 | llama-swap ID | Engine                  | Nodes           | Group   |
| ------------------------------------------- | ------------- | ----------------------- | --------------- | ------- |
| `qwen-coder`, `coder`, `qwen-coder-nothink` | `qwen-coder`  | vLLM, tensor parallel 2 | node-a + node-b | `large` |
| `gpt-oss`, `reasoning`, `gpt-oss-high`      | `gpt-oss`     | vLLM                    | node-a          | `large` |
| `small-gguf`                                | `small-gguf`  | llama.cpp               | node-a          | `side`  |
| `image-sd`                                  | `image-sd`    | sd-server               | node-a          | `side`  |

One large model at a time (they swap); the two side models stay loaded next to whichever large model
runs, because the memory plan shows they fit together at peak.

## Files on node-a

```text
/opt/llm-stack/start-model.sh          assets/start-model.sh
/opt/llm-stack/common.sh               assets/common.sh
/opt/llm-stack/models.d/qwen-coder.sh  assets/models.d/example-vllm.sh (with worker_run)
/opt/llm-stack/models.d/gpt-oss.sh     same pattern, model_run only
/opt/llm-stack/build-catalog.sh        assets/build-catalog.sh
/opt/llm-stack/catalog.json            assets/catalog.example.json, edited
/etc/llm-stack/llama-swap.yaml         assets/llama-swap.yaml
/etc/llm-stack/litellm-config.yaml     assets/litellm-config.yaml
/etc/llm-stack/litellm.env             LITELLM_MASTER_KEY=... (root, mode 600)
/etc/llm-stack/Caddyfile               assets/Caddyfile
/etc/cloudflared/config.yml            assets/cloudflared-config.yml
/etc/systemd/system/*.service          assets/systemd/
/etc/default/earlyoom                  -m <pct> -s 100 --prefer ... --avoid ...
```

node-b has `/opt/llm-stack` (same files, for consistency), the same HF cache contents, the same
engine image IDs, earlyoom, Docker and the NVIDIA Container Toolkit. No llama-swap, LiteLLM,
Caddy or cloudflared runs there.

## Request walk-through

1. Cursor calls `POST https://llm.example.com/v1/chat/completions` with `model: coder` and a
   virtual key.
2. cloudflared matches the second ingress rule and forwards to LiteLLM on 127.0.0.1:4000.
3. LiteLLM checks the key, resolves `coder` -> `qwen-coder` (`model_group_alias`), calls
   `http://127.0.0.1:8080/v1/chat/completions` with `model: qwen-coder`.
4. llama-swap sees `gpt-oss` loaded in the `large` group: runs its `cmdStop`
   (`start-model.sh stop gpt-oss`), then `start-model.sh run qwen-coder 5800`.
5. The wrapper checks image IDs on both nodes, starts `qwen-coder-worker` on node-b over SSH,
   waits until it runs, starts the head on node-a bound to 127.0.0.1:5800, and follows its logs.
6. llama-swap polls `/health`, streams loading progress to the client meanwhile, then proxies the
   request. `small-gguf` and `image-sd` are untouched.
7. The client's model list came from `GET /v1/models`, which cloudflared sent to Caddy; Caddy
   checked the key against LiteLLM and returned the enriched `models.json`.

## Day-two operations in this deployment

| Task                          | How                                                                           |
| ----------------------------- | ----------------------------------------------------------------------------- |
| What is loaded                | `curl -s 127.0.0.1:8080/running \| jq .`                                      |
| Free memory for a manual test | `curl -X POST 127.0.0.1:8080/api/models/unload`                               |
| Add a model                   | `adding-a-server.md` steps, then rebuild the catalog                          |
| Update vLLM                   | `updating.md`: pull on both nodes, compare IDs, baseline before and after     |
| Long image job                | call `image-sd` via the tailnet hostname, not the public one                  |
| Health in sparkDash           | probes on 127.0.0.1:8080, dashboard behind Access (`monitoring-sparkdash.md`) |

## What went wrong on the way (and is now in the templates)

- earlyoom never fired on a large swap file: `-s 100`.
- A capped `hf download` died from hf-xet memory use: larger cap, no high-performance mode.
- node-b served weights through dangling links after a single-repo rsync: sync all of `hub/`.
- The worker on node-b ran an older image under the same tag: `check_image_ids`.
- A `nohup` tunnel died and every client saw 530: cloudflared is a systemd unit.
- LobeHub sorted and sized models wrongly from LiteLLM's list: enriched catalog.
- `/v1/responses` without a backend route broke later requests: `use_chat_completions_api`.
- A `pgrep -f` wait loop waited on itself: waits use container state.

Each of these has a row in `troubleshooting.md`.
