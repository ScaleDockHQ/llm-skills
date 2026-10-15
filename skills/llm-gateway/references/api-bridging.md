# API bridging: /v1/messages and /v1/responses

> Verified against LiteLLM v1.105.0 (docs: anthropic_unified, response_api, tutorials/claude_responses_api) and Claude Code gateway docs, 2026-10-11

## How it plugs into this stack

- Clients speak chat completions, Responses or Messages; local engines usually speak only chat completions. LiteLLM on port 4000 serves all three.
- Anthropic clients (Claude Code): base URL is the gateway root without `/v1`; discovery lists only aliases containing `claude` or `anthropic`.
- Responses clients (Codex, Agents SDK): set `use_chat_completions_api: true` on every `openai/` deployment whose backend lacks `/v1/responses`. Otherwise Responses calls hit a missing route and later requests on pooled keep-alive connections break.
- For OpenAI-compatible backends behind `/v1/messages`, set `litellm_settings.use_chat_completions_url_for_anthropic_messages: true`.
- Test plain, streaming and one tool call on each bridged path; never let a client hit a route the backend does not implement.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llm-skills --skill litellm)
