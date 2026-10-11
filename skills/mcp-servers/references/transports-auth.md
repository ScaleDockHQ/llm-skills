# Transports and authorization

> Verified against MCP spec 2026-07-28, mcp-server-qdrant v0.8.1, chroma-mcp v0.2.6, postgres-mcp v0.3.0, LiteLLM v1.105.0, 2026-10-11

Latest stable spec revision at the check date: **2026-07-28** (released 2026-07-28). Older revisions: 2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05.

## Transports

| Transport       | Use                               | Notes                                                                                                                              |
| --------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| stdio           | Local, client launches the server | Newline-delimited JSON-RPC on stdin and stdout. The server must write nothing else to stdout; logs go to stderr.                   |
| Streamable HTTP | Remote or shared                  | One MCP endpoint accepting POST. Each request is its own POST; the reply is a JSON object or an SSE stream scoped to that request. |
| HTTP+SSE        | Legacy                            | Deprecated since 2025-03-26; reclassified Deprecated in 2026-07-28. Migrate.                                                       |

## What 2026-07-28 changed (relevant to operators)

- No protocol sessions and no `Mcp-Session-Id`; the `initialize` handshake is gone. Each request carries its protocol version and client capabilities. Servers implement `server/discover`.
- Streamable HTTP POSTs require `MCP-Protocol-Version` and `Mcp-Method` headers, so proxies can route and rate-limit by method.
- SSE resumability (`Last-Event-ID`) is removed: a broken stream loses the in-flight request and the client re-issues it. Do not rely on sticky sessions; any replica can answer.
- Roots, Sampling and Logging are deprecated. Dynamic Client Registration is deprecated in favour of Client ID Metadata Documents.
- Servers and clients built for older revisions may not speak this one yet; check each server's README before assuming (see `servers.md`).

## Security requirements for Streamable HTTP

The spec says servers MUST validate the `Origin` header on all connections (invalid present Origin gets an HTTP error), SHOULD bind to 127.0.0.1 locally rather than 0.0.0.0, and SHOULD authenticate all connections.

## Authorization

Authorization is optional. For HTTP transports, implementations should follow the spec (OAuth 2.1 draft, protected-resource metadata, resource indicators per RFC 8707); servers MUST check that tokens were issued for them as the audience and must not pass tokens through to other services. For stdio, do not use that flow: read credentials from the environment.

Practical self-hosted options:

1. Loopback only, no auth (single user).
2. Reverse proxy with a static bearer token (`templates/Caddyfile`), for small trusted teams. Returns 401 without the token.
3. OAuth at an identity-aware proxy or the LiteLLM MCP gateway for multi-user setups.
