# Aider: custom endpoints, keys and model names

> Verified against Aider v0.86.0 (docs: llms/openai-compat, llms/ollama, llms/other, config/dotenv, config/aider_conf, config/options, troubleshooting/models-and-keys), 2026-10-11

Aider uses the LiteLLM client library; the model-name prefix selects the provider adapter and which environment variables are read.

## OpenAI-compatible endpoint (vLLM, llama.cpp, llama-swap, LiteLLM, LM Studio and similar)

```bash
export OPENAI_API_BASE=http://HOST:PORT/v1       # include /v1
export OPENAI_API_KEY="$(cat ~/.config/llm/key)"  # any non-empty value if the server has no auth
aider --model openai/<served-name>
```

- `<served-name>` is the ID from `GET /v1/models` (vLLM `--served-model-name`, llama-swap model key, LiteLLM `model_name`). Everything after `openai/` goes to the server unchanged.
- Equivalent flags and variables: `--openai-api-base`, `--openai-api-key`, `AIDER_OPENAI_API_BASE`, `AIDER_OPENAI_API_KEY`. Do not pass keys as flags.
- Windows: `setx` then restart the shell (docs).

## Where to put settings

| File                         | Locations (later wins)                                            | Use                                                                 |
| ---------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------- |
| `.aider.conf.yml`            | home, git root, current directory (later wins; `--config <file>`) | Options without secrets: `model`, `openai-api-base`, `edit-format`. |
| `.env`                       | home, git root, current directory, then `--env-file <file>`       | Keys and provider variables.                                        |
| `.aider.model.settings.yml`  | home, git root, current directory, or `--model-settings-file`     | Per-model behavior: edit format, extra params.                      |
| `.aider.model.metadata.json` | home, git root, current directory, or `--model-metadata-file`     | Context and cost for unknown models.                                |

Only the OpenAI and Anthropic keys can be set in the YAML; every other provider key must be in `.env` or the environment (docs). Keep `.env` out of git (`chmod 600 .env`, add to `.gitignore`).

Other settings: `--set-env NAME=value` (repeatable) sets an environment variable for provider settings; `AIDER_<OPTION>` variables mirror every flag; `--verify-ssl`/`--no-verify-ssl` and `--timeout` for HTTP behavior. Avoid `--no-verify-ssl`; trust the private CA instead (`SSL_CERT_FILE` or `REQUESTS_CA_BUNDLE`, whichever the Python HTTP stack honors on that install: test).

## Ollama

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
OLLAMA_CONTEXT_LENGTH=8192 ollama serve   # docs example; larger for real work
aider --model ollama_chat/<model>
```

- `ollama_chat/` is recommended over `ollama/` by the aider docs.
- Authenticated Ollama: `OLLAMA_API_KEY`.
- Ollama's default window is 2k and it silently discards what does not fit. Aider by default asks Ollama for a window large enough for each request plus 8k tokens for the reply. To pin a fixed window instead (docs):

```yaml
- name: ollama/qwen2.5-coder:32b-instruct-fp16
  extra_params:
    num_ctx: 65536
```

in `.aider.model.settings.yml`. Check with `ollama ps` that the loaded context matches. Ollama also serves `/v1`, so `openai/` plus `OPENAI_API_BASE=http://HOST:11434/v1` works too, but the aider docs describe automatic `num_ctx` only for the Ollama routes, so Ollama's server default may apply: set `OLLAMA_CONTEXT_LENGTH` yourself.

## Anthropic-format endpoint (engines or gateways with `/v1/messages`)

Aider's docs cover the Anthropic API itself (`ANTHROPIC_API_KEY`, bare model aliases). A custom Anthropic-format base URL is a LiteLLM feature that aider inherits, not something the aider docs promise:

```bash
export ANTHROPIC_API_BASE=http://HOST:PORT        # LiteLLM appends /v1/messages
export ANTHROPIC_API_KEY="$(cat ~/.config/llm/key)"
aider --model anthropic/<served-name>
```

Untested here against a live engine. For self-hosted models prefer the OpenAI-compatible route, which is aider's documented path; use the Anthropic route only when the endpoint speaks Messages and nothing else. Aider also looks up the model's metadata by name, so Anthropic-only settings (thinking tokens, prompt caching headers) may be applied to names that look like Claude; use an unrelated alias for non-Claude models.

## Extra headers and body fields

Per model in `.aider.model.settings.yml`, or for all models with the special name `aider/extra_params`:

```yaml
- name: aider/extra_params
  extra_params:
    extra_headers:
      X-Team: platform
    max_tokens: 8192
```

`extra_params` is passed to `litellm.completion()`. Use it for tenant headers, `max_tokens`, `num_ctx`, `temperature` defaults or provider-specific body fields. Put a gateway key header here only if the gateway cannot use the standard `Authorization` header, and prefer environment expansion outside the file over writing a key into it.

## Per-engine notes

| Engine     | `OPENAI_API_BASE`     | Notes                                                                                                     |
| ---------- | --------------------- | --------------------------------------------------------------------------------------------------------- |
| vLLM       | `http://HOST:8000/v1` | `--api-key` on the server guards `/v1`; use the same value as `OPENAI_API_KEY`. Name = served model name. |
| llama.cpp  | `http://HOST:8080/v1` | Single model; name can be anything the server accepts (check `/v1/models`). `--jinja` for chat template.  |
| llama-swap | `http://HOST:PORT/v1` | Model key from its config is the name; first request may wait for a model load: raise `--timeout`.        |
| LiteLLM    | `http://HOST:4000/v1` | Name is a `model_name` alias; virtual key as `OPENAI_API_KEY`.                                            |
| Ollama     | see above             | Prefer `ollama_chat/`.                                                                                    |

Model selection without flags: `AIDER_MODEL`, `model:` in YAML, aliases with `--alias name:model`. With no model and no keys, aider offers to connect to OpenRouter; set `--model` explicitly on hosts that must not reach out.

## Verify

`scripts/check-endpoint.sh`, then `aider --model openai/<name> --message "reply with ok" --no-git --exit` to see the startup banner (version, model, edit format, repo map) and one round trip. `aider --list-models <partial>` lists LiteLLM's known models and does not call your server.
