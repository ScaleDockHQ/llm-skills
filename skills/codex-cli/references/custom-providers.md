# Codex CLI: custom model providers

> Verified against Codex CLI rust-v0.162.1 (docs: config-advanced, config-reference; repo README), 2026-10-11

Codex sends OpenAI Responses requests (`POST {base_url}/responses`, streamed) to the provider selected by `model_provider`. The config lives in `$CODEX_HOME/config.toml` (default `~/.codex/config.toml`).

## Provider table

```toml
model = "qwen3-coder"              # name the endpoint serves
model_provider = "local"
model_context_window = 131072      # real window of the served model

[model_providers.local]
name = "Local engine"
base_url = "http://HOST:PORT/v1"   # Codex appends /responses
env_key = "LOCAL_LLM_API_KEY"      # NAME of the env var holding the key
wire_api = "responses"             # the only supported value, also the default
```

| Key                                                     | Meaning                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `base_url`                                              | API root including `/v1`. Codex adds `/responses`.                                                                                                                                                                                                                                                                              |
| `env_key`                                               | Env var supplying the key, sent as a bearer token. Omit entirely for keyless local engines.                                                                                                                                                                                                                                     |
| `env_key_instructions`                                  | Text shown when the variable is missing.                                                                                                                                                                                                                                                                                        |
| `[model_providers.<id>.auth]`                           | `command`, `args`, `cwd`, `timeout_ms` (default 5000), `refresh_interval_ms` (default 300000; 0 = refresh only after an auth retry). Command prints the token to stdout; stdin is empty; whitespace is trimmed; empty output is an error. Do not combine with `env_key`, `experimental_bearer_token` or `requires_openai_auth`. |
| `experimental_bearer_token`                             | Key inline in the file. Discouraged: it puts a secret in config.                                                                                                                                                                                                                                                                |
| `http_headers` / `env_http_headers`                     | Static headers, or headers whose values come from env vars (use this for secrets such as a tenant token).                                                                                                                                                                                                                       |
| `query_params`                                          | Extra query string on every request (Azure `api-version`).                                                                                                                                                                                                                                                                      |
| `request_max_retries`                                   | HTTP retries, default 4.                                                                                                                                                                                                                                                                                                        |
| `stream_max_retries`, `stream_idle_timeout_ms`          | SSE reconnects (default 5) and idle timeout (default 300000 ms). Raise the timeout for cold model loads.                                                                                                                                                                                                                        |
| `requires_openai_auth`                                  | Provider uses OpenAI auth (default false). Leave unset for your own endpoints.                                                                                                                                                                                                                                                  |
| `supports_websockets`, `supports_standalone_web_search` | Capability advertisements, default off. Leave off for local engines.                                                                                                                                                                                                                                                            |

Built-in provider IDs `openai`, `ollama` and `lmstudio` are reserved and cannot be redefined. `openai_base_url` repoints the built-in OpenAI provider. `amazon-bedrock` is a separate built-in with its own `aws.profile` and `aws.region`.

## Key handling without printing it

```bash
mkdir -p ~/.config/llm && (umask 077 && ${EDITOR:-vi} ~/.config/llm/key)   # paste the key; file is created 0600
export LOCAL_LLM_API_KEY="$(cat ~/.config/llm/key)"     # in the shell profile or launcher
[ -n "${LOCAL_LLM_API_KEY:-}" ] && echo "key present"    # check by name, never echo the value
```

Or a command-backed token, for example a keychain item on macOS:

```toml
[model_providers.local.auth]
command = "security"
args = ["find-generic-password", "-s", "local-llm", "-w"]
refresh_interval_ms = 3600000
```

GUI launchers do not read shell profiles; export where the app starts or use the auth command.

## Project config cannot redirect credentials

Codex loads project `.codex/config.toml` only for trusted projects, and it ignores (with a startup warning) `openai_base_url`, `chatgpt_base_url`, `model_provider`, `model_providers`, `notify`, `profile`, `profiles` and `otel` there. Put providers in the user file. For per-project behavior use profiles.

## Profiles

`codex --profile local` loads `~/.codex/config.toml`, then overlays `~/.codex/local.config.toml` (top-level keys, not nested under `[profiles.local]`). Names may contain letters, numbers, hyphens and underscores. A profile file may override `model_catalog_json`. Keep a cloud default in `config.toml` and the self-hosted setup in a profile, so a missing endpoint never breaks normal use. One-off overrides: `codex --config model='"qwen3-coder"'` (values are TOML; quote them).

## `--oss` for Ollama and LM Studio

`codex --oss` uses a built-in local provider: `--local-provider ollama|lmstudio` for one run, or `oss_provider = "ollama"` as default. With neither set, the interactive CLI prompts and `codex exec` exits with an error. Use a custom provider instead for vLLM, llama.cpp, llama-swap, LiteLLM, remote hosts or a non-default port. Known issue at write time: connecting Ollama through the desktop app has written a top-level `model_provider` and `model_catalog_json` that hid OpenAI models (open issue openai/codex#30994); prefer an explicit profile.

## Per engine

Engine flags and versions belong to the engine skills; this is what Codex needs.

| Endpoint   | `base_url`                  | Key                             | Notes                                                                                                                                                                      |
| ---------- | --------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM       | `http://HOST:PORT/v1`       | `env_key` matching `--api-key`  | Serves `/v1/responses`. Tools need `--enable-auto-tool-choice --tool-call-parser <name>`; reasoning needs `--reasoning-parser`. Thinking arrives in the `reasoning` field. |
| llama.cpp  | `http://HOST:PORT/v1`       | `env_key` if `--api-key` is set | Serves `/v1/responses`. Needs `--jinja` (default on current builds) and a chat template with a tool section; `-c` large enough for agent prompts.                          |
| Ollama     | `http://127.0.0.1:11434/v1` | none locally                    | `/v1/responses` is stateless (no `previous_response_id`). Raise `OLLAMA_CONTEXT_LENGTH` to 64k or more for agents. Use a model with the `tools` capability.                |
| llama-swap | `http://HOST:PORT/v1`       | `apiKeys` entry as bearer       | Routes `/v1/responses` by `model`, loads on demand. Raise `stream_idle_timeout_ms` and `request_max_retries` for cold swaps.                                               |
| LiteLLM    | `http://HOST:4000/v1`       | virtual key                     | Bridges Responses to chat completions for backends without it. See `combos/litellm-responses-bridge.md`.                                                                   |

Read model names from the endpoint: `curl -s -H "Authorization: Bearer $LOCAL_LLM_API_KEY" http://HOST:PORT/v1/models | jq -r '.data[].id'`.

## Verify

```bash
CODEX_BASE_URL=http://HOST:PORT/v1 CODEX_MODEL=qwen3-coder scripts/check-endpoint.sh
codex --profile local exec "print the current directory and stop"
```

Templates: `templates/config.toml`, `templates/local.config.toml`.
