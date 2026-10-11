# Vercel AI SDK: updating

> Verified against Vercel AI SDK ai@7.0.137 (@ai-sdk/openai 4.0.91, @ai-sdk/openai-compatible 3.0.67, @ai-sdk/anthropic 4.0.78, @ai-sdk/otel migration notes), 2026-10-11

Check the newest versions, then pin all `ai` and `@ai-sdk/*` packages together; mixing majors causes type errors in the provider interface.

```bash
for p in ai @ai-sdk/openai @ai-sdk/openai-compatible @ai-sdk/anthropic; do echo "$p $(pnpm view $p version)"; done
pnpm ls ai @ai-sdk/openai @ai-sdk/openai-compatible @ai-sdk/anthropic 2>/dev/null
```

## v6 to v7 changes that touch custom endpoints

Upstream guide: https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0 (codemods exist; read the codemod table first).

| Change                                            | Effect on a self-hosted setup                                                                                    |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Node.js 22 or later; ESM only                     | Remove `require()`, set `"type": "module"`, bump CI Node.                                                        |
| `system` option renamed `instructions`            | Rename; `{role:"system"}` inside `messages` or `prompt` is rejected by default.                                  |
| `stepCountIs` renamed `isStepCount`               | Needed for every tool loop.                                                                                      |
| `fullStream` renamed `stream`                     | Update code that reads raw parts.                                                                                |
| Usage includes all steps; `reasoningTokens` moved | Use `usage.outputTokenDetails.reasoningTokens`.                                                                  |
| Request and response bodies excluded by default   | Opt in with `include` when debugging what was sent to your endpoint.                                             |
| OpenTelemetry moved to `@ai-sdk/otel`             | Install it and call `registerTelemetry(new OpenTelemetry())`; telemetry is on once an integration is registered. |
| Top-level `reasoning` option                      | Remove overlapping reasoning settings from `providerOptions`; provider options win if both are set.              |
| `experimental_customProvider` removed             | Use `customProvider`.                                                                                            |

Provider-specific notes: OpenAI Responses reasoning summary defaults to detailed; the Anthropic provider dropped `providerMetadata.anthropic.cacheCreationInputTokens`.

## Procedure

- [ ] Branch; note current versions and run the tests plus `scripts/probe.sh` for each alias.
- [ ] Run the upstream codemods, then `tsc --noEmit`.
- [ ] Re-test tools, `Output.object` and streamed usage per alias; behavior depends on the engine, not the SDK.
- [ ] Roll back by reverting the lockfile; there is no data to migrate.

## Official links

- https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0
- https://github.com/vercel/ai/releases
- https://www.npmjs.com/package/ai
