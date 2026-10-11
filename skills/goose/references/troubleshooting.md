# goose: troubleshooting

> Verified against goose v1.54.0 (docs: troubleshooting/known-issues, getting-started/providers, guides/config-files), 2026-10-11

Reproduce with `curl` against the same host, path, key and model first. If curl works, the issue is goose config; if not, the endpoint (engine, `litellm` or `llama-swap` skill).

| Symptom                                                                              | Likely cause and fix                                                                                                                                                                                                           |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 404 from the endpoint                                                                | OpenAI provider: `OPENAI_BASE_PATH` wrong (`v1/chat/completions` versus `chat/completions`). Custom provider: `base_url` must be the full chat completions URL for the `openai` engine, the root for `anthropic` and `ollama`. |
| 401 "No api key passed in"                                                           | Key not loaded. A key in `config.yaml` is ignored. Use the keyring (`goose configure`), `secrets.yaml`, or the env var (`OPENAI_API_KEY`, `api_key_env`).                                                                      |
| Key lost after restart in Docker or over SSH                                         | No keyring service. Set `GOOSE_DISABLE_KEYRING=1` or pass keys as env vars; persist `~/.config/goose` if using `secrets.yaml`.                                                                                                 |
| "Failed to access keyring" errors                                                    | Same as above; goose usually falls back to file storage automatically. Force with `GOOSE_DISABLE_KEYRING=1 goose configure`.                                                                                                   |
| Ollama: `error sending request for url (http://localhost:11434/v1/chat/completions)` | Ollama not running or model not pulled, wrong `OLLAMA_HOST`, or Ollama bound to loopback while goose is elsewhere.                                                                                                             |
| Model chats but no tool calls                                                        | Model or engine lacks tool calling, `GOOSE_MODE=chat`, extensions disabled. Fix the engine parser, or enable `GOOSE_TOOLSHIM` (`models-and-tools.md`).                                                                         |
| Tool call appears as plain text or with `<think>` mixed in                           | Server not parsing tools or reasoning. Fix the parser flags or use the tool shim.                                                                                                                                              |
| Ignores `.goosehints`, extensions fail, odd truncation                               | Context too small (Ollama default). Raise `OLLAMA_CONTEXT_LENGTH`/`GOOSE_INPUT_LIMIT`, set `context_limit`.                                                                                                                    |
| "Context length exceeded"                                                            | Input over the model limit. Lower `GOOSE_CONTEXT_LIMIT` to the real window, split input, lower the compaction limits.                                                                                                          |
| `429` rate limit                                                                     | Provider throttling. Use a gateway with rate limits and fallbacks.                                                                                                                                                             |
| Provider missing from the list after creating JSON                                   | Invalid JSON, wrong directory, or a running session. Check `~/.config/goose/custom_providers/`, validate with `jq . file.json`, start a new session.                                                                           |
| Custom provider uses wrong host after env change                                     | Env vars override config; list variable names with `env \| cut -d= -f1`, filtered to `GOOSE_` and `OPENAI_`, then run `goose info -v`.                                                                                         |
| Model list empty with a gateway                                                      | `dynamic_models` fetch got 404/auth error; set `dynamic_models: false` with a static `models` list, or fix the key.                                                                                                            |
| "hermit:fatal" when installing an extension                                          | Stale hermit cache; remove `~/Library/Caches/hermit` on macOS as documented, then retry.                                                                                                                                       |
| Desktop shows no window on some Apple Silicon Macs                                   | Follow the installation page note for the affected chip; update goose.                                                                                                                                                         |
| Config edits seem ignored                                                            | Existing sessions keep the provider they started with; start a new session. Env vars beat the file.                                                                                                                            |

## Gather facts

```bash
goose --version; goose info -v            # redact keys before sharing
ls -la ~/.config/goose/ ~/.config/goose/custom_providers/ 2>/dev/null
jq . ~/.config/goose/custom_providers/*.json >/dev/null && echo "custom provider JSON valid"
env | cut -d= -f1 | grep -E '^(GOOSE_|OPENAI_|ANTHROPIC_|OLLAMA_|LITELLM_)' | sort
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer $KEY" | jq -r '.data[].id'
```

For startup problems on Desktop see the "desktop startup debugging" and "diagnostics and reporting" pages on the docs site; scrub logs before sharing.

## Official links

- Known issues: https://goose-docs.ai/docs/troubleshooting/known-issues
- Provider setup: https://goose-docs.ai/docs/getting-started/providers
