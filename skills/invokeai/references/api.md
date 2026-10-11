# InvokeAI: HTTP API

> Verified against InvokeAI v6.14.2 (docs development/Guides/workflow-api and features/Multi-User Mode/api-guide, session_queue.py, app_info.py, auth.py and model_manager.py routers at tag v6.14.2), 2026-10-11

InvokeAI is a FastAPI app. The Swagger UI is at `/docs` and the schema at `/openapi.json`; routers include `/api/v1/app`, `/api/v1/queue`, `/api/v1/images`, `/api/v1/boards`, `/api/v1/workflows`, `/api/v1/auth` and `/api/v2/models`. No OpenAI-compatible `/v1/images/generations` route exists in the router list. For OpenAI-shaped image APIs see `stable-diffusion-cpp`, or write a thin wrapper. Always read the installed version's `/openapi.json`; the UI itself uses these routes and they change between releases.

## Executing work: enqueue a graph

A saved workflow is not executable directly. The queue takes a **graph** (nodes and edges); enqueue it with `POST /api/v1/queue/default/enqueue_batch`. Smallest check, with no model needed:

```bash
S=http://127.0.0.1:9090
id=$(curl -fsS $S/api/v1/queue/default/enqueue_batch -H 'Content-Type: application/json' -d '{
  "batch": {"graph": {"id":"hello","nodes":{"add":{"id":"add","type":"add","a":2,"b":3,"is_intermediate":false,"use_cache":true}},"edges":[]},
  "runs": 1, "origin": "external-client"}}' | jq -r '.item_ids[0]')
until s=$(curl -fsS $S/api/v1/queue/default/i/$id | jq -r .status); [ "$s" = completed ] || [ "$s" = failed ] || [ "$s" = canceled ]; do sleep 1; done
echo "$s"; curl -fsS $S/api/v1/queue/default/i/$id | jq '.session.results'
```

For image graphs the result holds `{"type":"image_output","image":{"image_name":"abc123.png"}}`. Download with `GET /api/v1/images/i/{image_name}/full` (thumbnail: `/thumbnail`). Status values: `completed`, `failed` (read `error_message`), `canceled`. Websocket events give lower-latency progress than polling. To build a real graph, generate it in the UI and copy the graph the browser sends (browser network tab), or export a workflow and convert it; read the invocation schemas in `/openapi.json`. Queue status: `GET /api/v1/queue/default/status`.

## Auth

Single-user mode needs no headers. Multi-user mode: login, then `Authorization: Bearer <token>` on queue, workflow and model calls (`configuration.md`). Keep tokens in environment variables, not scripts.

## Models over the API

`/api/v2/models/` lists and manages models, including install from a source; read the schema before using it. Installs download multi-GB files: get approval, check disk, and never include tokens in the request body you echo.

## Operational notes

- One queue per instance by default (`default`); `max_queue_size` limits it; GPU sessions run serially per GPU.
- A job waiting behind a cold model load can take minutes; use long client timeouts and avoid synchronous HTTP gateways with short limits.
- No built-in rate limiting; put limits at the gateway.
