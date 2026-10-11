# Example: local DGX Spark primary with cloud overflow and frontier models

> Verified against LiteLLM v1.105.0 docs (configs, fallbacks, provider budgets, health), vLLM v0.31.0 docs, Together AI and Anthropic API docs, AWS Bedrock docs, 2026-10-11

An anonymized team of eight engineers. Hosts, addresses and numbers are placeholders; no prices or benchmark figures are given.

## Starting point (from discovery)

- `node-a` (10.0.0.1): a DGX Spark running vLLM with one open model, exposed on the private network only.
- LiteLLM gateway on `node-b`, published as `https://llm.example.com` behind TLS.
- AWS account authenticated (`aws sts get-caller-identity` shows `<account-id>`), default region `<region>`.
- Keys present by name: `ANTHROPIC_API_KEY`, `TOGETHERAI_API_KEY`, `LITELLM_MASTER_KEY`. No `OPENAI_API_KEY`.
- Clients: coding agents and an internal chat app, all pointed at `https://llm.example.com/v1`.

## Requirements

- Internal source code is "confidential": allowed on the Spark and on providers with no-training terms; a small set of customer datasets is restricted to on-prem only.
- Daily load fits the Spark most of the day, but release weeks overflow it.
- Complex refactors need a frontier model.
- Monthly cloud spend ceiling agreed with finance.

## Design

| Alias           | Primary        | Fallback chain                                       | Data allowed              |
| --------------- | -------------- | ---------------------------------------------------- | ------------------------- |
| `chat`          | vLLM on node-a | same open model on Together AI → frontier chat model | Internal, confidential    |
| `private`       | vLLM on node-a | none                                                 | Restricted (on-prem only) |
| `frontier-code` | Anthropic API  | same model family on Bedrock in `<region>`           | Internal, confidential    |

Why this shape:

- **Overflow keeps behavior close**: the first fallback for `chat` is the same open model on an open-model API, so answers stay consistent during bursts.
- **Frontier fallback across providers**: if the Anthropic API rate-limits, Bedrock in the team's own AWS account serves the same model family under IAM, with geographic (not global) routing.
- **Restricted data has its own alias** with no fallback, and a virtual key that can reach only `private`.

## Steps taken (cloud-llms workflows)

1. **Pick a tier**: frontier API + hyperscaler for `frontier-code`; managed open-model API for overflow.
2. **Provision**: Anthropic workspace key and Together AI key stored in the secret manager; IAM role for the gateway host with `bedrock:InvokeModel` on one inference profile; Bedrock quota checked in Service Quotas and an increase requested before release week.
3. **Budgets before traffic**: AWS Budget with alerts at 50/80/100%; Anthropic spend limit; LiteLLM `provider_budget_config` for `anthropic` and `together_ai`, and `max_budget` on the overflow deployment. Database configured so key budgets enforce.
4. **Connect to the gateway**: entries added from `assets/litellm-hybrid.yaml` (OpenAI, Gemini, Vertex and Azure entries deleted as unused).
5. **Secure**: engines stay on the private network; only the gateway is public; logging set to metadata-only for `private`.
6. **Benchmark**: `scripts/bench.sh` against `chat` through the gateway and directly against node-a, at concurrency 1 and 16, recorded with date and region; repeated against `chat-overflow` to confirm acceptable latency from the gateway's location.
7. **Test fallbacks**: stopped vLLM on node-a in a maintenance window and confirmed `chat` was served by the overflow deployment (gateway logs show the backend). Mock fallback flags were not used because the proxy ignores them.
8. **Operate**: weekly check of provider spend vs budget; quarterly re-decision with `choosing-llm-hosting`.

## Gateway excerpt

```yaml
model_list:
  - model_name: chat
    litellm_params:
      model: hosted_vllm/<served-model-name>
      api_base: http://10.0.0.1:8000/v1
      api_key: os.environ/LOCAL_VLLM_API_KEY
      stream_timeout: 30
  - model_name: private
    litellm_params:
      model: hosted_vllm/<served-model-name>
      api_base: http://10.0.0.1:8000/v1
      api_key: os.environ/LOCAL_VLLM_API_KEY
  - model_name: chat-overflow
    litellm_params:
      model: together_ai/<org>/<same-open-model>
      api_key: os.environ/TOGETHERAI_API_KEY
  - model_name: frontier-code
    litellm_params:
      model: anthropic/<claude-model-id>
      api_key: os.environ/ANTHROPIC_API_KEY
  - model_name: frontier-code-bedrock
    litellm_params:
      model: bedrock/<geographic-inference-profile-id>
      aws_region_name: <region>

router_settings:
  fallbacks:
    - chat: ["chat-overflow"]
    - frontier-code: ["frontier-code-bedrock"]
  provider_budget_config:
    anthropic:
      budget_limit: <monthly-usd>
      time_period: 1mo
    together_ai:
      budget_limit: <monthly-usd>
      time_period: 1mo

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
```

## Outcome

- Clients changed nothing: same base URL, same aliases.
- Release weeks no longer queue on the Spark; overflow spend stays inside the provider budget.
- When a better open model ships, it goes on node-a under a test alias, is evaluated (`llm-evals`), and `chat` is repointed, with the old model kept as a fallback until the next review.

## Related skills

- `self-hosted-llms`: the Spark, vLLM, llama-swap and LiteLLM setup.
- `llm-gateway`: virtual keys per data class, routing strategies, API bridging.
- `choosing-llm-hosting`: the decision record behind this design.
