# Inspect AI: models, endpoints and gateways

> Verified against inspect-ai 0.3.278 (docs: providers, models, reasoning, options), 2026-10-11

Models are named `<provider>/<model>`. Pick the provider by where the model runs. `inspect eval ... --model` accepts a comma-separated list.

## Which provider for which target

| Target                                                                                         | Model string                                                              | Env vars (from the docs)                                                          |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| vLLM server you already run                                                                    | `vllm/<served-model-name>`                                                | `VLLM_BASE_URL` (include `/v1`), `VLLM_API_KEY` (defaults to `local`)             |
| vLLM started by Inspect (slow start)                                                           | `vllm/<hf-repo>`                                                          | `VLLM_DEFAULT_SERVER_ARGS` (JSON); `-M` args become vLLM CLI flags                |
| Raw `/v1/completions` (base models, logprob scoring)                                           | `vllm-completions/<model>` or `openai-api-completions/<provider>/<model>` | as above / `<PROVIDER>_BASE_URL`                                                  |
| Ollama                                                                                         | `ollama/<model>`                                                          | `OLLAMA_BASE_URL` (default `http://localhost:11434/v1`)                           |
| llama-cpp-python server                                                                        | `llama-cpp-python/<model>`                                                | `LLAMA_CPP_PYTHON_BASE_URL` (default `http://localhost:8000/v1`)                  |
| Any other OpenAI-compatible server (llama.cpp `llama-server`, SGLang, TGI, llama-swap, hosted) | `openai-api/<provider-name>/<model>`                                      | `<PROVIDER_NAME>_API_KEY`, `<PROVIDER_NAME>_BASE_URL`; hyphens become underscores |
| LiteLLM proxy                                                                                  | `litellm-proxy/<model_name-from-proxy-config>`                            | `LITELLM_PROXY_BASE_URL`, `LITELLM_PROXY_API_KEY`                                 |
| OpenRouter                                                                                     | `openrouter/<model>`                                                      | `OPENROUTER_API_KEY`                                                              |
| SGLang (managed)                                                                               | `sglang/<model>`                                                          | see providers doc                                                                 |
| Hugging Face local                                                                             | `hf/<repo>`                                                               | `HF_TOKEN`; needs `torch transformers`                                            |

`<provider-name>` in `openai-api/` is a label you choose; it only decides which env var names are read. Example for a llama.cpp server:

```bash
export LLAMACPP_BASE_URL=http://localhost:8080/v1
export LLAMACPP_API_KEY="$(cat ~/.config/llm/llamacpp.key)"   # a 0600 file
inspect eval task.py --model openai-api/llamacpp/<served-model-id> --limit 5
```

Model IDs come from `curl -s $BASE/models | jq -r '.data[].id'`.

## Existing vLLM server

```bash
export VLLM_BASE_URL=http://localhost:8000/v1
export VLLM_API_KEY="$(cat ~/.config/llm/vllm.key)"
inspect eval task.py --model vllm/<served-model-name> --limit 5
```

Or without env vars: `--model-base-url http://localhost:8000/v1`. Passing `-M api_key=...` puts the key in model args that get logged, so prefer the env var.

- `use_chat_template=false` (a `-M` arg, for base models) only works when Inspect starts the server; with `VLLM_BASE_URL` set `--chat-template` on the server instead.
- Prompt logprobs (perplexity scorers) need `--prompt-logprobs 1` and no streaming.

## Reasoning models

- vLLM: set the parser through `-M`, for example `-M reasoning_parser=qwen3`, and toggle thinking with chat-template kwargs: `-M default_chat_template_kwargs='{"enable_thinking": true}'` or per request `-M extra_body='{"chat_template_kwargs": {"enable_thinking": true}}'`. These `-M` examples apply when Inspect starts vLLM; for a server you started yourself, configure the parser on the server (vLLM reasoning docs: https://docs.vllm.ai/en/stable/features/reasoning_outputs.html).
- `--reasoning-effort` is a no-op for open-weights models that have no adjustable effort.
- When the model emits `<think></think>` itself, Inspect captures it as reasoning without server config. A `match()` scorer reads the final answer, so thinking text that leaks into the answer can cause false negatives; check five transcripts.
- `--extra-body` and `--extra-headers` take JSON or YAML mappings, for example `--extra-body '{"chat_template_kwargs": {"enable_thinking": false}}'`, and are not supported by every provider.

## Gateways

LiteLLM proxy: Inspect reads the proxy's `/model/info` to find the upstream model behind each `model_name`. If a deployment uses an opaque name Inspect cannot resolve a context window and fails at model creation; add `model_info.base_model` to the proxy deployment as the docs recommend. Virtual keys work and only list the models they can use.

## Generation settings that matter for comparisons

`--temperature`, `--top-p`, `--max-tokens`, `--seed`, `--max-retries` (default unlimited), `--timeout` (default none), `--attempt-timeout`. Put them in a `--generate-config` YAML or in `--run-config` so both sides of a comparison share them.

Official sources: https://inspect.aisi.org.uk/providers.html, https://inspect.aisi.org.uk/reasoning.html, https://inspect.aisi.org.uk/options.html
