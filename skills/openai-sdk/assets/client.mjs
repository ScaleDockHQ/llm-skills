// Smoke test for an OpenAI-compatible endpoint with the official Node SDK. Never prints the key.
// Usage: LLM_BASE_URL=http://localhost:4000/v1 MODEL=coder LLM_API_KEY_FILE=~/.config/llm/key node assets/client.mjs
// Needs: npm i openai (Node 20+)
import { readFileSync } from "node:fs";

import OpenAI from "openai";

const keyFile = process.env.LLM_API_KEY_FILE;
const apiKey =
  process.env.LLM_API_KEY ??
  (keyFile
    ? readFileSync(keyFile.replace(/^~/, process.env.HOME), "utf8").trim()
    : "none");

const client = new OpenAI({
  baseURL: process.env.LLM_BASE_URL ?? "http://localhost:8000/v1",
  apiKey,
  timeout: 120_000,
  maxRetries: 0,
});

const models = await client.models.list();
const ids = models.data.map((m) => m.id);
console.log("models:", ids.slice(0, 10).join(", "));
const model = process.env.MODEL ?? ids[0];

const chat = await client.chat.completions.create({
  model,
  messages: [{ role: "user", content: "Reply with the single word: pong" }],
  max_tokens: 16,
});
console.log("chat:", JSON.stringify(chat.choices[0].message.content));

let text = "";
const stream = await client.chat.completions.create({
  model,
  messages: [{ role: "user", content: "Count to three." }],
  max_tokens: 32,
  stream: true,
});
for await (const chunk of stream)
  text += chunk.choices[0]?.delta?.content ?? "";
console.log("stream:", JSON.stringify(text));
