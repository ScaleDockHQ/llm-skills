# Ollama

> Verified against Ollama v0.40.3, 2026-10-11

This page keeps the minimal command and how it plugs into the local stack. Environment variables, tuning and operating live in the product skill.

Depth: install the ollama skill (`npx skills add ScaleDockHQ/llm-skills --skill ollama`).

## Minimal working config

```bash
ollama pull <model>              # e.g. a tag from https://ollama.com/library
ollama run <model> "Say hi"
ollama ps                        # NAME, SIZE, PROCESSOR (100% GPU / CPU split), CONTEXT, UNTIL
```

Custom defaults with a Modelfile (see `assets/Modelfile.example`):

```bash
ollama create my-model -f ./Modelfile
ollama run my-model
```

## How it plugs in

| Item                 | Value                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Default bind         | `127.0.0.1:11434` (`OLLAMA_HOST`)                                                                                                |
| Health               | `GET /` returns `Ollama is running`; `GET /api/version`; `GET /api/ps` lists loaded models                                       |
| OpenAI-compatible    | base URL `http://localhost:11434/v1`: `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/v1/embeddings`, `/v1/responses` |
| Anthropic-compatible | base URL `http://localhost:11434` → `/v1/messages` (`ANTHROPIC_BASE_URL=http://localhost:11434`)                                 |
| Native API           | `/api/chat`, `/api/generate`, `/api/embed`, `/api/tags`, `/api/pull`, ...                                                        |
| Auth                 | **None on the local server.** OpenAI clients need _some_ `api_key` string, and Ollama ignores it                                 |

`ollama launch` can configure and start supported integrations (Claude Code, Codex, OpenCode, VS Code, Droid) against your local Ollama. For client setup in general, see the **llm-clients** skill.

## Known pitfalls

- **Truncated prompts / agents "forgetting":** the default context is only 4k on smaller GPUs. Raise `OLLAMA_CONTEXT_LENGTH`.
- **403 behind a proxy or tunnel while bound to localhost:** Ollama rejects unfamiliar `Host` headers when it listens on loopback (allowed: `localhost`, the machine hostname, `*.local`, `*.localhost`, `*.internal`, private IPs). Set the proxy's Host header to `localhost:11434`, as the FAQ shows for nginx, ngrok, and cloudflared.
- **No API key:** setting `OLLAMA_HOST=0.0.0.0` exposes the server unauthenticated to the whole network. See `sharing-on-lan.md`.
- **Two servers on 11434:** the desktop app and a manual `ollama serve`, or Windows and WSL2. Stop one.
- **Proxy env:** set `HTTPS_PROXY` only. `HTTP_PROXY` can break client connections.

## Official links

- Docs: https://docs.ollama.com
- FAQ: https://docs.ollama.com/faq
- OpenAI compatibility: https://docs.ollama.com/api/openai-compatibility
- Anthropic compatibility: https://docs.ollama.com/api/anthropic-compatibility
- GPU support: https://docs.ollama.com/gpu
- Modelfile: https://docs.ollama.com/modelfile
- Source: https://github.com/ollama/ollama
