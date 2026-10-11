# Quality and capabilities

> Verified against vLLM v0.31.0 docs (OpenAI-compatible server, Claude Code integration), OpenAI, Anthropic and Gemini API docs pages linked below, 2026-10-11

Quality is the requirement most often decided by reputation instead of evidence. This reference explains how to judge the open vs frontier gap for your tasks and which capabilities to check per tier. Running evals is owned by the `llm-evals` skill; this file only frames the decision.

## The open vs frontier gap

- Frontier proprietary models usually lead on the hardest reasoning, long-horizon agentic work, complex coding and multimodal understanding.
- Strong open-weight models are often close enough for classification, extraction, summarization, RAG answering, routine coding help, translation and chat.
- The gap is task-specific and moves with every release. Do not carry over a conclusion from a previous year, or from someone else's tasks.
- Smaller and more heavily quantized models lose quality first on long context, multi-step reasoning, tool use and non-English text. Check those explicitly if they matter (see `model-quantization`).

## Private evals decide

Public leaderboards are useful for building a shortlist. They cannot tell you whether a model handles your documents, your tools and your users. Before deciding:

1. Collect 50-200 real examples per workload (redacted if needed), including hard and edge cases.
2. Define pass criteria: exact match, rubric scoring, unit tests for code, or human review.
3. Run every shortlisted model through the **same gateway** with the same prompts and settings.
4. Record quality, latency (time to first token, tokens per second) and cost per task, not per token.
5. Pick the cheapest tier whose best model clears the bar, with margin.

Hand the method, scoring and quality gates to `llm-evals`.

## Capability checklist

Check each item against the actual model and serving path you plan to use. An open model may support a feature while a given provider or engine does not expose it.

| Capability | What to verify |
| --- | --- |
| Tool / function calling | Parallel calls, `tool_choice`, streaming tool calls. Self-hosted engines often need explicit flags (vLLM: `--enable-auto-tool-choice` with the right `--tool-call-parser`). |
| Structured output | JSON schema enforcement vs "JSON mode". Constrained decoding support in the engine or API. |
| Vision / multimodal | Image and document input, number of images, resolution limits. |
| Long context | Advertised vs usable context. Memory cost of KV cache on self-hosted hardware. Quality at the far end of the window. |
| Reasoning | Thinking or reasoning modes, how reasoning tokens are billed, whether reasoning content is returned. |
| API shape | OpenAI Chat Completions, OpenAI Responses, Anthropic Messages. Coding agents may require a specific one. vLLM serves OpenAI-compatible routes and also implements the Anthropic Messages API; a gateway can bridge the rest (`llm-gateway`). |
| Embeddings and reranking | Separate models; often cheaper to self-host. |
| Batch | Batch APIs exist on OpenAI, Anthropic and Gemini; self-hosted engines batch internally. |
| Prompt caching | Automatic on OpenAI and Gemini 2.5+ models, `cache_control` on Anthropic; prefix caching in vLLM and similar engines. |
| Fine-tuning | Possible on open weights (any tier that runs your weights); limited or unavailable for frontier models. See `fine-tuning-llms`. |
| Determinism and versioning | Can you pin an exact model version? How much notice before deprecation? |

## Matching quality to tiers

- Only a frontier model passes: tier 6 or 7 for that workload. Consider routing only the hard subset there (see `hybrid-patterns.md`).
- A large open model passes: tiers 2-5, decided by cost and data floor.
- A small open model passes: tier 1 for individuals, tier 2 or 4 for teams; it is often cheap enough to self-host on modest hardware.
- Nothing passes: change the task design (retrieval, decomposition, tools) or consider fine-tuning before buying hardware.

## Official links

- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server/
- vLLM tool calling: https://docs.vllm.ai/en/latest/features/tool_calling/
- OpenAI prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- Anthropic prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Gemini context caching: https://ai.google.dev/gemini-api/docs/caching
