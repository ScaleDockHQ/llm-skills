# Vercel AI SDK: custom endpoints

> Verified against Vercel AI SDK ai@7.0.137 (@ai-sdk/openai 4.0.91, @ai-sdk/openai-compatible 3.0.67, @ai-sdk/anthropic 4.0.78, ollama-ai-provider-v2 4.0.1), 2026-10-11

Pick the provider package by the API the endpoint serves, not by the engine's name.

| Endpoint serves                                                          | Package and factory                                  | Base URL shape                                               | Model factory                                    |
| ------------------------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------ |
| Chat Completions (vLLM, llama-server, LiteLLM, llama-swap, Ollama `/v1`) | `@ai-sdk/openai-compatible` `createOpenAICompatible` | `http://host:port/v1`                                        | `provider("alias")` or `provider.chatModel(...)` |
| Chat Completions, using the OpenAI provider                              | `@ai-sdk/openai` `createOpenAI`                      | `http://host:port/v1`                                        | `openai.chat("alias")` (not `openai("alias")`)   |
| Responses (`/v1/responses`: vLLM, LiteLLM, Ollama)                       | `@ai-sdk/openai` `createOpenAI`                      | `http://host:port/v1`                                        | `openai("alias")` or `openai.responses("alias")` |
| Anthropic Messages (`/v1/messages`)                                      | `@ai-sdk/anthropic` `createAnthropic`                | `http://host:port/v1` (**includes** `/v1`)                   | `anthropic("alias")`                             |
| Ollama native `/api/chat`                                                | community `ollama-ai-provider-v2` or `ai-sdk-ollama` | `http://host:11434/api` (default of `ollama-ai-provider-v2`) | `ollama("model")`                                |

Upstream states that `openai(id)` uses the Responses API since AI SDK 5 and that a chat-only base URL needs `openai.chat(id)` or the OpenAI-compatible provider.

## Install

```bash
pnpm add ai @ai-sdk/openai-compatible zod     # Chat Completions backends
pnpm add @ai-sdk/anthropic                    # only for /v1/messages
pnpm add @ai-sdk/openai                       # only for /v1/responses
```

AI SDK 7 is ESM only and needs Node.js 22 or later; set `"type": "module"` in `package.json`.

## Base URLs per backend

| Backend                  | OpenAI-compatible base URL  | Anthropic base URL for the AI SDK (with `/v1`) | Notes                                                                                        |
| ------------------------ | --------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------- |
| vLLM `vllm serve`        | `http://host:8000/v1`       | `http://host:8000/v1`                          | Serves `/v1/messages` too. Tools need `--enable-auto-tool-choice --tool-call-parser <name>`. |
| llama.cpp `llama-server` | `http://host:8080/v1`       | `http://host:8080/v1`                          | `/v1/messages` supported; tool use needs `--jinja`. Key: `--api-key-file`.                   |
| Ollama                   | `http://host:11434/v1`      | `http://host:11434/v1`                         | Native `/api` is separate. Needs no key by default.                                          |
| LiteLLM proxy            | `https://gw.example.com/v1` | `https://gw.example.com/v1`                    | Model ids are `model_name` aliases from `config.yaml`.                                       |
| llama-swap               | `http://host:8080/v1`       | `http://host:8080/v1`                          | Model ids are the keys under `models:` in its config.                                        |

Confirm the shape from the endpoint, never guess: `curl -fsS "$BASE/models" -H "Authorization: Bearer $(cat ~/.config/llm/key)" | jq -r '.data[].id'` (use a `0600` key file).

## OpenAI-compatible (default choice)

```ts
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { generateText } from "ai";

export const llm = createOpenAICompatible({
  name: "selfhosted", // provider name; also the providerOptions key
  baseURL: process.env.LLM_BASE_URL!, // e.g. http://gpu1:8000/v1
  apiKey: process.env.LLM_API_KEY, // adds Authorization: Bearer <key>
  includeUsage: true, // usage in streamed responses
  supportsStructuredOutputs: true, // only if the backend enforces json_schema
});

const { text, usage } = await generateText({
  model: llm("coder"), // alias exposed by /v1/models
  prompt: "ping",
});
```

