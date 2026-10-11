# Zed: troubleshooting

> Verified against Zed v1.23.2 (docs: ai/use-api-access, ai/use-a-local-model, ai/tool-permissions, environment), 2026-10-11

Reproduce with `curl` against the same URL, key and model first. If curl works, the problem is Zed config; if not, it is the endpoint (see the engine or `litellm` skill).

| Symptom                                                         | Likely cause and fix                                                                                                                                                                                                                      |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Provider shown but model list empty                             | Generic providers list only `available_models`; add entries. Built-in `ollama`/`llama.cpp`: `auto_discover` off, wrong `api_url`, or server not running.                                                                                  |
| 404 on every request                                            | `api_url` suffix wrong. OpenAI-compatible: use the root that serves `/chat/completions`, usually `.../v1`. Anthropic-compatible: no `/v1` in the documented example. Read the server log for the path hit.                                |
| 401 or "No api key passed in"                                   | Key not reaching the provider. Check the env var name (provider id upper snake case plus `_API_KEY`), restart Zed, or re-enter in Agent Settings. A non-empty env var overrides the keychain. Dock launches only see login-shell exports. |
| Works from `zed .` but not from the Dock                        | Environment differs. Export the key in a login-shell file and reopen Zed.                                                                                                                                                                 |
| 400 "model not found"                                           | `name` is not exactly what `/v1/models` lists; gateways are case and prefix sensitive (`openai/coder` versus `coder`).                                                                                                                    |
| Agent answers but never edits files                             | `capabilities.tools` false, model lacks tool support, engine tool parser missing, or the thread's agent profile excludes tools. See `models-and-features.md`.                                                                             |
| Tool call JSON printed as text                                  | Engine not parsing tools (vLLM parser flags, llama.cpp `--jinja`). Fix on the server.                                                                                                                                                     |
| 400 about `max_completion_tokens` unsupported                   | Set `capabilities.max_tokens_parameter: true` for that model.                                                                                                                                                                             |
| 400 about `reasoning_effort` or unknown field                   | Remove `reasoning_effort` (or set `none`); the server does not support it.                                                                                                                                                                |
| Thinking shows as raw `<think>` text                            | Server returns reasoning inline. Enable a reasoning parser on the server, or set `interleaved_reasoning` if it uses `reasoning_content`.                                                                                                  |
| 400 on Anthropic-compatible requests mentioning `cache_control` | Set `capabilities.prompt_caching: false`.                                                                                                                                                                                                 |
| Long chats truncate early on Ollama                             | Zed defaults to `num_ctx` 4096; set `context_window` or per-model `max_tokens`.                                                                                                                                                           |
| Answers arrive all at once                                      | Proxy buffering SSE. Disable buffering on nginx/CDN in front of the endpoint.                                                                                                                                                             |
| Remote (SSH) project cannot reach `localhost` model             | Providers run in the local app; `localhost` is your machine. Use a reachable address or port-forward locally.                                                                                                                             |
| Tab completion does nothing                                     | `edit_predictions` is separate from Agent models; set it up (`edit-prediction.md`) and confirm the server has `/v1/completions`.                                                                                                          |
| Settings edits ignored                                          | Invalid JSONC or edited the wrong file; project `.zed/settings.json` overrides user settings. Check for the settings error banner.                                                                                                        |

## Gather facts

```bash
rg -n 'language_models|default_model|edit_predictions' ~/.config/zed/settings.json .zed/settings.json 2>/dev/null
env | cut -d= -f1 | grep -E '_API_KEY$' | sort
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer $KEY" | jq -r '.data[].id'
ls ~/.local/share/zed/logs/Zed.log 2>/dev/null   # Linux app log; on macOS and Windows use the "zed: open log" action
```

The app log shows request errors from providers; do not paste logs publicly without scrubbing headers.

## Official links

- Use API Access: https://zed.dev/docs/ai/use-api-access
- Tool permissions: https://zed.dev/docs/ai/tool-permissions
- Environment variables: https://zed.dev/docs/environment
