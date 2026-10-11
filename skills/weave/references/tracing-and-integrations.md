# Weave: tracing, local endpoints and integrations

> Verified against weave 0.53.12 (`weave/trace/api.py`, `settings.py`), Weave docs (local models, LiteLLM, OpenAI, disable tracing), 2026-10-11

## Basics

```python
import weave
weave.init("<entity>/<project>")          # call before creating clients you want auto-patched

@weave.op()
def answer(question: str) -> str:
    ...                                    # inputs, outputs, code, latency and nested calls are recorded
```

`weave.init(project_name, *, settings=None, postprocess_inputs=None, postprocess_output=None, attributes=None)`; the `global_*` names and `autopatch_settings` are deprecated. After `weave.init`, supported SDKs (OpenAI, LiteLLM, Anthropic, many agent frameworks) are patched automatically (`implicitly_patch_integrations`, default true). Traces print a link to the UI (`print_call_link`).

## Self-hosted endpoints through the OpenAI client

Any server with an OpenAI-compatible API is traced by pointing the client at it:

```python
import openai, weave
weave.init("<entity>/<project>")
client = openai.OpenAI(base_url="http://node-a:8000/v1", api_key="local")   # vLLM; key can be any string but must be set
```

Ports in this stack: vLLM 8000, llama.cpp `llama-server` (see `llama-cpp`), Ollama 11434 (`/v1`), llama-swap 8080, LiteLLM proxy 4000. Weave's docs list LM Studio, Ollama, GPT4All, llama-cpp-python and llamafile as supported local runners. For engines with a keyed endpoint, pass the real key from a file, not inline. Token usage and model name come from the response; cost needs a price entry for models Weave does not know (custom costs are configurable in the platform; details are in the upstream costs guide).

For a model call outside an OpenAI-compatible runner, wrap your function with `@weave.op()`.

## LiteLLM SDK

`import litellm` then `litellm.completion(...)` (not `from litellm import completion`) so the patch applies; `weave.init` first. For the LiteLLM proxy use the OTLP route (`otlp-and-gateways.md`).

## Attributes, display names, sampling

- `weave.init(..., attributes={"env": "prod", "host": "node-a"})` tags every trace; `weave.attributes({...})` as a context manager tags a block.
- Ops accept `call_display_name`, `tracing_sample_rate` and `enable_code_capture` in the decorator signature (per the SDK source); verify names for your pinned version before relying on them.
- Threads group multi-turn conversations; see the upstream threads guide.

## Disable tracing

`WEAVE_DISABLED=true` (read once at function-definition time), `weave.init(..., settings={"disabled": True})`, or `with tracing_disabled():` (`from weave.trace.context.call_context import tracing_disabled`) for a code block.

## Settings

Every setting is also an environment variable `WEAVE_<NAME>`: `WEAVE_DISABLED`, `WEAVE_PRINT_CALL_LINK`, `WEAVE_LOG_LEVEL`, `WEAVE_CAPTURE_CODE`, `WEAVE_REDACT_PII`, `WEAVE_CAPTURE_CLIENT_INFO`, `WEAVE_CAPTURE_SYSTEM_INFO`, `WEAVE_HTTP_TIMEOUT` (30 s), `WEAVE_RETRY_MAX_ATTEMPTS` (3), `WEAVE_MAX_CALLS_QUEUE_SIZE` (100000), `WEAVE_ENABLE_DISK_FALLBACK`. Environment variables override `settings`.

## Read-only checks

```bash
pip show weave | grep -E '^Version'
WEAVE_PRINT_CALL_LINK=true WEAVE_LOG_LEVEL=DEBUG python3 -c 'import weave; print(weave.__file__)'
```

## Official links

- Local models: https://docs.coreweave.com/products/wandb/weave/guides/integrations/local_models
- LiteLLM: https://docs.coreweave.com/products/wandb/weave/guides/integrations/litellm
- Tracing: https://docs.coreweave.com/products/wandb/weave/guides/tracking/tracing
- Disable tracing: https://docs.coreweave.com/products/wandb/weave/guides/tracking/trace-disable
