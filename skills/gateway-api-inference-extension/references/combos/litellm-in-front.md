# Combo: LiteLLM in front of the inference gateway

> Verified against Gateway API Inference Extension v1.6.2 docs (AI gateways such as LiteLLM can integrate self-hosted models) and LiteLLM docs (`openai/` provider with `api_base`), 2026-10-11

The inference gateway balances replicas of one model; it does not manage keys, budgets, or provider fallbacks. Put LiteLLM
in front:

```yaml
model_list:
  - model_name: qwen3-32b
    litellm_params:
      model: openai/<served-model-name>
      api_base: http://<gateway-service>.<ns>.svc/v1 # the Gateway's Service/address, not the pods
      api_key: os.environ/INFERENCE_GATEWAY_KEY # only if your Gateway enforces one; else any non-empty value
```

- Raise LiteLLM and Gateway request timeouts together for streaming and long generations.
- Keep one LiteLLM deployment entry per pool; use LiteLLM fallbacks to a hosted provider if the pool is down.
- Skills: `litellm`, `llm-gateway`.
