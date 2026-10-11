# LM Studio side

> Verified against LM Studio 0.4.26 (docs: integrations/claude-code, developer/anthropic-compat/messages, system requirements), 2026-10-11

The LM Studio server exposes Anthropic-compatible `POST /v1/messages` (added in 0.4.1) at the server root, alongside OpenAI-compatible and native endpoints. Depth on serving lives in the `lm-studio` skill; the Claude-Code-relevant parts are here.

## Model and context

- Agent tools fill context quickly. Upstream's tip: use a model and settings with more than about 25k tokens of context.
- Preload with the context you want: `lms load <model> --context-length 32768 --gpu max --identifier <id>`; `lms load --estimate-only` shows memory first. JIT loading on first request uses default load settings, often a small context, so preload instead.
- On a Mac prefer an MLX build (`lms get --mlx`) when one exists; budget memory with `apple-silicon`.
- The request's `model` must be a model key or identifier LM Studio knows (`lms ls`, `lms ps`). The `--identifier` you set at load time is the safest name to give Claude Code.
- Streaming returns the standard events (`message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`); tools and `tool_choice` are supported on the endpoint. Tool-call quality depends on the model.

## Server and auth

```bash
lms server start --port 1234          # 127.0.0.1 by default
lms server status --json --quiet
```

Require Authentication (a server setting in the app) makes LM Studio accept both `x-api-key` and `Authorization: Bearer <token>`. Turn it on before changing the bind address or CORS; create the token in the app and store it in a `0600` file.

## Resource hygiene

Run one big model at a time: `lms ps` shows what is resident; Claude Code may also request a second model for background tasks (see `claude-code-side.md`), which competes for the same memory.

## LM Link

LM Link lets a laptop use a model running on another machine while Claude Code keeps talking to `localhost:1234` (LM Studio docs pro tip). Setup belongs to the `lm-studio` skill.

## Official links

- https://lmstudio.ai/docs/integrations/claude-code
- https://lmstudio.ai/docs/developer/anthropic-compat/messages
- https://lmstudio.ai/docs/developer/core/authentication
