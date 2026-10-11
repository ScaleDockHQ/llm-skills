# Open WebUI: troubleshooting

> Verified against Open WebUI v0.12.0 (docs: troubleshooting/connection-error, troubleshooting/*, reference/env-configuration), 2026-10-11

Triage first: `docker logs --tail 100 open-webui`; model list from inside the container (`docker-networking.md`); the same request with `curl` against the endpoint on the host.

| Symptom                                                                 | Cause                                                                         | Fix                                                                                                                           |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `Connect call failed ('127.0.0.1', 8000)` or "Server connection failed" | Endpoint URL uses `localhost`                                                 | Use `host.docker.internal` or a service name; add `host-gateway` mapping on Linux.                                            |
| Works from the host, not the container                                  | Engine bound to `127.0.0.1`, or a firewall blocks the Docker bridge           | Bind `0.0.0.0`/bridge/VPN address with an API key; allow the bridge subnet to that port.                                      |
| Verify Connection fails, chat works                                     | Server has no `/models`                                                       | Add model ids manually in the connection.                                                                                     |
| Verify fails with 401/403                                               | Wrong key, key has a stray newline or quotes, or wrong auth type              | Re-enter key; Auth: Bearer; test `curl -H "Authorization: Bearer ..."` from the host without printing the key in shared logs. |
| Wrong env value ignored                                                 | PersistentConfig: DB copy wins                                                | Change in Admin UI or `ENABLE_PERSISTENT_CONFIG=False` (`persistence-and-updating.md`).                                       |
| Model list empty or very slow                                           | One of several connections is unreachable; model cache                        | Fix or disable it; lower `AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST`; save Connections to refresh the cache.                          |
| 404 on chat                                                             | URL missing or doubling `/v1`                                                 | The connection URL should end at the API root (`.../v1`), not `.../v1/chat/completions`.                                      |
| Infinite spinner or empty reply                                         | Streaming buffered by a proxy; engine error; tool-call deltas without `index` | Disable proxy buffering; read engine logs; see blank-reply note in `models-and-tools.md`.                                     |
| Raw `##`, `**` shown, fixed by non-streaming                            | Proxy buffering                                                               | nginx: `proxy_buffering off`.                                                                                                 |
| Tools never fire or error                                               | Engine lacks tool parser; model not tool-capable; Legacy mode                 | Engine flags (`models-and-tools.md`); use Native.                                                                             |
| 413 or upload failures                                                  | Proxy body size limit                                                         | Raise (`client_max_body_size` on nginx).                                                                                      |
| Login loop or WebSocket errors behind proxy                             | No WebSocket upgrade, or `WEBUI_URL`/CORS mismatch                            | Enable Upgrade/Connection headers; set `WEBUI_URL`, `CORS_ALLOW_ORIGIN`; HTTPS cookies as needed.                             |
| Intermittent "Model not found" with container names                     | Old DNS resolver (c-ares)                                                     | Upgrade; leave `AIOHTTP_CLIENT_ASYNC_DNS_RESOLVER` at default.                                                                |
| Replies lose characters like U+2028                                     | `ENABLE_ORJSON=True` on v0.11.0                                               | Upgrade or disable.                                                                                                           |
| Slow or timed out first token                                           | Swap proxy loading a model                                                    | Raise `AIOHTTP_CLIENT_TIMEOUT`.                                                                                               |
| Everything gone after update                                            | Container recreated without the volume                                        | Restore the backup into the volume.                                                                                           |

## Collect a report safely

```bash
docker logs --tail 200 open-webui 2>&1 | sed 's/Bearer [^ ]*/Bearer <redacted>/g'
curl -fsS http://localhost:3000/api/version | jq .
docker inspect open-webui --format '{{.Config.Image}}'
```

Never paste env files, `docker inspect` env output or the database.

## Official links

- Connection errors: https://docs.openwebui.com/troubleshooting/connection-error
- Troubleshooting index: https://docs.openwebui.com/troubleshooting
- Issues: https://github.com/open-webui/open-webui/issues
