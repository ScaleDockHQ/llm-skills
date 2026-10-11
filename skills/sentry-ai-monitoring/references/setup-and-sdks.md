# Sentry AI monitoring: setup and SDKs

> Verified against Sentry docs "Agents" (Agent Tracing), sentry-sdk 2.71.0 and @sentry/node 11.6.0, 2026-10-11

Sentry's AI monitoring is now called Agent Tracing, under Explore, Agents (older URLs under `/product/insights/ai/` redirect). It is built on Sentry spans with `gen_ai.*` attributes, so it sits next to errors, logs and normal traces. It has tabs for Conversations, Traces and LLM Calls, plus Overview, Models and Tools dashboards. MCP server monitoring is a separate page.

## Choose where Sentry runs

| Option             | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sentry SaaS        | Third-party hosting; decide content capture first (`references/privacy-and-sampling.md`). Check the pricing page for current quotas; do not assume free usage.                                                                                                                                                                                                                                                                                                                                             |
| Self-hosted Sentry | Docker Compose on a Linux host (docs minimum: 4 cores, 16 GB RAM plus 16 GB swap, 20 GB disk), `./install.sh` from a tagged release of `getsentry/self-hosted`, no guarantees, Fair Source (FSL) license. Seer and other AI and ML features are closed source and not available. Python SDK 2.64.0 or newer sends gen_ai spans as standalone items; on self-hosted set `stream_gen_ai_spans=False` if they are not ingested. Conversations need the streaming mode, so check it works before promising it. |

Create one Sentry project per AI-enabled repository and use its DSN. The DSN is a public ingestion key, but still keep it in an environment variable rather than in code.

## Python: an app calling a local OpenAI-compatible server

```bash
pip install 'sentry-sdk==2.71.0' openai
```

```python
import os
import sentry_sdk
import sentry_sdk.ai
from sentry_sdk.integrations.openai import OpenAIIntegration
from openai import OpenAI

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    traces_sample_rate=1.0,                 # production: a traces_sampler, see references/privacy-and-sampling.md
    send_default_pii=False,                 # True captures prompts and responses
    integrations=[OpenAIIntegration(include_prompts=False)],
)

client = OpenAI(base_url="http://127.0.0.1:8000/v1", api_key="local")   # vLLM, llama-server, SGLang; Ollama :11434/v1

sentry_sdk.ai.set_conversation_id("conv_abc123")        # groups a chat in Conversations
sentry_sdk.set_user({"id": "user_123"})                 # fills the Conversations User column

with sentry_sdk.start_span(op="gen_ai.invoke_agent", name="invoke_agent support-bot") as span:
    span.set_data("gen_ai.agent.name", "support-bot")
    client.chat.completions.create(model="<served-model-name>", messages=[{"role": "user", "content": "ping"}])
```

Notes from the docs:

- Supported AI libraries are instrumented automatically when installed and `sentry_sdk.init` runs. The OpenAI integration needs openai 1.0 or newer, Python 3.9 or newer and sentry-sdk 2.41.0 or newer, traces `responses.create`, `chat.completions.create` and `embeddings.create`, and needs `tiktoken` plus `tiktoken_encoding_name` for token counts on streamed chat.
- Data shows in Explore, Traces, AI Spans. The Agents dashboards need an `invoke_agent` span (or a framework integration that creates one).
- Name agents with `gen_ai.agent.name`, or the framework's `name` argument; unnamed agents cannot be filtered or alerted on individually.
- Other integrations: Anthropic, Google Gen AI, OpenAI Agents SDK, LangChain, LangGraph, LiteLLM, Pydantic AI, Hugging Face Hub, Mistral.
- Conversation IDs: some integrations infer them; otherwise set `gen_ai.conversation.id` through `set_conversation_id()` before the AI calls.

## Node

```bash
npm install @sentry/node
```

Node uses `Sentry.init` with the OpenAI, Anthropic, Vercel AI and other integrations; privacy is `sendDefaultPii` plus per-integration `recordInputs` and `recordOutputs`. Read the Node guide under the Agents setup page for the exact integration names at use time; they were not copied here.

## LiteLLM

Two different things exist:

1. **Tracing:** the Python SDK integration `LiteLLMIntegration()` (litellm 1.77.5 or newer, Python 3.8 or newer; traces `completion` and `embedding`, sync and async). It instruments LiteLLM running inside your Python process, so it covers the SDK. Whether it applies to the proxy server was not verified.
2. **Exceptions only:** LiteLLM's own `sentry` callback (`failure_callback: ["sentry"]`, env `SENTRY_DSN`) sends exceptions and breadcrumbs, not agent traces. See `references/otlp-and-gateways.md`.

## Manual spans

For raw clients or engines without an integration, wrap calls yourself. Required attributes from the docs: `sentry.op` or span `op` of `gen_ai.<operation>` (for example `gen_ai.chat`), `gen_ai.operation.name` (`chat`, `embeddings`, `generate_content`, `text_completion`, `invoke_agent`, `execute_tool`), `gen_ai.provider.name`, `gen_ai.request.model`, and token usage `gen_ai.usage.input_tokens` and `gen_ai.usage.output_tokens`. Put system prompts in `gen_ai.system_instructions`, not in the input messages.

## Read-only discovery

```bash
pip show sentry-sdk | grep -E '^(Name|Version)'
curl -fsS https://pypi.org/pypi/sentry-sdk/json | jq -r .info.version
curl -fsS https://registry.npmjs.org/@sentry%2fnode/latest | jq -r .version
```
