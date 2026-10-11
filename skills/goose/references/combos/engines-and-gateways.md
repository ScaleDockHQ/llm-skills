# goose with vLLM, llama.cpp, Ollama, LM Studio, llama-swap and LiteLLM

> Verified against goose v1.54.0 docs and source (providers page, declarative provider definitions), 2026-10-11

Pick one path per backend; do not mix the dedicated provider and the OpenAI provider for the same proxy.

| Backend    | goose provider                       | Host setting                                                                                         | Notes                                                                                                                  |
| ---------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| vLLM       | OpenAI (or custom JSON)              | `OPENAI_HOST=http://host:8000`                                                                       | Start vLLM with `--enable-auto-tool-choice --tool-call-parser <name>`; add `--api-key` and use it as `OPENAI_API_KEY`. |
| llama.cpp  | OpenAI (or custom JSON)              | `OPENAI_HOST=http://host:8080`                                                                       | `llama-server --jinja` for tools; `--api-key` if exposed beyond loopback.                                              |
| Ollama     | Ollama                               | `OLLAMA_HOST=http://host:11434`                                                                      | Needs a tool-capable model; raise context (`OLLAMA_CONTEXT_LENGTH`, `GOOSE_INPUT_LIMIT`).                              |
| LM Studio  | built-in `lmstudio` provider         | `LMSTUDIO_HOST=http://host:1234`                                                                     | No auth by default; model list is dynamic.                                                                             |
| llama-swap | built-in `llama_swap` provider       | `LLAMA_SWAP_HOST=http://host:8080`                                                                   | First request after idle loads a model; allow time.                                                                    |
| LiteLLM    | LiteLLM provider, or OpenAI provider | `LITELLM_HOST` + `LITELLM_BASE_PATH` + `LITELLM_API_KEY`, or `OPENAI_HOST` root + `OPENAI_BASE_PATH` | Set `GOOSE_CONTEXT_LIMIT` for custom aliases; use a virtual key.                                                       |

## Steps for any OpenAI-shaped backend

1. `curl -fsS $B/models -H "Authorization: Bearer $KEY" | jq -r '.data[].id'`; choose the alias.
2. Provide the key in the `0600` env file (`assets/goose.env.example`) or the keyring.
3. `export GOOSE_PROVIDER=openai GOOSE_MODEL=<alias> OPENAI_HOST=<root>`; run `goose info -v`.
4. Ask for a file listing; confirm tool calls. If none, see `models-and-tools.md`.
5. Set `GOOSE_CONTEXT_LIMIT` to the engine's real window minus headroom.

## Remote engines

- Engines bound to loopback are unreachable from other hosts. Expose them behind an authenticated proxy, VPN or tailnet; never open an unauthenticated engine port to the internet (see `caddy`, `tailscale`, `cloudflare-tunnel` skills).
- goose inside Docker reaching an engine on the host: use `host.docker.internal` (add `--add-host=host.docker.internal:host-gateway` on Linux) rather than `localhost`.

## LiteLLM specifics

- OpenAI-provider route: `OPENAI_HOST` is the proxy root, `OPENAI_BASE_PATH` is usually `v1/chat/completions`. A `404` points at the base path; a `401` "No api key passed in" points at key loading.
- Dedicated provider route: `LITELLM_HOST`, `LITELLM_BASE_PATH`, `LITELLM_API_KEY`.
- For Anthropic shape, a custom provider with `engine: anthropic` and `base_url` set to the proxy root (`assets/custom_provider.anthropic.json`).

## Official links

- Providers (custom OpenAI endpoints, LiteLLM note, local LLMs): https://goose-docs.ai/docs/getting-started/providers
- LiteLLM proxy: https://docs.litellm.ai/docs/simple_proxy
