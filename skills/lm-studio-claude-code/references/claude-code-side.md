# Claude Code side

> Verified against Claude Code docs (llm-gateway, llm-gateway-connect, llm-gateway-protocol, model-config; npm latest 2.1.296, stable 2.1.287), 2026-10-11

Claude Code is not a published skill here yet; install later: the `claude-code` skill will own settings, permissions and hooks. This is the minimum for a local endpoint. Claude Code treats `ANTHROPIC_BASE_URL` as the Claude API and cannot tell what sits behind it.

## Variables

| Variable                                       | Use here                                                                                                  |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `ANTHROPIC_BASE_URL`                           | `http://localhost:1234` (LM Studio server root)                                                           |
| `ANTHROPIC_AUTH_TOKEN`                         | Sent as `Authorization: Bearer`; any string when auth is off, the LM Studio token when on                 |
| `ANTHROPIC_API_KEY`                            | Alternative, sent as `x-api-key`; LM Studio accepts both; do not set both                                 |
| `CLAUDE_CODE_ATTRIBUTION_HEADER=0`             | Omits the attribution block from the system prompt; upstream LM Studio docs recommend it                  |
| `ANTHROPIC_MODEL` or `claude --model <id>`     | The LM Studio model identifier; applies to that session                                                   |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL`                | Optional; also moves background tasks (session titles) to that model                                      |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`   | Stops version checks, telemetry and similar traffic to Anthropic and third parties; disables auto-updates |
| `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` | Adds the endpoint's `/v1/models` to the `/model` picker (see limits below)                                |

Credential precedence: a credential variable beats a saved claude.ai login, which stays saved and unused while the variable is set; `/logout` clears it. `/status` shows the active base URL and credential source. Setting only `ANTHROPIC_BASE_URL` without a credential variable leaves a saved login as the active credential: set the token too.

## Settings file instead of exports

`~/.claude/settings.json` `env` block applies everywhere, including background agents; shell exports do not reliably reach them. Do not put credentials in a project's `.claude/settings.json` (committed and shared). In interactive sessions a project settings `env` applies only after the first-run wizard and trust prompt, so set the token somewhere read before first-run setup (shell export or `~/.claude/settings.json`).

## Model picker and names

- Discovery keeps only entries whose `id` contains `claude` or `anthropic`; ids such as `openai/gpt-oss-20b` are filtered out and will not appear in `/model`. Select the local model with `--model` or `ANTHROPIC_MODEL`, which Claude Code does not validate up front (a typo fails on the first request).
- Background tasks use the main model when `ANTHROPIC_AUTH_TOKEN` is the credential, unless `ANTHROPIC_DEFAULT_HAIKU_MODEL` pins another. Pinning a second local model means LM Studio loads it too (memory).
- Capability declarations (`ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES`) only apply in the cloud-provider configurations, not behind `ANTHROPIC_BASE_URL`.

## What Claude Code sends

It posts to `/v1/messages?beta=true` with `anthropic-version` and `anthropic-beta` headers and the full beta field set, even to a non-Anthropic endpoint. `/v1/messages/count_tokens` is optional (absent: it estimates by characters). If the endpoint rejects unknown fields (`Extra inputs are not permitted`, `context_management`), set `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`. A streaming response must be relayed event by event; buffering stalls the client.

## Limits

- Vendor support: see the support statement in `SKILL.md`.
- The fast-mode check and WebFetch domain safety check call `api.anthropic.com` directly regardless of the base URL (`/fast` may report unavailable).
- Subscription limits do not apply to requests that carry a gateway credential variable; with a local endpoint there is no per-token bill, but the saved claude.ai login is untouched.

## Official links

- https://code.claude.com/docs/en/llm-gateway
- https://code.claude.com/docs/en/llm-gateway-connect
- https://code.claude.com/docs/en/llm-gateway-protocol
- https://code.claude.com/docs/en/model-config
