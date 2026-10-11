# LobeHub: model lists and capability flags

> Verified against LobeHub v2.2.19 (docs: self-hosting/advanced/model-list), 2026-10-11

## Syntax

```text
id->deploymentName=displayName<maxToken:vision:reasoning:search:fc:file:imageOutput>,model2,model3
```

- `+id` adds, `-id` hides, `-all` hides every built-in (start with it for a clean list), `id=Name` renames.
- `->deploymentName` is only used by some providers (Azure, Azure AI, Qwen, Spark, Volcengine, Kimi Coding Plan); omit it for self-hosted endpoints.
- In `<...>` the first value is the context size (`maxToken`); the rest are capabilities in any order, colon separated.

| Flag          | Meaning                                                 |
| ------------- | ------------------------------------------------------- |
| `fc`          | Function calling                                        |
| `vision`      | Image input                                             |
| `reasoning`   | Reasoning model                                         |
| `search`      | Web search                                              |
| `video`       | Video input                                             |
| `file`        | File upload (the docs call it hacky, not for daily use) |
| `imageOutput` | Image generation                                        |

Examples:

```bash
OPENAI_MODEL_LIST=-all,+coder=Coder<131072:fc>,+vl=Vision<32768:vision:fc>,+think=Reasoner<65536:reasoning>
OLLAMA_MODEL_LIST=+llama3:8b=Llama 3 8B<8192:fc>
```

Quote values containing `<`, `>` or spaces in `.env` files if your Compose tooling needs it, and balance every `<` with `>`: the upstream docs include examples that omit the closing bracket, which is a typo that breaks parsing.

## Rules

- A flag only tells LobeHub to offer the feature; the endpoint must really support it. `fc` against an engine without a tool parser yields no tool calls or errors (vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama.cpp `--jinja`; see the engine skills).
- `maxToken` is LobeHub's context budget for trimming history, not the engine's limit. Set it at or below the engine's real context.
- `vision` needs a vision-capable model and, for image URLs, server-side fetching (SSRF rules in `docker-networking.md`).
- A model missing from the selector: check the syntax, that the provider is enabled, and that the id is not hidden by `-all`.

## Per provider variable

Each provider has its own `*_MODEL_LIST` (`OPENAI_MODEL_LIST`, `ANTHROPIC_MODEL_LIST`, `OLLAMA_MODEL_LIST`, and so on). An endpoint added via the OpenAI provider uses `OPENAI_MODEL_LIST` only.

## Official links

- Model list syntax: https://lobehub.com/docs/self-hosting/advanced/model-list
