# ComfyUI: HTTP API and API-format workflows

> Verified against ComfyUI v0.39.0 (server.py and execution.py read at the tag; docs: docs.comfy.org development/comfyui-server/comms_routes and comms_overview; script_examples/basic_api_example.py), 2026-10-11

ComfyUI has **no OpenAI-compatible route**. Clients call its native API, or you wrap it (`integrations.md`). Every route below also answers under an `/api` prefix (`server.py` registers each route twice: `/prompt` and `/api/prompt`).

## Routes used for headless work

| Route                                                 | Purpose                                                                                                                                                                                      |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /`                                               | web UI; returns 200 once the server is up (there is no `/health`)                                                                                                                            |
| `GET /system_stats`                                   | `system` (os, ram, `comfyui_version`, `pytorch_version`, `argv`) and `devices[]` (`name`, `type`, `vram_total`, `vram_free`, `torch_vram_*`)                                                 |
| `POST /prompt`                                        | queue a workflow. Body `{"prompt": <API graph>, "client_id": "...", "prompt_id": "<lowercase UUID, optional>", "number": N, "front": bool, "extra_data": {}}`                                |
| `GET /prompt`                                         | queue status                                                                                                                                                                                 |
| `GET /history/{prompt_id}`                            | `{ "<id>": { "prompt", "outputs", "status": {"status_str": "success"\|"error", "completed", "messages"} } }`; empty object while pending or unknown. `GET /history?max_items=&offset=` lists |
| `GET /view?filename=&subfolder=&type=`                | download an output (`type` is `output`, `input` or `temp`)                                                                                                                                   |
| `GET /queue`, `POST /queue`                           | `queue_running` and `queue_pending`; `POST {"clear": true}` or `{"delete": ["<prompt_id>"]}`                                                                                                 |
| `POST /interrupt`                                     | stop the running job; optional body `{"prompt_id": "..."}` targets one job                                                                                                                   |
| `GET /api/jobs`, `GET /api/jobs/{id}`                 | job list with `status` (`pending,in_progress,completed,failed`), `sort_by`, `sort_order`, `limit`, `offset`                                                                                  |
| `POST /api/jobs/{id}/cancel`, `POST /api/jobs/cancel` | cancel one job (running jobs are interrupted, pending ones removed) or several; unknown or finished ids return `{"cancelled": false}`                                                        |
| `POST /free`                                          | `{"unload_models": true, "free_memory": true}` sets flags that release models and cached memory after the current work                                                                       |
| `POST /upload/image`, `POST /upload/mask`             | multipart: `image` file, optional `type` (default `input`), `subfolder`, `overwrite` (`true` or `1`); returns `{"name","subfolder","type"}`                                                  |
| `GET /object_info`, `GET /object_info/{class}`        | every node type with inputs; use it to check that a custom node loaded                                                                                                                       |
| `GET /models`, `GET /models/{folder}`                 | model types and files the server can see in a folder                                                                                                                                         |
| `GET /embeddings`, `GET /extensions`, `GET /features` | embeddings, web extensions, server capabilities                                                                                                                                              |
| `GET /ws?clientId=<id>`                               | websocket for progress                                                                                                                                                                       |

`POST /prompt` returns `{"prompt_id", "number", "node_errors"}` on success. On validation failure it returns HTTP 400 with `error` (`type`, `message`, `details`) and `node_errors`. A body without `prompt` returns 400 `no_prompt`. A `prompt_id` that is not a canonical lowercase UUID returns 400 `invalid_prompt_id`; omit it and the server generates one.

## API-format workflows

The `prompt` body is a map of node id to `{"class_type", "inputs"}`. Inputs are literal values or `["<source node id>", <output index>]` links. It is **not** the UI save format (`nodes`, `links`, `groups`), and `POST /prompt` rejects that.

- Export from the UI: File, Export (API) (wording from the comfy-cli README). Keep the exported file in git next to your script.
- `comfy run --workflow file.json` can auto-convert UI-format JSON, but it is a comfy-cli feature, not part of the server.
- Template the fields you vary. In the default text-to-image graph shipped as `script_examples/basic_api_example.py`, node `"6"` is the positive prompt (`inputs.text`) and node `"3"` is the sampler (`inputs.seed`). **Node ids differ per workflow**: look up the `class_type` of each node in your own export.

```bash
# Change the prompt and seed without editing the file; ids "6" and "3" are from the example graph
jq -c --arg t "a lighthouse at dusk" --argjson s 42 \
  '.["6"].inputs.text = $t | .["3"].inputs.seed = $s' workflow_api.json > /tmp/job.json
```

## Job lifecycle

1. `POST /prompt` with `{"prompt": <graph>, "client_id": "<your-uuid>"}`. Save `prompt_id`.
2. Wait. Either poll `GET /history/{prompt_id}` until the key exists, or listen on `GET /ws?clientId=<your-uuid>`.
3. Read `.[$id].status.status_str`: `success` or `error`. Outputs are in `.[$id].outputs.<node_id>.images[]` (`filename`, `subfolder`, `type`); video and audio nodes use their own output keys, so list `.outputs[]` generically.
4. Download each file with `GET /view?filename=...&subfolder=...&type=...`.

`scripts/comfy-run.sh` implements this with curl and jq:

```bash
scripts/comfy-run.sh workflow_api.json            # submit, poll, download into ./comfy-out
COMFY_URL=http://127.0.0.1:8188 COMFY_OUT=./out scripts/comfy-run.sh job.json
```

Repeating an identical graph is cheap: ComfyUI re-executes only nodes whose inputs changed (README notes). Change the seed to force new output.

## WebSocket messages (v0.39.0)

Connect with `?clientId=` and pass the same `client_id` in `POST /prompt`. Messages are JSON text frames with `type` and `data`. Seen in `server.py` and `execution.py`: `status` (first frame, includes `sid`), `execution_start`, `execution_cached`, `executing` (`node` id; `node: null` with your `prompt_id` means the whole prompt finished), `progress`, `executed` (node output), `execution_success`, `execution_error`, `execution_interrupted`. docs.comfy.org comms_messages documents the same events.

Behind a proxy, an open websocket is a long-lived connection. In llama-swap that is why the `/comfyui/` endpoint exists (`combos/llama-swap-litellm.md`).

## Authentication and partner nodes

Core ComfyUI does not authenticate requests. Partner nodes (paid cloud models inside a workflow) take a Comfy account API key in the `extra_data` field of the payload (docs.comfy.org development/comfyui-server/api-key-integration); keep that key in an environment variable and build the JSON with `jq --arg`, never paste it into a command line. `--offline` or `--disable-partner-nodes` removes the feature.

## Release memory after a job

```bash
curl -fsS -X POST 127.0.0.1:8188/free -H 'Content-Type: application/json' \
  -d '{"unload_models": true, "free_memory": true}'
```

The flags are applied by the prompt worker, so the memory drops shortly after the call, not before it returns. Check with `GET /system_stats`.

## Gotchas

- `GET /history/{id}` returns `{}` for a job that is queued or running; treat empty as "not done", and check `/queue` before concluding it was lost.
- The history is capped in memory (`MAXIMUM_HISTORY_SIZE` in `execution.py`); fetch results promptly.
- Output filenames come from the `SaveImage` node's `filename_prefix`; set a unique prefix per request if several clients share the server.
- Uploaded images referenced by `LoadImage` nodes must use the returned `name` (and `subfolder`).
