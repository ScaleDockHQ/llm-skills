# Replicate with LiteLLM and clients

> Verified against docs.litellm.ai/docs/providers/replicate, replicate.com/docs reference/client-libraries, Cloudflare AI Gateway provider docs, 2026-10-11

Replicate documents no OpenAI-compatible endpoint. Chat models reach an OpenAI-style client through LiteLLM's `replicate/` provider, which translates calls to the predictions API.

## LiteLLM

```yaml
model_list:
  - model_name: replicate-llama
    litellm_params:
      model: replicate/<owner>/<model> # e.g. a Llama chat model from the Replicate catalog
      api_key: os.environ/REPLICATE_API_KEY
  - model_name: replicate-deployment
    litellm_params:
      model: replicate/deployments/<owner>/<name>
      api_key: os.environ/REPLICATE_API_KEY
```

- The provider's environment variable is `REPLICATE_API_KEY`. The official clients use `REPLICATE_API_TOKEN`. Set both from the same `0600` file if you use both.
- Cold boots of public models can take several minutes (LiteLLM notes 3 to 5). Raise the gateway `timeout` and add a fallback model, or use a deployment with warm instances.
- For image, video and audio models, call the predictions API directly rather than through chat routes, and see `self-hosted-genmedia` for local alternatives.
- Check LiteLLM's page before relying on streaming for a given model.

## Python client

```python
import replicate

output = replicate.run("<owner>/<model>", input={"prompt": "hello"})
```

The client reads `REPLICATE_API_TOKEN`. Output files come back as `FileOutput` objects, which you download right away because the URLs expire.

## Cloudflare AI Gateway

Replicate is a provider in Cloudflare AI Gateway. Proxy Replicate requests via `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/replicate` with your Replicate token in the Authorization header. Use it for caching, logging and rate limits. Check the Cloudflare docs for the current path.

## Webhooks and gateways

If a gateway is on the path for long jobs, use `webhook` on predictions instead of holding a connection. Verify signatures (`references/predictions-api.md`).

## Verify

- [ ] A 16-token request through the gateway returns text.
- [ ] A cold model times out into the fallback instead of failing the client.
