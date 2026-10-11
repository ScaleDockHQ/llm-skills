// Smoke test for an Anthropic-compatible Messages endpoint with the official Node SDK. Never prints the key.
// Usage: LLM_BASE_URL=http://localhost:4000 MODEL=coder LLM_API_KEY_FILE=~/.config/llm/key node assets/client.mjs
// Set AUTH=api_key to send x-api-key instead of Authorization: Bearer. Needs: npm i @anthropic-ai/sdk (Node 20+)
import { readFileSync } from "node:fs";

import Anthropic from "@anthropic-ai/sdk";

const keyFile = process.env.LLM_API_KEY_FILE;
const key =
  process.env.LLM_API_KEY ??
  (keyFile
    ? readFileSync(keyFile.replace(/^~/, process.env.HOME), "utf8").trim()
    : "none");

const client = new Anthropic({
  baseURL: process.env.LLM_BASE_URL ?? "http://localhost:8000", // root, no /v1
  ...(process.env.AUTH === "api_key"
    ? { apiKey: key, authToken: null }
    : { authToken: key, apiKey: null }),
  timeout: 120_000,
  maxRetries: 0,
});

const model = process.env.MODEL;
if (!model) throw new Error("Set MODEL to an id the server exposes");

const msg = await client.messages.create({
  model,
  max_tokens: 32,
  messages: [{ role: "user", content: "Reply with the single word: pong" }],
});
console.log(
  "message:",
  JSON.stringify(msg.content.find((b) => b.type === "text")?.text),
  "stop:",
  msg.stop_reason,
);

const stream = client.messages.stream({
  model,
  max_tokens: 64,
  messages: [{ role: "user", content: "Count to three." }],
});
let text = "";
stream.on("text", (t) => (text += t));
await stream.finalMessage();
console.log("stream:", JSON.stringify(text));
