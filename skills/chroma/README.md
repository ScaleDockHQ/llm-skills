# Chroma

Run Chroma beside a self-hosted LLM stack: Docker install, RAM sizing, an auth proxy (v1 has no built-in auth), the OpenAI-compatible embedding function via LiteLLM or TEI, backups, upgrades, teardown.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill chroma
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **No built-in auth: loopback plus a token proxy.**
- **Keep `allow_reset` false.**
- **Back up before upgrades.**

## References

- [`install.md`](references/install.md), [`sizing.md`](references/sizing.md), [`security.md`](references/security.md), [`api.md`](references/api.md), [`updating.md`](references/updating.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/llm-stack.md`](references/combos/llm-stack.md).

## Companion skills

- `text-embeddings-inference`, `infinity`, `litellm`, `qdrant`, `pgvector`.

## License

MIT
