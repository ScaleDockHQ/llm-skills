# Open WebUI behind LiteLLM (one connection, many engines)

> Verified against Open WebUI v0.12.0 and LiteLLM v1.105.0 (inherited stamp; docs: connect-a-provider), 2026-10-11

Pattern: Open WebUI has a single OpenAI-compatible connection to LiteLLM (or llama-swap); the gateway fans out to vLLM, llama.cpp, Ollama and clouds, and holds the upstream keys. Open WebUI then needs only one virtual key and one URL. Set up the gateway with the `litellm` or `llama-swap` skill (install with `npx skills add ScaleDockHQ/llm-skills --skill litellm`).

1. Gateway: create a virtual key limited to the models Open WebUI should see, with a budget (`litellm` skill), stored in a `0600` file.
2. Connection: `http://host.docker.internal:4000/v1` (or `http://litellm:4000/v1` on a shared network), Bearer, that key. Set Provider to LiteLLM in Advanced.
3. Model ids are the gateway's `model_name` aliases. Use aliases, not provider-prefixed upstream names, so swapping engines does not break saved chats.
4. Declare capabilities per model in Open WebUI (`models-and-tools.md`); the gateway does not pass them.
5. Tool calling works only if the upstream engine parses tools and the alias maps to such a model.
6. Optional: `ENABLE_FORWARD_USER_INFO_HEADERS=True` sends user name, id, email and role headers to the gateway for per-user attribution. Only enable with a trusted gateway.
7. With llama-swap, point at its port; first request to a swapped-out model waits for load (raise `AIOHTTP_CLIENT_TIMEOUT`).

Verify:

```bash
curl -fsS -H "Authorization: Bearer $(cat ~/.config/open-webui/litellm-key)" http://localhost:4000/v1/models | jq -r '.data[].id'
```

Then pick one alias in Open WebUI and chat.
