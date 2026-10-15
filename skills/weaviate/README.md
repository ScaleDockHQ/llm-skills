# Weaviate

Run Weaviate beside a self-hosted LLM stack: Docker install, memory rule of thumb and quantization, API-key auth and RBAC (anonymous access is on in the quick start), text2vec-openai pointed at LiteLLM or TEI, backups, upgrades, teardown.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill weaviate
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **Turn anonymous access off, bind to loopback.**
- **Expose both 8080 and 50051 or neither.**
- **Back up before upgrades.**

## References

- [`install.md`](references/install.md), [`sizing.md`](references/sizing.md), [`security.md`](references/security.md), [`api.md`](references/api.md), [`updating.md`](references/updating.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/llm-stack.md`](references/combos/llm-stack.md).

## Companion skills

- `text-embeddings-inference`, `infinity`, `litellm`, `qdrant`, `pgvector`.

## License

MIT
