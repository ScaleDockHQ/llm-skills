# Securing Chroma

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

## No built-in authentication

Chroma v1.0.0 no longer ships built-in authentication. The `CHROMA_SERVER_AUTHN_*`, `CHROMA_SERVER_AUTHZ_*` and `CHROMA_AUTH_TOKEN_TRANSPORT_HEADER` variables appear only in older examples. Anyone who can reach port 8000 can read, write and delete every collection.

Therefore:

1. Do not publish 8000. Bind it to `127.0.0.1` or keep it on an internal Docker network (the template does the latter).
2. Put an authenticating reverse proxy in front (`templates/Caddyfile` is a bearer-token check; use mTLS, OIDC or your gateway if you have one).
3. Terminate TLS at the proxy when clients are on other hosts; clients then use `ssl=True`.
4. Keep the token in a `0600` env file.

Clients send the header:

```python
import os, chromadb
client = chromadb.HttpClient(host="chroma.internal", port=8001, ssl=False,
    headers={"Authorization": f"Bearer {os.environ['CHROMA_PROXY_TOKEN']}"})
```

## Other settings

- `CHROMA_ALLOW_RESET` stays `false`. When true, a client can erase all state.
- `cors_allow_origins` defaults to `["*"]` in the sample config; restrict it if browsers connect.
- Payload cap defaults to 40 MiB (`CHROMA_MAX_PAYLOAD_SIZE_BYTES`).
- Isolation is per tenant and database name only, not per user: a bearer token grants everything. Run one instance per trust boundary.
- Telemetry goes to your OTLP endpoint only if you set `CHROMA_OPEN_TELEMETRY__ENDPOINT`; `OTEL_EXPORTER_OTLP_HEADERS` may carry credentials, so keep it in the env file.
