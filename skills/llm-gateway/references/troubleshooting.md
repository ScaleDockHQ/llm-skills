# Troubleshooting

> Verified against LiteLLM v1.105.0 (docs: completion/drop_params, proxy/model_discovery, response_api, proxy/health, proxy/reliability, tutorials/opencode_integration, tutorials/claude_responses_api) and Claude Code gateway docs, 2026-10-11

Always reproduce in two steps: call the backend directly, then the same request through the gateway. The difference localizes the fault.

```bash
# Direct to the backend
curl -fsS http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
# Through the gateway (key from env, never printed)
curl -sS -o /tmp/gw.json -w '%{http_code}\n' http://127.0.0.1:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"coder","messages":[{"role":"user","content":"Say ok"}]}'
jq '.error // .choices[0].message' /tmp/gw.json
```

## Symptom -> cause -> fix

| Symptom | Likely cause | Fix |
|---|---|---|
| `400` mentioning an unsupported or unknown parameter (`UnsupportedParamsError`) | Client sends a param the provider or LiteLLM's map does not support | `litellm_settings.drop_params: true`, or per deployment `drop_params: true`; for specific fields `additional_drop_params: ["reasoningSummary"]`; if LiteLLM is wrong about support, `allowed_openai_params` |
| Chat UI (for example LobeHub) shows odd model dates or no context size for gateway models | `/v1/models` is OpenAI-shaped: `created` is a fixed placeholder timestamp and `owned_by` is generic; context and capability fields from `model_info` are not included | Declare context and capabilities in the client (LobeHub model settings or `OPENAI_MODEL_LIST` with `<maxTokens:fc:vision>`), see the `llm-clients` skill; use `/v1/model/info` for tooling that can read it |
| Client lists models but treats them as text-only or without tools | Client capability detection uses its own model DB, not `model_info` | Set capabilities on the client side (OpenCode `modalities`/`tool_call`, Continue `capabilities`, Cline model configuration) |
| Responses client works once, then truncated or corrupted responses and connection resets | Backend lacks `/v1/responses`; calls hit an unsupported route and left reused keep-alive connections in a bad state | `use_chat_completions_api: true` on the deployment (or `openai/chat_completions/<id>`); see `api-bridging.md` |
| `404 Not Found` from an `openai/` backend | `api_base` missing `/v1`, or wrong served model ID | Add `/v1`; match `model` to the backend's `/v1/models` IDs |
| `Connection refused` to `127.0.0.1:8080` from LiteLLM in Docker | `127.0.0.1` is the container | Use `host.docker.internal` (with `extra_hosts: host-gateway`) or the host address |
| `401` with a virtual key | Key expired, blocked, out of budget, or model not in key's `models` | `GET /key/info` with that key (filter with `jq '.info'`); adjust limits or scope |
| `No connected db.` | Virtual key used without `DATABASE_URL` | Add Postgres; check `/health/readiness` shows `"db": "connected"` |
| Budgets never trigger | No DB, or local models without explicit zero cost | Connect DB; set `input_cost_per_token: 0` and `output_cost_per_token: 0` on local deployments |
| Every request fails fast for ~30 s after a few errors | Deployment in cooldown | Fix root cause; add replicas, tune `allowed_fails`/`cooldown_time`, or `disable_cooldowns: true` for single deployments |
| First request after idle times out, later ones fine | On-demand model load (llama-swap) exceeds timeout | Raise `timeout`/`stream_timeout` on that deployment; warm the model |
| `ContextWindowExceededError` | Prompt above backend limit | `model_info.max_input_tokens` + `enable_pre_call_checks: true`, and `context_window_fallbacks` to a larger model |
| Claude Code: `Unexpected value(s)` for `anthropic-beta`, or `Extra inputs are not permitted` | Non-Anthropic upstream rejects beta headers/fields | Client: `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`; gateway: `additional_drop_params` for the offending field |
| Claude Code `/model` picker missing gateway models | Discovery off, or alias lacks `claude`/`anthropic` in its name, or `/v1/models` redirects or is slow | `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`; rename alias; serve `/v1/models` directly at the base URL |
| Streams stall then error, non-streaming fine | Reverse proxy buffering SSE or short read timeout | Disable buffering, raise read timeout, keep ping events flowing |
| Config change has no effect | Container not restarted, or the same key was saved via UI and the DB value wins | `docker compose restart litellm`; check UI-saved settings |
| Stored provider credentials suddenly unreadable | `LITELLM_SALT_KEY` changed | Restore the original salt key from the secret store |
| `/health` shows a model unhealthy but chat works | Probe uses the wrong mode or too few tokens (reasoning models) | Set `model_info.mode`; raise `health_check_max_tokens` |

## Collecting evidence without leaking secrets

```bash
docker compose logs --since 15m litellm | grep -Ei 'error|exception|status_code' | tail -50
docker inspect <litellm-container> --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
curl -fsS http://127.0.0.1:4000/v1/model/info -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '.data[] | {model_name, model: .litellm_params.model, api_base: .litellm_params.api_base, max_input_tokens: .model_info.max_input_tokens}'
```

`/v1/model/info` masks API keys, but filter it with `jq` anyway before sharing output.

## Official links

- Drop params: https://docs.litellm.ai/docs/completion/drop_params
- Model discovery (`/v1/models` shape): https://docs.litellm.ai/docs/proxy/model_discovery
- Responses bridge: https://docs.litellm.ai/docs/response_api
- Reliability and cooldowns: https://docs.litellm.ai/docs/proxy/reliability
- Debugging: https://docs.litellm.ai/docs/proxy/debugging
- Claude Code gateway troubleshooting: https://code.claude.com/docs/en/llm-gateway-connect
