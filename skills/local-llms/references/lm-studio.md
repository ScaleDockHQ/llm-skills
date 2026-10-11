# LM Studio

> Verified against LM Studio 0.4.26 (`lms` CLI bundled, llmster headless daemon), 2026-10-11

Depth: install the lm-studio skill (`npx skills add ScaleDockHQ/llms-skills --skill lm-studio`).

## How it plugs into this stack

LM Studio is the GUI-first runtime: search and download GGUF or MLX models, chat, and run a local API server.
Pick it when the user wants a GUI, a memory estimate before loading, MLX and GGUF in one tool on a Mac, or
API-token auth without proxy config. Three parts: the app, `llmster` (headless daemon) and `lms` (CLI).

```bash
lms get <model>                                            # append @q4_k_m for a quant; --mlx / --gguf filter
lms load --estimate-only <model> --context-length 32768    # memory estimate, loads nothing
lms load <model> --context-length 32768 --gpu max --identifier local-model
lms server start                                           # 127.0.0.1:1234 (last-used port)
curl -s http://localhost:1234/v1/models
```

| Item         | Value                                                                                                                       |
| ------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Default bind | `127.0.0.1:1234`; `--port N`, `--bind 0.0.0.0` (or `LMS_SERVER_HOST`) for the LAN                                           |
| Health       | `lms server status`; `GET /v1/models`                                                                                       |
| APIs         | OpenAI `/v1/*` (models, chat/completions, completions, responses, embeddings); Anthropic `/v1/messages`; native `/api/v1/*` |
| Auth         | Off by default; Developer, Server Settings, Require Authentication, Manage Tokens; send `Authorization: Bearer <token>`     |
| CORS         | Off; `lms server start --cors`                                                                                              |

Just-in-time loading lists every downloaded model in `/v1/models` and loads on request; JIT models auto-unload after a TTL (`lms load --ttl <seconds>`).

Pitfalls: `--bind 0.0.0.0` without Require Authentication exposes every model to the network; the port is sticky, so check `lms server status` before pointing clients at 1234; set `--context-length` explicitly (agents need tens of thousands of tokens); on Apple Silicon prefer the MLX build (`lms get --mlx`); "Allow calling servers from mcp.json" lets API clients reach your MCP servers, keep it off.

Install: app from https://lmstudio.ai/download (`lms` ships with it; `npx lmstudio install-cli` if missing), or headless llmster `curl -fsSL https://lmstudio.ai/install.sh | bash` then `lms daemon up`. Logs: `lms log stream`. Unload: `lms unload --all`.

## Official links

- Docs: https://lmstudio.ai/docs
- Headless mode: https://lmstudio.ai/docs/developer/core/headless
- Authentication: https://lmstudio.ai/docs/developer/core/authentication
- Serve on local network: https://lmstudio.ai/docs/developer/core/server/serve-on-network
