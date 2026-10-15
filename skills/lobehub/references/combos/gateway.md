# LobeHub behind LiteLLM or llama-swap

> Verified against LobeHub v2.2.19 and LiteLLM v1.105.0 (inherited stamp; docs: model-provider, model-list), 2026-10-11

One OpenAI-compatible connection to a gateway keeps LobeHub config small; the gateway holds upstream keys and routes to vLLM, llama.cpp, Ollama and clouds. Set the gateway up with `litellm` or `llama-swap` (`npx skills add ScaleDockHQ/llm-skills --skill litellm`).

1. Create a gateway virtual key limited to the models LobeHub should use, with a budget; save it in a `0600` file.
2. In the Compose `.env`:
   ```bash
   ENABLED_OPENAI=1
   OPENAI_API_KEY=<virtual key>
   OPENAI_PROXY_URL=http://host.docker.internal:4000/v1       # or http://litellm:4000/v1 on a shared network
   OPENAI_MODEL_LIST=-all,+coder=Coder<131072:fc>,+vision=Vision<32768:vision:fc>
   ```
3. Use gateway aliases as ids so engines can change without breaking saved agents.
4. Declare `fc`/`vision` per alias; the gateway does not pass capabilities.
5. Recreate: `docker compose up -d lobe`.
6. For an Anthropic-shaped route use `ANTHROPIC_PROXY_URL` (see `connections.md`).
7. llama-swap: first call to a swapped-out model waits for load; raise client timeouts if needed.

Verify:

```bash
curl -fsS -H "Authorization: Bearer $(cat ~/.config/lobehub/gateway-key)" http://localhost:4000/v1/models | jq -r '.data[].id'
```

Then pick the alias in LobeHub and chat.
