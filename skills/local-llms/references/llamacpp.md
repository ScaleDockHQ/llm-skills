# llama.cpp (`llama-server`)

> Verified against llama.cpp b11555 (common/common.h, tools/server/README.md; default port 9931 since b11521, 8080 in v0.6.0 and earlier), 2026-10-11

This page keeps the minimal command and how it plugs into the local stack. Flags, builds and tuning live in the product skill.

Depth: install the llama-cpp skill (`npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`).

## Minimal working config

```bash
# Download from Hugging Face (defaults to Q4_K_M if present) and serve on localhost
llama-server -hf ggml-org/<model>-GGUF:Q4_K_M -c 32768 --host 127.0.0.1 --port 9931

# Local file, explicit GPU layers, API key from a file, stable model name
llama-server -m ~/models/<model>-Q4_K_M.gguf -c 32768 -ngl all \
  --host 127.0.0.1 --port 9931 --api-key-file ~/.config/llama-server/keys -a local-model
```

## How it plugs in

| Item                 | Value                                                                                                                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default bind         | `127.0.0.1:9931` (`--host`, `--port`; env `LLAMA_ARG_HOST`, `LLAMA_ARG_PORT`). **Builds before b11521 (including the v0.6.0 release) use 8080, and the Docker examples pass `--port 8080`** |
| Health               | `GET /health` (also `/v1/health`), public: `503` while loading, `200 {"status":"ok"}` when ready                                                                                            |
| OpenAI-compatible    | `http://localhost:9931/v1`: `/v1/models`, `/v1/chat/completions`, `/v1/completions`, `/v1/responses`, `/v1/embeddings`                                                                      |
| Anthropic-compatible | `/v1/messages`, `/v1/messages/count_tokens`                                                                                                                                                 |
| Other                | `/props`, `/slots`, `/metrics` (with `--metrics`), `/tokenize`, `/infill`, `/reranking`; web UI at `/`                                                                                      |
| Auth                 | `--api-key KEY[,KEY2]` (env `LLAMA_API_KEY`) or `--api-key-file PATH` (one key per line, `#` comments). Clients send `Authorization: Bearer <key>` (Anthropic clients: `x-api-key`)         |
| TLS                  | `--ssl-key-file`, `--ssl-cert-file`                                                                                                                                                         |

Prefer `--api-key-file` to `--api-key`: command lines show up in `ps` output and shell history.

## Known pitfalls

- **Wrong port:** clients configured for `:8080` won't reach a current build on `:9931`. Pass `--port` explicitly and write it down.
- **Tool calls fail or come back as plain text:** the template is missing or broken. Keep `--jinja`, try `--chat-template-file`, and update to a newer build.
- **`--host 0.0.0.0` without `--api-key-file`:** anyone on the network can use it, and the web UI too. Since `/health` is always public, a health check succeeding proves nothing about auth.
- **CUDA zip without cudart:** missing DLLs, or a silent CPU fallback.
- **Out of memory at load:** lower `-c`, use `-ctk q8_0 -ctv q8_0`, or let `--fit on` reduce `-ngl`.
- `--agent` / `--ui-mcp-proxy` enable tools and a CORS proxy. Upstream says not to enable them in untrusted environments.

## Official links

- Server README (all flags and endpoints): https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Install: https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md
- Build: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- Releases: https://github.com/ggml-org/llama.cpp/releases
- Installer: https://llama.app
