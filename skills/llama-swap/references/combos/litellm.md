# llama-swap behind LiteLLM

> Verified against llama-swap v263 and LiteLLM v1.105.0 (docs.litellm.ai response_api and openai_compatible pages, litellm source), 2026-10-11

LiteLLM adds per-user keys, budgets, retries and an Anthropic/Responses front door; llama-swap does the model lifecycle. Run both on loopback and expose only LiteLLM.

## Config

```yaml
# litellm-config.yaml
model_list:
  - model_name: qwen-coder # name clients use
    litellm_params:
      model: openai/qwen-coder # llama-swap model ID, openai/ prefix
      api_base: http://127.0.0.1:8080/v1
      api_key: "none" # llama-swap has no apiKeys on loopback; any non-empty value
      use_chat_completions_api: true # bridge /v1/responses to chat completions
```

One `model_list` entry per llama-swap ID, including `setParamsByID` aliases (for example `gpt-oss-high`), so variants need no LiteLLM callbacks. The master key comes from the environment (`LITELLM_MASTER_KEY`), never from the file.

## Rules

- If llama-swap has `apiKeys`, put the key in `api_key: os.environ/LLAMA_SWAP_KEY`.
- Give clients LiteLLM timeouts above the longest cold swap; add `sendLoadingState: true` in llama-swap so streams show progress.
- Duplicate model IDs between LiteLLM and llama-swap are fine; LiteLLM chooses the deployment, llama-swap the process.
- Health: `GET /health` on llama-swap, `/health/liveliness` on LiteLLM. Use the `litellm` skill for gateway depth.

Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
