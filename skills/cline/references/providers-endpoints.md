# Cline: providers for custom endpoints

> Verified against Cline v4.1.23 (VS Code extension) and CLI v3.0.70, docs.cline.bot provider, local-model and CLI pages, 2026-10-11

## What it is and when to choose it

Cline is an agent in your IDE (VS Code, JetBrains), terminal and desktop app. Requests leave from your machine (extension host or CLI process), so localhost, LAN, VPN and Tailscale endpoints work. Use this page to pick the provider that matches the API your endpoint speaks.

## Install

Nothing beyond Cline itself; see `install.md`. Provider settings are in the extension panel (gear icon) or `cline auth` in the CLI. Credentials and provider config are stored in `~/.cline/data/settings/providers.json`.

## Minimal working config

### OpenAI Compatible (vLLM, llama.cpp, LiteLLM, llama-swap, Ollama `/v1`)

Settings > API Provider "OpenAI Compatible":

| Field                             | Value                                                                                                          |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Base URL                          | `http://host:port/v1` or `https://llm.example.com/v1` (not api.openai.com)                                     |
| API Key                           | A scoped virtual key (empty or any string when the endpoint has no auth)                                       |
| Model ID                          | The exact name the endpoint serves (gateway alias, `--served-model-name`)                                      |
| Use Azure Identity Authentication | Only for Azure managed identity; leave off here                                                                |
| Model Configuration               | Max Output Tokens, Context Window size, Image Support, Computer Use, input and output price per million tokens |

Docs also show a Verify button for the connection. Set Context Window and Max Output Tokens explicitly; the endpoint's `/v1/models` carries neither.

### Anthropic-compatible endpoint

Provider "Anthropic": paste the key, then tick "Use custom base URL" and enter the gateway URL (the docs say most users do not need it). Use this when the endpoint serves the Anthropic Messages API (for example LiteLLM `/v1/messages`). Whether the URL should carry `/v1` is not stated in the docs; test with `curl "$URL/v1/messages"` first, then try the form that returns 200 in the gateway log. Extended Thinking is a checkbox under the model picker for Claude models.

### Ollama and LM Studio (local runtimes)

Cline has dedicated providers. Ollama: provider "Ollama", Base URL `http://localhost:11434` (no `/v1`), pick the model from the dropdown. LM Studio: provider "LM Studio", Base URL `http://localhost:1234`. For a remote Ollama or a gateway use "OpenAI Compatible" with the `/v1` URL instead. Local models: enable **Use Compact Prompt** (Settings > Features), keep tasks focused and start a new task when context grows (Cline's local-model guidance).

### LiteLLM

Cline's enterprise docs list a "LiteLLM" provider (base URL set by the admin, API key per member, models listed from the proxy). "OpenAI Compatible" pointing at the same proxy works as well and is the safer documented path for individuals.

### CLI

```bash
cline auth                                   # interactive: provider, key, model (key not echoed)
cline auth -p <provider> -b <baseurl> -m <model>   # scripted, enter the key interactively
cline -P <provider> -m <model> "prompt"      # one run with a provider and model
cline config                                 # view settings, rules, skills, hooks
```

`-k` (on `cline` and on `cline auth`) exists but puts the key in shell history and the process list; avoid them. The SDK docs name the provider id `openai-compatible` and pass `baseUrl` and `apiKey`; the CLI's provider id strings are not listed on the pages read, so use the interactive flow to discover them.

## Key handling

- API keys are stored in `~/.cline/data/settings/providers.json` (the config docs say global settings apply across the IDE, CLI and SDK; the IDE may also use editor secret storage, so do not assume the file is the only copy). Keep the file owner-only and out of repositories; never print it. To list configured providers without values: `jq -r 'keys[]' ~/.cline/data/settings/providers.json` (confirm the file's shape first, it is internal).
- Use a per-tool virtual key from the gateway with a model allowlist and budget; rotate by creating a new one and re-running `cline auth`.
- `CLINE_DIR` or `--config <path>` points the CLI at another config directory (for example a throwaway directory for CI).

## Model-name mapping

Model ID is sent verbatim. Use the gateway alias. Cline's catalog knows real vendor model names, but for the OpenAI Compatible provider the entry is yours; set limits by hand. Avoid aliases that look like a famous vendor model if you want Cline to treat them as custom.

## Tool calling and streaming caveats

- "Computer Use" in Model Configuration is labelled in the docs as for models with tool/function calling; leave it consistent with what the model can do.
- Engines must emit OpenAI-format `tool_calls`: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`; llama.cpp `--jinja` with a tool-capable template; Ollama a tool-capable model. Small local models may loop or call tools incorrectly; Kilo's docs say the same of local runtimes, and Cline recommends Compact Prompt.
- Responses stream; proxies that buffer SSE make Cline look hung. Disable buffering.
- Anthropic path: extended thinking and prompt caching apply to real Anthropic models; a gateway may ignore caching headers.

## How it plugs into the stack

```text
Cline (IDE extension host or CLI) --> gateway or engine
```

Proxy handling: the VS Code extension follows VS Code's proxy settings; the CLI reads `https_proxy`, `http_proxy`, `no_proxy` and `NODE_EXTRA_CA_CERTS` (HTTP proxies only; no SOCKS or PAC). Add the endpoint's host to `no_proxy` for LAN endpoints.

## Operating

- Logs: `cline doctor log` (file `~/.cline/data/logs/cline.log`, or `CLINE_LOG_PATH`); `cline doctor` diagnoses configuration; `cline doctor fix` kills running Cline processes. JetBrains log: `~/.cline/cline-core-service.log`.
- Gateway log is the ground truth for path, key and model name.

## Known pitfalls

- Context Window left at default: Cline compacts or overflows at the wrong point.
- Ollama provider given a `/v1` URL (or OpenAI Compatible given a bare host): 404.
- Key passed with `-k`: now in shell history.
- Roo Code and Kilo Code settings do not carry over; they are separate extensions.

## Official links

- OpenAI Compatible: https://docs.cline.bot/provider-config/openai-compatible
- Anthropic: https://docs.cline.bot/provider-config/anthropic
- Local models: https://docs.cline.bot/running-models-locally/overview
- Config files: https://docs.cline.bot/getting-started/config
- CLI reference: https://docs.cline.bot/cli/cli-reference
- Networking and proxies: https://docs.cline.bot/troubleshooting/networking-and-proxies
- LiteLLM (enterprise, members): https://docs.cline.bot/enterprise-solutions/configuration/remote-configuration/litellm/member-configuration
- SDK model providers: https://docs.cline.bot/sdk/model-providers
