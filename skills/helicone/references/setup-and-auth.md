# Setup and authentication

> Verified against Helicone docs (quickstart, gateway overview) and Helicone/helicone main (last commit 2026-09-16), 2026-10-11

Sources: <https://docs.helicone.ai/getting-started/quick-start>, <https://docs.helicone.ai/gateway/overview>, <https://docs.helicone.ai/gateway/concepts/error-handling>, <https://www.helicone.ai/blog/joining-mintlify>.

## Account and key

Sign up, then create an API key under Settings > API Keys (`us.helicone.ai/settings/api-keys`). Store it without echoing it:

```bash
umask 077; read -r -s -p "Helicone key: " k; printf '%s' "$k" > ~/.config/helicone-key; unset k
export HELICONE_API_KEY="$(cat ~/.config/helicone-key)"
```

## Send a request

The gateway is OpenAI-compatible at `https://ai-gateway.helicone.ai`:

```bash
curl -sS https://ai-gateway.helicone.ai/chat/completions \
  -H "Authorization: Bearer $HELICONE_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<model-id>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq '.choices[0].message.content'
```

Model ids come from the registry at <https://helicone.ai/models>; the gateway also forwards models not yet in the registry, but those route only through your BYOK deployments.

## Credits vs BYOK

Two billing methods, called Pass-Through Billing (PTB, Helicone credits, no provider account needed, docs say 0% markup) and Bring Your Own Keys (BYOK, billed by the provider directly; add keys at Provider Settings). With both configured, the gateway tries PTB first and falls back to BYOK on failure such as insufficient credits, and returns the most actionable error when both fail. Provider routing, by contrast, tries your BYOK keys first and Helicone's managed keys as the fallback; read both pages before relying on an order. Ask the user before adding credits or provider keys, and check the dashboard for live rates.

## Regions

The dashboard and API keys page exist at `us.helicone.ai`; check the docs for an EU host before assuming one.

## What maintenance mode means for setup

Existing platform features keep working; do not expect new features or fast issue handling. Reconsider before building anything that depends on an unreleased or roadmap item.
