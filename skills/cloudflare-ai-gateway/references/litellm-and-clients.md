# LiteLLM and clients

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06) and LiteLLM OpenAI-compatible provider docs, 2026-10-11

Sources: usage/rest-api, authentication, integrations/coding-agents/claude-code, integrations/vercel-ai-sdk under <https://developers.cloudflare.com/ai-gateway/>; <https://docs.litellm.ai/docs/providers/openai_compatible>.

## OpenAI SDK

```python
import os
from openai import OpenAI
client = OpenAI(
    api_key=os.environ["CLOUDFLARE_API_TOKEN"],
    base_url=f"https://api.cloudflare.com/client/v4/accounts/{os.environ['CLOUDFLARE_ACCOUNT_ID']}/ai/v1",
)
print(client.chat.completions.create(model="openai/<model>", messages=[{"role": "user", "content": "ping"}], max_tokens=16).choices[0].message.content)
```

To use a non-default gateway add `default_headers={"cf-aig-gateway-id": "<gateway>"}`.

## Claude Code

Needs an authenticated gateway and a gateway token with `Run`. Credentials: Unified Billing credits or your own Anthropic key (stored as BYOK or sent normally). Use the Anthropic provider endpoint:

```bash
export ANTHROPIC_BASE_URL="https://gateway.ai.cloudflare.com/v1/$CLOUDFLARE_ACCOUNT_ID/<gateway>/anthropic"
export ANTHROPIC_API_KEY="$CF_AIG_TOKEN"
export ANTHROPIC_CUSTOM_HEADERS="cf-aig-authorization: Bearer $CF_AIG_TOKEN"
```

Claude Code speaks the Anthropic Messages schema only, so it cannot use `/ai/v1/chat/completions` or `/ai/run`. Bedrock and Vertex variants exist (`CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX` with provider endpoints on the gateway and BYOK credentials); follow the Claude Code page for the exact variables.

## LiteLLM

AI Gateway can sit behind LiteLLM as an OpenAI-compatible upstream, which keeps LiteLLM's virtual keys and budgets in front:

```yaml
model_list:
  - model_name: cf-gpt
    litellm_params:
      model: openai/openai/<model> # LiteLLM openai/ prefix, then the gateway's provider/model
      api_base: https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1
      api_key: os.environ/CLOUDFLARE_API_TOKEN
      extra_headers: { "cf-aig-gateway-id": "<gateway>" }
```

Replace `<ACCOUNT_ID>` literally; LiteLLM does not expand shell variables in `api_base`. Use `litellm` for the proxy side: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.

## Vercel AI SDK

Use `createOpenAI` with the same `baseURL` and token as the OpenAI SDK, or the `ai-gateway-provider` package with `createAiGateway({accountId, gateway, apiKey})` and `createUnified()` for `{provider}/{model}` names. See `integrations/vercel-ai-sdk`.
