# LobeHub: troubleshooting

> Verified against LobeHub v2.2.19 (docs: environment-variables/model-provider, model-list, docker-compose FAQ), 2026-10-11

Start: `docker compose ps`, `docker logs --tail 100 lobehub`, and the endpoint tested from the host with `curl`.

| Symptom                                              | Cause                                                               | Fix                                                                                |
| ---------------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Empty reply from a proxy or gateway                  | `/v1` suffix wrong in `OPENAI_PROXY_URL`                            | Add or remove `/v1`; test with a real chat.                                        |
| Check fails or connection refused                    | `localhost` used, or engine bound to loopback                       | `host.docker.internal` or service name; engine `--host 0.0.0.0` with auth.         |
| Env change ignored                                   | Container not recreated                                             | `docker compose up -d lobe` after editing `.env`.                                  |
| Model missing in selector                            | `-all` hides it, syntax error, provider disabled                    | Add `+id`; balance `<`/`>`; `ENABLED_OPENAI=1`.                                    |
| Tools not called                                     | No `fc` flag, or engine lacks tool parser                           | Add `fc`; engine flags (see `vllm`, `llama-cpp`).                                  |
| Vision images fail, text works                       | SSRF guard blocking private IP, or non-vision model                 | `SSRF_ALLOW_IP_ADDRESS_LIST`; check model.                                         |
| `lobe-gateway` restarting, `ACTION REQUIRED` in logs | Gateway variables missing after upgrade                             | `updating-and-backup.md`.                                                          |
| Saved keys stop working                              | `KEY_VAULTS_SECRET` changed                                         | Restore the old value.                                                             |
| Login or auth errors                                 | Missing `AUTH_SECRET` or `JWKS_KEY`; wrong `APP_URL`; proxy headers | Set both secrets; `APP_URL` equals the browser URL; forward Host and proto.        |
| Migration errors on start                            | Non-empty or incompatible database                                  | Use a fresh database for the stack or restore a backup (`docker logs -f lobehub`). |
| Slow or timed out Anthropic-route calls              | SDK timeout                                                         | `ANTHROPIC_CLIENT_TIMEOUT` (ms).                                                   |
| Uploads fail                                         | `S3_ENDPOINT` not reachable by the browser                          | Fix the public endpoint and CORS on the bucket.                                    |
| Fetched models show odd dates or flags               | Gateways return placeholder metadata                                | Declare models in `*_MODEL_LIST`.                                                  |

## Safe report

```bash
docker compose ps
docker logs --tail 200 lobehub 2>&1 | sed 's/Bearer [^ ]*/Bearer <redacted>/g'
docker inspect lobehub --format '{{.Config.Image}}'
```

Never paste `.env`, env dumps with values, or database dumps.

## Official links

- Docker Compose FAQ: https://lobehub.com/docs/self-hosting/server-database/docker-compose
- Issues: https://github.com/lobehub/lobehub/issues
