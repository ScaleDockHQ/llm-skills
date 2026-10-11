# goose: custom OpenAI-compatible, Anthropic-compatible and Ollama endpoints

> Verified against goose v1.54.0 (docs: getting-started/providers, guides/environment-variables; source: goose-providers declarative.rs and definitions), 2026-10-11

## Option 1: built-in OpenAI provider with a custom host

Works for vLLM, llama.cpp, LiteLLM, llama-swap, LM Studio and any server that serves `/v1/chat/completions`. Desktop: Settings, Models, Configure providers, OpenAI. CLI: `goose configure`, Configure Providers, OpenAI. Or environment:

| Variable                                | Meaning                                                                                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `OPENAI_API_KEY`                        | Key (required by the provider even if the server ignores it; use any placeholder for unauthenticated local servers, stored via keyring or env) |
| `OPENAI_HOST`                           | Endpoint root, for example `http://gpu-box:8000` (no trailing path), default `api.openai.com`                                                  |
| `OPENAI_BASE_PATH`                      | Path appended to the host, default `v1/chat/completions`; `chat/completions` if the proxy is mounted without `v1`                              |
| `OPENAI_CUSTOM_HEADERS`                 | `HEADER_A=VALUE_A,HEADER_B=VALUE_B`, from env, config or CLI                                                                                   |
| `OPENAI_ORGANIZATION`, `OPENAI_PROJECT` | Optional governance headers                                                                                                                    |
| `OPENAI_STORE`                          | Persist Responses API responses upstream; default `false`                                                                                      |

```bash
export GOOSE_PROVIDER=openai GOOSE_MODEL=coder
export OPENAI_HOST=http://gpu-box:8000          # vLLM default port; root only
export OPENAI_API_KEY="$(cat ~/.config/llm/gateway.key)"   # 0600 file; never echo
goose session
```

A `404` almost always means `OPENAI_BASE_PATH` is wrong for the proxy. A `401` with "No api key passed in" means the key is not being loaded (for example it sits in `config.yaml`).

## Option 2: custom provider JSON

Use when you have several endpoints, want per-model context, headers, a friendly name or a refreshable credential. One JSON file per provider in `~/.config/goose/custom_providers/` (Windows `%APPDATA%\Block\goose\config\custom_providers\`), or create it in Desktop (Configure providers, Add Custom Provider) or `goose configure` (Custom Providers, Add A Custom Provider).

```json
{
  "name": "custom_selfhosted",
  "engine": "openai",
  "display_name": "Self-hosted gateway",
  "api_key_env": "CUSTOM_SELFHOSTED_API_KEY",
  "base_url": "http://localhost:4000/v1/chat/completions",
  "models": [{ "name": "coder", "context_limit": 131072 }],
  "headers": { "X-Team": "platform" },
  "supports_streaming": true,
  "requires_auth": true
}
```

Fields seen in the docs and source:

- `engine`: `openai`, `anthropic` or `ollama` (the aliases `openai_compatible`, `anthropic_compatible`, `ollama_compatible` also parse).
- `base_url`: for the `openai` engine the examples use the full chat completions URL (`.../v1/chat/completions`). For `anthropic` give the root; goose requests `v1/messages` under it. For `ollama` give the root (`http://host:11434`).
- `api_key_env`: name of the environment variable holding the key; the key itself is stored in the keyring (or `secrets.yaml`) when you create the provider in Desktop or `goose configure`. Start a session with `export <NAME>=...; goose session start --provider <name>` for env-only use.
- `requires_auth: false` for unauthenticated local servers (Desktop: untick "This provider requires an API key").
- `models`: `name` and `context_limit` (tokens). Optional per-model fields in the source include cost and `supports_cache_control`.
- `dynamic_models`: `true` (or unset) fetches `/v1/models` and falls back to the static list on 404; `false` uses only the static list (then `models` must be non-empty).
- `supports_streaming`, `timeout_seconds`, `headers`, `toolshim` (see `models-and-tools.md`), `env_vars` and `${VAR}` expansion in `base_url` (used by the built-in definitions).
- `headers` can be edited only in the file for Desktop-created providers and for Anthropic or Ollama providers created in the CLI.
- Changes apply to the next session.

## Command-based credentials

Replace `api_key_env` with an `auth` object to fetch short-lived tokens (they are mutually exclusive):

```json
"auth": { "command": "/usr/local/bin/get-llm-token", "args": [], "refresh_interval": 3600, "timeout_seconds": 10 }
```

The command is run directly (no shell), its trimmed stdout is the credential, it must exit 0 with non-empty output, and it inherits goose's environment. Use `/bin/bash -c` explicitly if you need shell features. `refresh_interval` 0 means refresh only after an auth error.

## Anthropic Messages endpoint

Use a custom provider with `engine: anthropic` and `base_url` set to the gateway root (`assets/custom_provider.anthropic.json`). The built-in `ANTHROPIC_HOST` variable also overrides the Anthropic provider's host (default `https://api.anthropic.com`). Prefer this shape for gateways that map Claude-style thinking and caching; otherwise the OpenAI shape has wider support in local engines.

## Ollama

Built-in Ollama provider: `OLLAMA_HOST` (default `localhost:11434`; `http://` is prepended if no scheme). Local models appear automatically in Desktop. For a remote Ollama host set `OLLAMA_HOST=http://host:11434`. Ollama's default context is small; see `models-and-tools.md` for `GOOSE_INPUT_LIMIT` and the server-side `OLLAMA_CONTEXT_LENGTH`.

## Built-in providers for common local servers

The source ships declarative providers for LM Studio (`LMSTUDIO_HOST`, default `http://localhost:1234`) and llama-swap (`LLAMA_SWAP_HOST`, default `http://localhost:8080`), both OpenAI engine with dynamic model lists and no auth required by default. goose also has a dedicated LiteLLM provider (`LITELLM_HOST`, `LITELLM_BASE_PATH`, `LITELLM_API_KEY`); pick either it or the OpenAI provider for a LiteLLM proxy, never both. See `combos/engines-and-gateways.md`.

## Remove or update

Desktop: Configure providers, select the custom provider, Update Provider or Delete Provider (deletes the stored key). CLI: `goose configure`, Custom Providers, Remove Custom Provider. Deleting only the JSON file leaves a keyring entry behind.

## Official links

- Providers: https://goose-docs.ai/docs/getting-started/providers
- Environment variables: https://goose-docs.ai/docs/guides/environment-variables
- Configuration files: https://goose-docs.ai/docs/guides/config-files
