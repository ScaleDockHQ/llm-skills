# Continue: troubleshooting custom endpoints

> Verified against Continue v2.1.0-vscode docs (FAQ, model capabilities) and source, 2026-10-11

## What it is and when to choose it

Symptom-first fixes when Continue cannot use a self-hosted endpoint. Server-side causes (parsers, templates, rejected parameters) belong to the engine and gateway skills.

## Install

Nothing to install. First reproduce with the same base URL, key and model name:

```bash
LLM_API_KEY_FILE=~/.config/llm/continue.key scripts/probe.sh http://127.0.0.1:4000/v1 coder
```

If the probe fails, Continue is not the problem.

## Minimal working config

See `config-endpoints.md`.

## How it plugs into the stack

```text
Continue --(openai: /chat/completions | anthropic: /messages | ollama: /api/chat)--> endpoint
```

## Operating

Open the Continue output/console in the IDE for the error text; read the gateway log for path, status and model name.

## Tuning knobs

`requestOptions.timeout` for slow prefill, `caBundlePath` for private CAs, `defaultCompletionOptions.contextLength` and `maxTokens` for overflow.

## Known pitfalls

| Symptom                                          | Likely cause                                                            | Fix                                                                                         |
| ------------------------------------------------ | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 404 on every request                             | `apiBase` lacks `/v1` (source warns "forgot to add '/v1'")              | `apiBase: http://host:port/v1` for `openai` and `anthropic` providers                       |
| 404 only for some model names                    | Alias matches `o<digit>` or `gpt-5..9`, sent to `/responses`            | Rename the alias or `useResponsesApi: false`                                                |
| Agent mode greyed out or tools never called      | `tool_use` missing, or engine returns no tool calls                     | Add `capabilities: [tool_use]`; fix the engine parser/template; probe shows `tool_calls=0`  |
| Images cannot be attached                        | `image_input` missing or model text-only                                | Add `image_input` and use a vision model                                                    |
| `fetch failed`, certificate errors               | Private CA or proxy                                                     | `requestOptions.caBundlePath`; check VS Code proxy setting                                  |
| 401 with a key that works in curl                | `${{ secrets.X }}` not resolved: key in shell export, wrong `.env` path | Put it in `~/.continue/.env`, restart the IDE; no quotes around values                      |
| Anthropic provider 401                           | Gateway expects `Authorization: Bearer`, Continue sends `x-api-key`     | Enable `x-api-key` auth on the gateway route, or use `provider: openai`                     |
| "Model requires more system memory" (Ollama)     | Continue default context larger than the host can allocate              | Lower `defaultCompletionOptions.contextLength` or use a smaller model                       |
| Unable to connect to local Ollama                | Server not running, wrong host, or remote bind                          | `ollama serve`; `apiBase` to the server IP; `OLLAMA_HOST=0.0.0.0:11434`; use `http://`      |
| Works in terminal, fails in dev container or WSL | `localhost` is the container                                            | `host.docker.internal` (with `host-gateway` on Linux) or the WSL mirrored networking mode   |
| Config change has no effect                      | Window not reloaded                                                     | "Developer: Reload Window"                                                                  |
| Autocomplete empty                               | Chat model without FIM, or wrong route                                  | FIM-capable model; `useLegacyCompletionsEndpoint: true` if the engine serves `/completions` |
| Reasoning text appears as the answer             | Engine returns `<think>` inside content                                 | Enable the engine's reasoning parser so thinking goes to a separate field                   |
| 404 from a gateway after a tool request          | Model behind it has no function calling (FAQ, OpenRouter case)          | Pick a tool-capable model or route that model without tools                                 |

## Official links

- FAQ: https://docs.continue.dev/faqs
- Model capabilities: https://docs.continue.dev/customize/deep-dives/model-capabilities
- config.yaml reference: https://docs.continue.dev/reference
