# Hyperbolic serverless inference is retired

> Verified against hyperbolic.ai/docs faq/inference-models, llms.txt index (no inference pages), changelog, docs.litellm.ai/docs/providers/hyperbolic (listing only), 2026-10-11

## What the vendor says

The Inference and models FAQ (https://hyperbolic.ai/docs/faq/inference-models) states:

- The serverless inference API and the playground have been retired. The models that used to be listed are gone.
- A new inference product is being built, with no release date.
- Requests to the old inference models no longer work, even with a valid API key. Old code keeps failing until a new product launches.
- Credit can still be used for GPU rentals and storage.
- Suggested alternative: rent an on-demand GPU and run an open model with your own serving stack.
- To shape the new product, email support@hyperbolic.ai with the models used, request volume and use case.

The old inference overview and quickstart paths now redirect to that FAQ. The docs index (`https://hyperbolic.ai/docs/llms.txt`) lists GPU, billing, account and rentals pages only.

## What this means for agents

- Do not recommend `https://api.hyperbolic.xyz/v1/chat/completions`, the `/v1/image/generation` endpoint, or per-token Hyperbolic models. The host `api.hyperbolic.xyz` still answers (it is the legacy host of the GPU API), but a 401 from it without a key does not show that inference works.
- Old model IDs in code (for example `meta-llama/...` served by Hyperbolic) need to be replaced.
- LiteLLM still lists a `hyperbolic/` provider, with `HYPERBOLIC_API_KEY`, aimed at that API. Treat it as not working until the vendor announces a new product. Remove those entries from gateway configs.
- If someone reports "my Hyperbolic key returns errors or empty model lists", the cause is the retirement, not the key. The exact error body was not captured here: unverified, check the FAQ page.

## Migration paths

1. **Another hosted open-model provider.** Load `cloud-llms` (`npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`). It covers managed open-model APIs and how to wire them into LiteLLM.
2. **Keep Hyperbolic, run it yourself.** Rent a GPU (`SKILL.md` workflow 2), serve the model with `self-hosted-llms`, and expose it through `llm-gateway` with the same model alias your clients already use. The client code then needs only a new base URL and key at the gateway.
3. **Wait for the new product.** Not plannable until a date is published. Check https://hyperbolic.ai/docs/changelog.

## Account tiers and the old free tier

The account docs still mention a free tier with restrictive API rate limits. That tier cannot launch GPUs. After retirement it has no inference to rate-limit, so do not plan around it.
