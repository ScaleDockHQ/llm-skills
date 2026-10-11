# Troubleshooting MCP servers

> Verified against MCP spec 2026-07-28, mcp-server-qdrant v0.8.1, chroma-mcp v0.2.6, postgres-mcp v0.3.0, LiteLLM v1.105.0, 2026-10-11

| Symptom                                      | Likely cause and fix                                                                                                                |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Client shows no tools                        | Wrong command or transport; run the server by hand and read stderr. For HTTP, `curl` the endpoint through the proxy with the token. |
| JSON parse errors on stdio                   | The server printed non-protocol text to stdout. Logs must go to stderr.                                                             |
| 401 from the proxy                           | Missing `Authorization: Bearer`; the client config needs the header.                                                                |
| 403 or origin error                          | `Origin` not allowed; the spec requires servers to reject invalid origins. Allow your host's origin at the proxy.                   |
| Old server and new client fail to negotiate  | Server predates revision 2026-07-28 (no `server/discover`); pin the host to a version that falls back, or upgrade the server.       |
| Qdrant find returns nothing                  | Collection embedded with another model; the MCP server uses fastembed and its own vector name.                                      |
| Chroma server cannot reach Chroma            | Proxy token not accepted by chroma-mcp; point it at the internal URL.                                                               |
| Stdio server missing in LiteLLM              | Stdio entries stay disabled unless `LITELLM_ENABLE_MCP_STDIO=true` is set on the proxy.                                             |
| Cold start timeouts                          | First run downloads fastembed models; pre-warm or raise host timeouts (Open WebUI: `MCP_INITIALIZE_TIMEOUT`).                       |
| Sticky-session errors behind a load balancer | Not needed in 2026-07-28 (stateless); remove stickiness or check the server's revision.                                             |
