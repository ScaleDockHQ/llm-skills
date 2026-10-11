# Jan: Local API Server

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop/api-server, api-preference, v0.8.5 changelog.

Enable under Settings -> Local API Server -> Start Server. The log shows `JAN API listening at http://127.0.0.1:1337` when ready. Powered by llama.cpp; since v0.7.7 it serves local and remote models.

## Settings

| Setting                            | Default     | Notes                                                                                   |
| ---------------------------------- | ----------- | --------------------------------------------------------------------------------------- |
| Server Host                        | `127.0.0.1` | `0.0.0.0` exposes it to the LAN                                                         |
| Server Port                        | 1337        | No automatic fallback if taken                                                          |
| API Prefix                         | `/v1`       | Can be changed or empty                                                                 |
| API Key                            | empty       | If set, clients send `Authorization: Bearer <key>`; empty disables auth                 |
| Trusted Hosts                      | none        | Comma-separated hostnames; with a `0.0.0.0` bind, other `Host` values get 403 (v0.8.5+) |
| Request Timeout                    | seconds     | Raise for big models on slow hardware                                                   |
| Execute Tools on Server            | off         | Run MCP tool calls server-side for `/v1/chat/completions`                               |
| CORS                               | on          | Turn off for non-browser clients                                                        |
| Verbose Server Logs                | on          | Detail in the Server Logs view                                                          |
| Run in background (Windows, Linux) | on          | Off = closing the window quits Jan and the server (v0.8.5+)                             |

## Endpoints

- `GET /v1/models`
- `POST /v1/chat/completions`: OpenAI format, streaming, tool calling.
- `POST /v1/messages`: Anthropic Messages format (header `x-api-key`).

```bash
H="Authorization: Bearer $JAN_API_KEY"
curl -fsS http://127.0.0.1:1337/v1/models -H "$H" | jq -r '.data[].id'
curl -N http://127.0.0.1:1337/v1/chat/completions -H "$H" -H 'Content-Type: application/json' \
  -d '{"model":"<id>","messages":[{"role":"user","content":"hi"}],"stream":true}'
curl -fsS http://127.0.0.1:1337/v1/messages -H "x-api-key: $JAN_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"<id>","max_tokens":64,"messages":[{"role":"user","content":"hi"}]}' | jq .
```

OpenAI SDKs: `base_url="http://127.0.0.1:1337/v1"`, `api_key=<key or placeholder>`.

## Reaching it from elsewhere

Containers: bind to `0.0.0.0` and use `host.docker.internal` (allowed by default). LAN or remote: set key and Trusted Hosts, then prefer `tailscale`, or a proxy such as `caddy` with TLS, over opening the port. Jan itself has no TLS.
