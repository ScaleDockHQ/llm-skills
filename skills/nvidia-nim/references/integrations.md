# NVIDIA NIM integrations

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: related software, tool calling, Claude Code and Codex CLI integration pages, Kubernetes pages.

## Gateways and auth

NIM documents no API-key setting for `/v1`. Put it behind a gateway that issues keys, rate limits and
logs. Install `litellm` or `llm-gateway` from this repo for configuration:
`npx skills add ScaleDockHQ/llms-skills --skill litellm`. Bind NIM to loopback or a private network
and let only the gateway reach it.

## OpenAI SDKs and LiteLLM

NIM is OpenAI-compatible: use base URL `http://<host>:8000/v1`, any non-empty key if the client requires
one, and the `model` id from `/v1/models`. In LiteLLM use an `openai/<model-id>` entry with `api_base`.

## Agent clients

- Claude Code and the Anthropic SDK use `/v1/messages` (set `ANTHROPIC_BASE_URL`, a placeholder key and
  `ANTHROPIC_CUSTOM_MODEL_OPTION`); the model needs tool calling.
- Codex CLI has its own integration page in the NIM docs.
- LangChain and LangGraph work through `create_agent` with the tool-calling flags enabled.
- MCP: the client owns MCP; see `references/features.md`.

## Platform

- NIM Operator (`NIMCache`, `NIMService`) and the `nim-llm` Helm chart for Kubernetes.
- KServe, OpenShift (with an SCC troubleshooting page), Run:ai and vGPU deployment pages.
- Cloud pages for AWS, Azure, Google Cloud and Oracle.
- Backend background: `vllm` skill for flags and semantics, since NIM packages vLLM.
- Orchestration at scale: `nvidia-dynamo`. Multi-framework serving: `triton-inference-server`.
