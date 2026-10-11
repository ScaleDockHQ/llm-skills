# Phoenix: configuration, auth and network

> Verified against Arize Phoenix v20.21.0 (docs: self-hosting/configuration, self-hosting/features/authentication, self-hosting/security/network-security, self-hosting/security/privacy), 2026-10-11

## Server environment variables

| Variable                                                            | Default          | Notes                                                                                            |
| ------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------ |
| `PHOENIX_PORT` / `PHOENIX_GRPC_PORT`                                | `6006` / `4317`  | Web and OTLP HTTP / OTLP gRPC                                                                    |
| `PHOENIX_HOST`                                                      | `0.0.0.0`        | Bind address                                                                                     |
| `PHOENIX_HOST_ROOT_PATH`                                            | none             | Sub-path prefix behind a reverse proxy                                                           |
| `PHOENIX_WORKING_DIR`                                               | `~/.phoenix/`    | SQLite and exports; must be a persistent volume in containers                                    |
| `PHOENIX_SQL_DATABASE_URL`                                          | temp SQLite file | `postgresql://...` or `sqlite:///path/db.sqlite`                                                 |
| `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS`                             | `0` (infinite)   | Default trace retention for all projects                                                         |
| `PHOENIX_ENABLE_PROMETHEUS`                                         | `false`          | Metrics on port 9090                                                                             |
| `PHOENIX_TELEMETRY_ENABLED`                                         | `true`           | Product web analytics only, no trace data; `false` disables                                      |
| `PHOENIX_ALLOW_EXTERNAL_RESOURCES`                                  | `true`           | `false` for air-gapped hosts: no Google Fonts, no telemetry, no WASM sandbox download (11.15.0+) |
| `PHOENIX_ENABLE_MCP_SERVER`                                         | `true`           | Built-in remote MCP server at `/mcp` (beta); set `false` to remove the endpoint                  |
| `PHOENIX_ENABLE_MCP_CODE_MODE`                                      | `true`           | MCP `execute` tool runs agent-written Python in a sandbox; `false` exposes plain tools           |
| `PHOENIX_ALLOWED_PROVIDERS`                                         | all              | Playground providers shown, comma list; `NONE` hides all                                         |
| `PHOENIX_ALLOWED_SANDBOX_PROVIDERS`                                 | all              | Code-execution sandbox providers; `NONE` disables all                                            |
| `PHOENIX_SERVER_INSTRUMENTATION_OTLP_TRACE_COLLECTOR_HTTP_ENDPOINT` | none             | Makes the Phoenix server trace itself to that collector                                          |
| `PHOENIX_LOG_SQL`                                                   | `false`          | Log every SQL statement (13.4.0+)                                                                |

List installed settings by name only: `env | cut -d= -f1 | grep ^PHOENIX_`.

## Authentication

Off by default. Enable with two variables (restart required):

```bash
# in a 0600 env file, never on the command line
PHOENIX_ENABLE_AUTH=true
PHOENIX_SECRET=<long random string>      # signs JWTs; keep identical across replicas
PHOENIX_USE_SECURE_COOKIES=true          # behind HTTPS
PHOENIX_CSRF_TRUSTED_ORIGINS=https://phoenix.example.com
PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD=<strong password>   # only read on first start
```

Procedure, per upstream:

1. Schedule downtime. With auth on, trace ingestion and API calls are rejected until clients carry an API key.
2. The built-in admin is `admin@localhost`; the initial password is `admin` unless `PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD` is set before the account is first created. Changing the variable later has no effect; change it in the UI.
3. Log in, set a new password, create a **system API key** in Settings (one per sender, so you can revoke one).
4. Senders use `Authorization: Bearer <key>`. `phoenix.otel` and the Phoenix client read `PHOENIX_API_KEY`; raw OTLP exporters use `OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer <key>"` (set from a secret file, do not echo it).

Options: `PHOENIX_ENABLE_STRONG_PASSWORD_POLICY=true` (12+ chars with classes, 13.5.0+; default minimum is 4), brute-force lockout after 5 attempts for 5 minutes (`PHOENIX_BRUTE_FORCE_LOGIN_PROTECTION_MAX_ATTEMPTS`, `PHOENIX_DISABLE_BRUTE_FORCE_LOGIN_PROTECTION`), OAuth2/OIDC and LDAP sign-in (`PHOENIX_LDAP_*`), `PHOENIX_DISABLE_BASIC_AUTH`, token expiry variables. `PHOENIX_ENABLE_OAUTH2_AUTHORIZATION_SERVER` (default `true`, needs auth on) lets the Phoenix CLI and MCP clients log in through the browser; set `false` for API-key-only deployments.

## Network and egress

- Expose only 6006 (and 4317 if gRPC senders are remote) through TLS. Keep PostgreSQL private.
- The Playground and evaluations make outbound requests to LLM providers and to any base URL a user types. Upstream warns this is an SSRF path to internal services and metadata endpoints (`169.254.169.254`); restrict egress with Kubernetes NetworkPolicies or a firewall and hide providers with `PHOENIX_ALLOWED_PROVIDERS`.
- Self-hosted Phoenix sends no trace or eval data to Arize (upstream statement); the only telemetry is UI analytics, off with `PHOENIX_TELEMETRY_ENABLED=false`.
- Reverse proxy: forward HTTP/1.1 and gRPC (h2) separately; for a sub-path set `PHOENIX_HOST_ROOT_PATH`; the upstream repo has `examples/reverse-proxy`.

## Observe the server

`PHOENIX_ENABLE_PROMETHEUS=true` exposes metrics on 9090 (keep private). `GET /healthz` is liveness; `GET /readyz` checks the database and returns `503` when it is unreachable. `GET /arize_phoenix_version` returns the server version.