Provider options from upstream: `baseURL`, `apiKey`, `headers`, `queryParams`, `fetch`, `includeUsage`, `supportsStructuredOutputs`, `supportsMultiPartToolContent`, `supportedUrls`, `transformRequestBody`, `metadataExtractor`. Backend-specific request fields (for example vLLM `chat_template_kwargs`, `top_k`) go through `transformRequestBody`, or pass them under `providerOptions: { selfhosted: {...} }` where the provider supports it; test that the field reaches the server.

## Anthropic Messages

```ts
import { createAnthropic } from "@ai-sdk/anthropic";

export const claude = createAnthropic({
  baseURL: process.env.LLM_BASE_URL!, // http://gw:4000/v1  (includes /v1)
  authToken: process.env.LLM_API_KEY, // sends Authorization: Bearer
});
// or apiKey -> x-api-key header. Only one of apiKey or authToken is required.
```

`apiKey` defaults to `ANTHROPIC_API_KEY`, `authToken` to `ANTHROPIC_AUTH_TOKEN`. Pick the header your gateway checks (confirm with `scripts/probe.sh anthropic`, which sends both). Do not rely on ambient `ANTHROPIC_API_KEY` in CI: an unrelated real key then goes to your endpoint.

## Responses API

```ts
import { createOpenAI } from "@ai-sdk/openai";
const openai = createOpenAI({
  baseURL: process.env.LLM_BASE_URL!,
  apiKey: process.env.LLM_API_KEY,
});
const model = openai("alias"); // Responses
const chatOnly = openai.chat("alias"); // Chat Completions
```

`OPENAI_BASE_URL` and `OPENAI_API_KEY` are read when the options are omitted. Use `openai.chat` for any endpoint that returns 404 on `/responses`.

## Authentication without printing secrets

- Read the key from `process.env` (loaded from a `0600` env file, a secret manager or the platform's secret store); never commit it and never log the provider config object.
- Local endpoints with no auth still need a non-empty key on some gateways; use a placeholder env var such as `LLM_API_KEY=none` only against unauthenticated engines.
- Custom headers (for example Cloudflare Access service tokens): `headers: { "CF-Access-Client-Id": process.env.CF_ID!, "CF-Access-Client-Secret": process.env.CF_SECRET! }`.
- In browsers keys must not appear; call the endpoint from a route handler and stream the result.

## Model-name mapping

The model id string is sent verbatim as `model`. Use what `GET /v1/models` returns: vLLM's `--served-model-name`, LiteLLM `model_name`, llama-swap model keys, Ollama tags such as `qwen3:8b`.

For stable app names and default settings, wrap with `customProvider` (documented under Provider and Model Management):

```ts
import {
  customProvider,
  wrapLanguageModel,
  defaultSettingsMiddleware,
} from "ai";

import { llm } from "./llm";

export const models = customProvider({
  languageModels: {
    fast: llm("qwen3-8b"),
    smart: wrapLanguageModel({
      model: llm("qwen3-235b"),
      middleware: defaultSettingsMiddleware({ settings: { temperature: 0.2 } }),
    }),
  },
  fallbackProvider: llm, // unknown names pass through to the endpoint
});
// models.languageModel("fast")
```

Avoid aliases that look like real OpenAI model names when using `createOpenAI`: the OpenAI provider recognises reasoning models by id and, for those, converts `system` messages to `developer` (`providerOptions.openai.systemMessageMode` overrides this; `forceReasoning` forces the opposite case). Chat-only engines can reject the `developer` role.

## Plain string model ids

`model: "anthropic/claude-sonnet-5.5"` resolves through the global default provider, which is the Vercel AI Gateway unless you register another one. Against a self-hosted endpoint always pass a provider model object. A missing `AI_GATEWAY_API_KEY` error from code you thought pointed at vLLM means a string id slipped through.

## Probe before coding

```bash
BASE_URL=http://gpu1:8000/v1 MODEL=coder KEY_FILE=~/.config/llm/key skills/vercel-ai-sdk/scripts/probe.sh openai
BASE_URL=http://gpu1:8000 MODEL=coder KEY_FILE=~/.config/llm/key skills/vercel-ai-sdk/scripts/probe.sh anthropic
```

## Official links

- https://ai-sdk.dev/providers/openai-compatible-providers
- https://ai-sdk.dev/providers/ai-sdk-providers/openai
- https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- https://ai-sdk.dev/providers/community-providers/ollama
- https://ai-sdk.dev/docs/ai-sdk-core/provider-management
- https://github.com/vercel/ai
