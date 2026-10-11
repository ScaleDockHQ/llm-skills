# Qdrant

Run Qdrant beside a self-hosted LLM stack: Docker install, RAM and disk sizing, memory tiers and quantization, API keys and TLS, snapshots, upgrades, teardown, and the LiteLLM embedding and Open WebUI wiring.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill qdrant
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **Auth is off by default.** Bind to loopback, set a key, add TLS.
- **Never expose port 6335.**
- **Snapshot before upgrades and deletes.**

## References

- [`install.md`](references/install.md), [`sizing.md`](references/sizing.md), [`config.md`](references/config.md), [`api.md`](references/api.md), [`security.md`](references/security.md), [`updating.md`](references/updating.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/llm-stack.md`](references/combos/llm-stack.md).

## Companion skills

- `text-embeddings-inference`, `infinity`, `litellm`, `pgvector`, `mcp-servers`.

## License

MIT
