# Langfuse: prompts, evals and scores

> Verified against Langfuse v4.56.0 (docs: prompt-management/overview, prompt-management/get-started, evaluation/overview, evaluation-methods/scores-via-sdk, api-and-data-platform/features/public-api, features/cli), Python SDK 4.17.0, 2026-10-11

Three features that sit on top of traces. Everything below works on self-hosted OSS unless marked Enterprise.

## Prompt management

Store prompts centrally, version them, and fetch by label at runtime.

```python
from langfuse import get_client

langfuse = get_client()
langfuse.create_prompt(name="movie-critic", type="text",
                       prompt="As a {{criticlevel}} critic, review {{movie}}.",
                       labels=["production"])        # optionally promote to production on create
prompt = langfuse.get_prompt("movie-critic")          # label defaults to production
text = prompt.compile(criticlevel="expert", movie="Dune 2")
chat = langfuse.get_prompt("movie-critic-chat", type="chat")
```

- Versions are immutable; labels (`production`, `staging`, custom) point at versions. Fetch `production` in production code.
- SDKs cache prompts client-side and revalidate in the background, so prompt fetches add no request latency after the first; the server also caches prompts in Redis (`LANGFUSE_CACHE_PROMPT_ENABLED`, TTL 300s default).
- Link prompts to traces to compare quality and cost per prompt version.
- Protected prompt labels are Enterprise.

## Scores

A score is a named value (`NUMERIC`, `CATEGORICAL`, `BOOLEAN` or `TEXT` of 1-500 characters) attached to a trace, observation, session or dataset run. Sources: UI annotation, user feedback, LLM-as-a-judge, code evaluators, or the SDK/API.

```python
langfuse.create_score(trace_id="<trace id>", name="correctness", value=0.9, data_type="NUMERIC")
# inside an active span: langfuse.score_current_span(...) / langfuse.score_current_trace(...)
```

Read scores with Scores API v3 (`GET /api/public/v3/scores`); the v1/v2 score reads return `404` on default v4 write mode.

## Evaluation loop

Upstream frames it as trace, monitor, build datasets, experiment, evaluate:

- **Online**: evaluators score live traces (LLM-as-a-judge, code evaluators, decision-model evaluators). The playground (web) and evaluators (worker) call an LLM API you configure: OpenAI, Azure OpenAI, Anthropic, Google Vertex, Amazon Bedrock, or any OpenAI-compatible endpoint, including a LiteLLM or vLLM gateway. Tracing itself never needs LLM access. The compose file exposes `LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST`, `_IPS` and `_IP_SEGMENTS` for pointing at private hosts; their semantics are not documented on the pages read (unverified), so check the configuration page before relying on them.
- **Offline**: datasets of inputs and expected outputs, then experiments via UI, via the Experiment runner SDK, or via OpenTelemetry. `langfuse/experiment-action` runs experiments in CI and fails the job when a script raises `RegressionError`.
- Dataset run reads moved to the experiments API (`GET /api/public/experiments`, `/experiment-items`); `POST /api/public/dataset-run-items` is deprecated and must not be used with v4.
- v4 note: trace-level and legacy-dataset LLM-as-a-judge evaluators stop running after cutover to `events_only`; recreate them as observation-level evaluators.

## API and CLI

- API reference: https://api.reference.langfuse.com; a self-hosted v4.36.0+ instance serves its own spec at `/api/openapi.yaml` and an interactive reference at `/api/docs`. Auth is HTTP Basic with the project public key as user and secret key as password.
- CLI: `npx @langfuse/cli api <resource> <action>` (package `@langfuse/cli`; the older `langfuse-cli` package is identical until the next major). It reads and writes traces, prompts, datasets and scores. Pass keys through the environment, not arguments.

```bash
curl -fsS -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" "$LANGFUSE_HOST/api/public/projects" | jq '.data[].name'
```

## Boundary with other skills

Choosing an eval methodology, golden sets and CI gates in general belongs to `llm-evals`: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.

## Official links

- https://langfuse.com/docs/prompt-management/overview
- https://langfuse.com/docs/evaluation/overview
- https://langfuse.com/docs/evaluation/evaluation-methods/scores-via-sdk
- https://langfuse.com/docs/api-and-data-platform/features/public-api
- https://langfuse.com/docs/api-and-data-platform/features/cli
- https://langfuse.com/self-hosting/deployment/infrastructure/llm-api
