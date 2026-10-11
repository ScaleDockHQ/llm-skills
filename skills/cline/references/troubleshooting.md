# Cline: troubleshooting custom endpoints

> Verified against Cline v4.1.23 docs (OpenAI Compatible, local models, networking, authorization), 2026-10-11

## What it is and when to choose it

Symptom-first fixes when Cline cannot use a self-hosted endpoint. Server-side causes (parsers, templates, rejected parameters) belong to the engine and gateway skills.

## Install

Nothing to install. Reproduce with the same base URL, key and model name:

```bash
LLM_API_KEY_FILE=~/.config/llm/cline.key scripts/probe.sh http://127.0.0.1:4000/v1 coder
```

## Minimal working config

See `providers-endpoints.md`.

## How it plugs into the stack

```text
Cline --> [HTTP proxy?] --> gateway or engine
```

## Operating

IDE: the Cline panel error and VS Code's output. CLI: `cline doctor log`, `~/.cline/data/logs/cline.log`. Always compare with the gateway log.

## Tuning knobs

Context Window and Max Output Tokens, Use Compact Prompt, CLI `--timeout`, `--retries`, `--compaction`.

## Known pitfalls

| Symptom                                         | Likely cause                                                           | Fix                                                                                        |
| ----------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| "Invalid API Key" / 401                         | Wrong or expired key; gateway key lacks the model                      | Re-enter the key; test with curl; check the virtual key's `models`                         |
| "Model Not Found"                               | Model ID not served at that Base URL                                   | Copy the id from `/v1/models` or the gateway alias list                                    |
| Connection errors                               | Wrong Base URL, endpoint down, firewall, proxy                         | `curl` the same URL from the same machine; check `http_proxy`, `no_proxy`                  |
| 404 on every call                               | Base URL missing `/v1` (OpenAI Compatible) or has it (Ollama provider) | OpenAI Compatible `.../v1`; Ollama provider bare host                                      |
| Works in terminal, not in VS Code Remote or WSL | `localhost` is the remote or container side                            | Use the host's reachable address, or forward the port                                      |
| Context overflows or tasks forget early work    | Context Window left at default                                         | Set Context Window to the engine's real value; start new tasks sooner                      |
| Output cut off                                  | Max Output Tokens too low or engine limit                              | Raise it within the engine's limit                                                         |
| Agent chats but never edits files               | Engine returns no `tool_calls`                                         | Fix parser or template; probe shows `tool_calls=0`; Computer Use setting matches the model |
| Loops, malformed tool calls with a small model  | Model too weak for the agent prompt                                    | Enable Use Compact Prompt; use a larger coder model                                        |
| Hangs on the first request                      | Model loading (llama-swap, Ollama cold start) or buffered stream       | Warm the model; raise timeouts; disable proxy buffering                                    |
| Certificate errors (CLI)                        | Private CA                                                             | `NODE_EXTRA_CA_CERTS=/path/ca.pem`                                                         |
| Proxy not honoured (CLI)                        | SOCKS or PAC proxy, or lowercase variables unset                       | Use an HTTP proxy with `https_proxy`/`http_proxy`; set `no_proxy` for LAN                  |
| JetBrains ignores new proxy settings            | Cline does not pick up proxy changes dynamically                       | Restart the IDE                                                                            |
| Key visible in `history` or `ps`                | `cline -k` / `cline auth -k` used                                      | Rotate the key; use interactive `cline auth`                                               |
| CLI stuck or stale sessions                     | Hub process in a bad state                                             | `cline doctor`, `cline hub status`, `cline doctor fix` (kills Cline processes)             |

## Official links

- Troubleshooting in OpenAI Compatible: https://docs.cline.bot/provider-config/openai-compatible
- Networking and proxies: https://docs.cline.bot/troubleshooting/networking-and-proxies
- Local models: https://docs.cline.bot/running-models-locally/overview
- CLI reference (`doctor`): https://docs.cline.bot/cli/cli-reference
