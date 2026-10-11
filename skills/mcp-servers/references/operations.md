# Hardening, updating, teardown

> Verified against MCP spec 2026-07-28, mcp-server-qdrant v0.8.1, chroma-mcp v0.2.6, postgres-mcp v0.3.0, LiteLLM v1.105.0, 2026-10-11

## Hardening checklist

- Pin versions (`uvx mcp-server-qdrant==0.8.1`, image digests). Review changelogs before bumps.
- Bind HTTP servers to 127.0.0.1 or an internal network; publish only the proxy.
- Proxy checks the bearer token and `Origin`; add TLS for off-box clients.
- Read-only by default: `QDRANT_READ_ONLY=true`, Postgres `--access-mode=restricted` with a read-only role.
- Least-privilege store credentials, one per server.
- Keep tokens out of client JSON; use env files with mode 0600 or the host's secret store.
- Treat retrieved text as untrusted; do not let the same agent hold write or delete tools and read arbitrary web content.
- Log to stderr or your log pipeline, without queries containing secrets.

## Update

1. Read release notes for the server and, if your host updates, the spec revision.
2. Bump the pinned version in one client first; list tools and run a known query.
3. Roll to the rest. Roll back by repinning.

## Teardown

Remove the server entries from client configs and from LiteLLM, stop the proxy and containers, revoke the store credentials and bearer tokens you created, and delete the env files. Stores and their data are removed through their own skills.
