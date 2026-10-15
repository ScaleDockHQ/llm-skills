# MCP servers

Connect a self-hosted LLM stack to MCP tool servers: stdio vs streamable HTTP under spec 2026-07-28, authentication, the Qdrant, Chroma and Postgres servers, and the LiteLLM MCP gateway.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill mcp-servers
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **Remote means authenticated; loopback by default.**
- **Read-only tools by default.**
- **Check server maintenance first.**

## References

- [`transports-auth.md`](references/transports-auth.md), [`servers.md`](references/servers.md), [`operations.md`](references/operations.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/llm-stack.md`](references/combos/llm-stack.md).

## Companion skills

- `qdrant`, `chroma`, `pgvector`, `litellm`, `open-webui`, `text-embeddings-inference`.

## License

MIT
