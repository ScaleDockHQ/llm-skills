# Vercel AI SDK: structured output, tools and streaming

> Verified against Vercel AI SDK ai@7.0.137 (@ai-sdk/openai-compatible 3.0.67), 2026-10-11

Self-hosted models differ from hosted ones in three ways that matter here: JSON enforcement depends on the engine, tool calls depend on a server-side parser, and streamed usage is opt-in.

## Structured output

Use `generateText` or `streamText` with `output`:

```ts
import { generateText, Output } from "ai";
import { z } from "zod";

import { llm } from "./llm";

const { output } = await generateText({
  model: llm("coder"),
  output: Output.object({
    schema: z.object({ city: z.string(), temp_c: z.number() }),
  }),
  prompt: "Weather in Paris as JSON.",
});
```

Variants documented upstream: `Output.text()` (default), `Output.object`, `Output.array`, `Output.choice`, `Output.json` (valid JSON only, no schema check). Structured output counts as a step; when combined with tools, account for it in `stopWhen`.

With `createOpenAICompatible`:

- `supportsStructuredOutputs: true` sends the schema as `response_format` of type `json_schema`; without it the provider sends plain `response_format: {type: "json_object"}`, drops the schema and returns an unsupported-`responseFormat` warning (check `result.warnings`). Enable it only for engines that enforce it (vLLM with its guided decoding, llama-server with grammar from `json_schema`, recent Ollama with `format`/`response_format`). Run `scripts/probe.sh openai` and read the `json_schema` line.
- If the backend ignores `response_format`, the model may still answer in JSON; the SDK validates and throws a type validation or no-object error otherwise. Put the shape in the prompt too, keep temperature low, and catch the error.
- Reasoning models may spend the whole token budget thinking, leaving empty content. Raise `maxOutputTokens`, or turn thinking off in the engine or alias.

## Tool calling

```ts
import { generateText, tool, isStepCount } from "ai";
import { z } from "zod";

const { text, steps } = await generateText({
  model: llm("coder"),
  tools: {
    weather: tool({
      description: "Weather by city",
      inputSchema: z.object({ city: z.string() }),
      execute: async ({ city }) => ({ city, temp_c: 18 }),
    }),
  },
  stopWhen: isStepCount(5),
  prompt: "Weather in Paris? Use the tool.",
});
```

- The SDK sends OpenAI `tools`; the engine must parse the model's output into `tool_calls`. vLLM needs `--enable-auto-tool-choice --tool-call-parser <name>`; llama-server needs `--jinja`; Ollama only for models whose template supports tools. No parser means tool JSON appears as plain text and `toolCalls` stays empty (see `troubleshooting.md`).
- `isStepCount(n)` replaced `stepCountIs(n)` in AI SDK 7. Without `stopWhen` the loop ends after the first model step, so the tool result never reaches the model.
- Tool results containing images or files need `supportsMultiPartToolContent: true` and a backend that accepts content arrays for the `tool` role; the default stringifies them.
- Small models call tools unreliably: reduce the tool count, keep descriptions short, and add one test per alias.

## Streaming

```ts
import { streamText } from "ai";

const result = streamText({
  model: llm("coder"),
  prompt: "Write a haiku.",
  onError: ({ error }) => console.error(String(error)), // errors are suppressed otherwise
});
for await (const t of result.textStream) process.stdout.write(t);
console.log(await result.usage);
```

- `streamText` suppresses errors to avoid crashing servers. Always set `onError`, or a dead endpoint looks like an empty answer.
- Streamed `usage` is empty unless the provider sets `includeUsage: true` (OpenAI-compatible), which asks for `stream_options.include_usage`. Engines that ignore it return no usage chunk.
- AI SDK 7 renamed `fullStream` to `stream`; `textStream` is unchanged.
- Proxies that buffer SSE (Nginx without `proxy_buffering off`, some tunnels) turn streaming into one late chunk; see the gateway or tunnel skill.
- Set `abortSignal` or `timeout` for slow local models; `maxRetries` defaults to retrying failed requests, which repeats expensive prompts on a timeout.

## Reasoning content

Compatible providers surface reasoning tokens returned by the backend (for example DeepSeek R1 style `reasoning_content`) as reasoning parts. Models that inline `<think>...</think>` in `content` need the engine's reasoning parser (vLLM `--reasoning-parser`) or `extractReasoningMiddleware` from `ai` wrapped around the model.

## Official links

- https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data
- https://ai-sdk.dev/docs/foundations/tools
- https://ai-sdk.dev/docs/ai-sdk-core/generating-text
- https://ai-sdk.dev/docs/ai-sdk-core/settings
- https://ai-sdk.dev/docs/ai-sdk-core/middleware
- https://ai-sdk.dev/providers/openai-compatible-providers
