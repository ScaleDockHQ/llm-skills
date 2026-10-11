# Milvus

Run Milvus (Lite, single container or Compose standalone) beside a self-hosted LLM stack: requirements, hardened compose, memory math per index, authentication and the insecure defaults to change, backup and one-way upgrades, and the LiteLLM embedding and Open WebUI wiring.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill milvus
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **Defaults are insecure:** auth off, root password `Milvus`, MinIO `minioadmin`.
- **Never publish etcd or MinIO.**
- **Upgrades are one-way; back up first.**

## References

- [`install.md`](references/install.md), [`sizing.md`](references/sizing.md), [`security.md`](references/security.md), [`api.md`](references/api.md), [`updating.md`](references/updating.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/llm-stack.md`](references/combos/llm-stack.md).

## Companion skills

- `text-embeddings-inference`, `infinity`, `litellm`, `qdrant`, `pgvector`.

## License

MIT
