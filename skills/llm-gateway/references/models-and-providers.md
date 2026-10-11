# Models and providers

> Verified against LiteLLM v1.105.0 (docs: proxy/configs, proxy/load_balancing, providers/openai_compatible, completion/drop_params, model_prices_and_context_window.json), 2026-10-11

## How it plugs into this stack

- One `model_list` entry per alias in `assets/litellm-config.yaml`: alias in `model_name`, `<provider>/<id>` in `model`, `api_base` ending in `/v1` for `openai/` backends, `api_key: os.environ/NAME` (or `"none"` for local engines).
- Every self-hosted or aliased model declares `model_info` (`max_input_tokens`, `max_output_tokens`, `supports_function_calling`, `supports_vision`, `supports_reasoning`, `mode`) and explicit `input_cost_per_token: 0` / `output_cost_per_token: 0` in `litellm_params`.
- `drop_params: true` globally or per deployment; `additional_drop_params` for named fields.
- Pitfall: `/v1/models` is OpenAI-shaped and omits `model_info`; clients read context and capabilities from their own config (`llm-clients` skill).

Depth: install the litellm skill (npx skills add ScaleDockHQ/llms-skills --skill litellm)
