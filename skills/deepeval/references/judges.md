# DeepEval: configuring the judge model

> Verified against deepeval 4.2.8 (docs: command-line-interface, environment-variables, integrations/models vllm, ollama, litellm, guides-using-custom-llms), 2026-10-11

LLM-as-a-judge metrics (GEval, AnswerRelevancy, Faithfulness, ...) call a judge model and need valid JSON back. With no provider selected, each model family falls back to OpenAI, so set the judge explicitly.

## Selecting a provider

`deepeval set-<provider> [flags] [--save=dotenv[:path]]` selects the provider for all metrics; `unset-<provider>` reverts. Only one `USE_*` flag per family (LLM judge, embeddings, text-to-speech, speech-to-text) is active. Providers for the judge: `set-openai`, `set-azure-openai`, `set-anthropic`, `set-bedrock`, `set-ollama`, `set-local-model`, `set-grok`, `set-moonshot`, `set-deepseek`, `set-gemini`, `set-litellm`, `set-portkey`, `set-openrouter`. Explicit constructor arguments (`model=...`) always win over environment settings. `deepeval diagnose` shows what is active.

## Local OpenAI-compatible server (vLLM, llama.cpp, LM Studio, gateway)

```bash
deepeval set-local-model --model=<served-model-id> --base-url="http://localhost:8000/v1/" --save=dotenv
```

You are prompted for an API key (any placeholder works for open servers). Equivalent environment: `USE_LOCAL_MODEL=1`, `LOCAL_MODEL_NAME`, `LOCAL_MODEL_BASE_URL`, `LOCAL_MODEL_API_KEY` (put the key in a `0600` `.env.local`). In code:

```python
from deepeval.metrics import AnswerRelevancyMetric
from deepeval.models import LocalModel

judge = LocalModel(model="<served-model-id>", base_url="http://localhost:8000/v1/",
                   api_key="local", temperature=0)      # api_key from the environment in real use
metric = AnswerRelevancyMetric(model=judge)
```

`LocalModel` options: `model` (`LOCAL_MODEL_NAME`), `api_key` (`LOCAL_MODEL_API_KEY`), `base_url` (`LOCAL_MODEL_BASE_URL`), `temperature` (`TEMPERATURE`, else 0.0), `format` (`LOCAL_MODEL_FORMAT`, else `"json"`), `generation_kwargs` (forwarded to `chat.completions.create`). Extra kwargs go to the OpenAI client constructor. Revert with `deepeval unset-local-model`. Model IDs: `curl $BASE/models | jq -r '.data[].id'`.

## Ollama

```bash
ollama run <model>                                   # make sure it is pulled and serving
deepeval set-ollama --model=<model> --base-url="http://localhost:11434"
```

Note the Ollama page documents the host as `http://localhost:11434` (no `/v1`) and the `LOCAL_MODEL_BASE_URL` variable for a custom host. `unset-ollama` reverts. Small models often fail the JSON requirement; see below.

## LiteLLM (gateway or proxy)

`pip install litellm` first (not installed with DeepEval). `deepeval set-litellm --model=openai/<id> --base-url="https://gateway.example"`; the provider prefix is mandatory. In code `LiteLLMModel(model=..., base_url=..., api_key=..., temperature=0)`. Without `api_key`, DeepEval tries `LITELLM_API_KEY`, `LITELLM_PROXY_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY` in that order, so a stray `OPENAI_API_KEY` can be picked up; pass the key explicitly or unset the others.

## Hosted judges

`deepeval set-openai --model=<id>`, `set-anthropic -m <id>`, `set-azure-openai`, `set-bedrock`, `set-gemini`: each reads its provider's key from the environment or `--save=dotenv`. Token costs are USD per token (`$3 / MTok` is `0.000003`) via `-i`/`-o` flags or `*_COST_PER_*_TOKEN`; do not hardcode prices in committed files. Hosted judges send test inputs and outputs to the provider; get approval for private data.

## Custom judge class

Wrap any client by subclassing `DeepEvalBaseLLM`. `generate(prompt, schema=None)` must return a string without a schema, and when DeepEval passes a Pydantic `schema` it must return a valid `schema` instance; accepting `schema` is required for metrics with structured output such as `FaithfulnessMetric` (omitting it fails with a confusing `AttributeError`). Implement `a_generate`, `get_model_name` and `load_model`. Use JSON-confinement tooling (the guide covers `lm-format-enforcer` and `instructor`) when the judge is a small open model. Guide: https://deepeval.com/guides/guides-using-custom-llms.

## Reliability rules for judges

- "Evaluation LLM outputted an invalid JSON" means the judge cannot follow the schema: use a stronger model, enable structured output on the server (for vLLM, see the `vllm` skill), or use the schema-aware custom class.
- Thinking is disabled by default for judges (`DEEPEVAL_MODEL_THINKING=1` enables it on models that expose a thinking parameter and raises the output budget). For reasoning judges served locally, a parser that moves thinking out of `content` avoids JSON corruption.
- Pin the judge's model id, `temperature=0`, and use a different, stronger model than the system under test. Self-judging inflates scores.
- Lower concurrency for a small server: `AsyncConfig(max_concurrent=...)` or `-n` / throttle settings (`references/running-and-ci.md`).

Official sources: https://deepeval.com/docs/command-line-interface, https://deepeval.com/integrations/models/vllm, https://deepeval.com/integrations/models/ollama, https://deepeval.com/integrations/models/litellm
