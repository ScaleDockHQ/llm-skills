# Operating the stack: health, backup, update, removal

> Verified against Open WebUI v0.12.0 (docs: quick-start Docker updating, troubleshooting/connection-error), Ollama v0.40.3 and Tailscale v1.104.1 CLI, 2026-10-11

## Health

```bash
curl -fsS http://127.0.0.1:11434/api/version | jq .            # Ollama
curl -fsS http://127.0.0.1:8080/health                          # Open WebUI
tailscale serve status                                         # mapping present
docker logs --since 30m open-webui | tail -50                   # app errors
ss -ltn | grep -E ':(8080|11434)\b'                             # both on 127.0.0.1
```

## Backup

All chats, users and settings live in the `open-webui` volume (`/app/backend/data`). Copy it while the container is stopped:

```bash
docker stop open-webui
docker run --rm -v open-webui:/data -v "$PWD":/backup alpine tar czf /backup/open-webui-data.tgz -C /data .
docker start open-webui
```

Treat the archive as sensitive (chat history, hashed passwords). Keep it `0600` and off shared storage.

## Update

The docs' manual update: remove the container, pull, run again with the same volume and `WEBUI_SECRET_KEY`. For this stack:

```bash
docker rm -f open-webui
docker pull ghcr.io/open-webui/open-webui:v<NEW>
# re-run the docker run command from open-webui-ollama.md with the new tag
```

Back up first. Rollback is the same command with the previous pinned tag and the backed-up volume if a migration ran. Read the release notes (`https://github.com/open-webui/open-webui/releases`) before major minor bumps; the project is in 0.x and ships often. Update Ollama through the `ollama` skill and Tailscale through the `tailscale` skill.

## Remove

```bash
sudo tailscale serve --https=443 off    # this listener only; `serve reset` clears all
docker rm -f open-webui
docker volume rm open-webui             # deletes chats and users: back up first
```

Leave Ollama and its models unless you also want them gone (`ollama` skill).

## Troubleshooting by symptom

| Symptom                                        | Check                                                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Model list empty, "connection error" to Ollama | `OLLAMA_BASE_URL` wrong for the network mode; docs: Ollama only on 127.0.0.1 is unreachable from a bridge container; use host networking  |
| Everyone logged out after an update            | `WEBUI_SECRET_KEY` was not fixed                                                                                                          |
| Env change ignored                             | Persistent config: the Admin Panel value wins after first run; change it there or set `ENABLE_PERSISTENT_CONFIG=false` (see docs warning) |
| Garbled markdown, text missing mid-reply       | Proxy buffering (nginx) or, on v0.11.0, `ENABLE_ORJSON=True`; docs say upgrade or unset                                                   |
| Chat loads but never streams, WebSocket errors | Proxy not passing WebSockets; test direct on 127.0.0.1:8080, check CORS origin (`CORS_ALLOW_ORIGIN`)                                      |
| Serve URL 502                                  | Open WebUI not up on 8080 (`docker logs`), or listening on another port                                                                   |
| Serve URL unreachable on the phone             | Tailscale not running on the phone, grant missing, MagicDNS or HTTPS off (`tailscale` skill, `troubleshooting.md`)                        |
| First reply slow after idle                    | Ollama reloads the model after `OLLAMA_KEEP_ALIVE` (`ollama` skill)                                                                       |
