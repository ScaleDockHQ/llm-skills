// Copy to src/llm.ts. Reads settings from the environment; never hardcode keys.
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { customProvider } from "ai";

const baseURL = process.env.LLM_BASE_URL; // e.g. http://gpu1:8000/v1
if (!baseURL) throw new Error("LLM_BASE_URL is not set");

export const llm = createOpenAICompatible({
  name: "selfhosted",
  baseURL,
  apiKey: process.env.LLM_API_KEY, // omit for unauthenticated local engines
  includeUsage: true, // usage in streamed responses
  supportsStructuredOutputs: process.env.LLM_JSON_SCHEMA === "1", // set after scripts/probe.sh passes
});

// Stable app-level names; unknown names fall through to the endpoint.
export const models = customProvider({
  languageModels: {
    default: llm(process.env.LLM_MODEL ?? "coder"),
  },
  fallbackProvider: llm,
});
