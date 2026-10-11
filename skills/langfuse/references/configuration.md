# Langfuse: configuration

> Verified against Langfuse v4.56.0 (docs: self-hosting/configuration, security/authentication-and-sso, security/networking, configuration/health-readiness-endpoints, license-key), 2026-10-11

Names only; values come from the `0600` env file or Kubernetes secrets. The full list is at https://langfuse.com/self-hosting/configuration; read it for the running version before adding anything unusual.

## Required on web and worker

| Variable                                                                                                                             | Notes                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DATABASE_URL`                                                                                                                       | Postgres URL; or `DATABASE_HOST`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME`. Encode special characters. Postgres 15+ for v4                                   |
| `DIRECT_URL`, `SHADOW_DATABASE_URL`                                                                                                  | Migration URL (pooled setups) and shadow DB when the user cannot `CREATE DATABASE`                                                                                         |
| `CLICKHOUSE_URL`, `CLICKHOUSE_MIGRATION_URL`                                                                                         | HTTP (8123/8443) and native TCP (9000/9440) URLs, `clickhouse://host:port` for migration                                                                                   |
| `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`                                                                                             | The user needs the v4 grants listed in `references/updating.md`                                                                                                            |
| `CLICKHOUSE_CLUSTER_ENABLED`                                                                                                         | Documented default `true`; set `false` for single-node ClickHouse                                                                                                          |
| `REDIS_CONNECTION_STRING` or `REDIS_HOST`/`REDIS_PORT`/`REDIS_AUTH`                                                                  | Plus `REDIS_TLS_ENABLED`, cluster (`REDIS_CLUSTER_ENABLED`, `REDIS_CLUSTER_NODES`) or sentinel variants                                                                    |
| `LANGFUSE_S3_EVENT_UPLOAD_BUCKET` (+ `_REGION`, `_ENDPOINT`, `_ACCESS_KEY_ID`, `_SECRET_ACCESS_KEY`, `_FORCE_PATH_STYLE`, `_PREFIX`) | Event store. Credentials need List, Get, Put (plus Delete when retention is on)                                                                                            |
| `LANGFUSE_S3_MEDIA_UPLOAD_*`                                                                                                         | Same shape for media; `_ENDPOINT` must be browser-reachable, `_INTERNAL_ENDPOINT` for server-side reads                                                                    |
| `LANGFUSE_S3_BATCH_EXPORT_ENABLED` + `LANGFUSE_S3_BATCH_EXPORT_*`                                                                    | Off by default; needed for UI batch exports                                                                                                                                |
| `NEXTAUTH_URL`                                                                                                                       | Public URL users open; also used in emails and SSO callbacks                                                                                                               |
| `NEXTAUTH_SECRET`, `SALT`, `ENCRYPTION_KEY`                                                                                          | `openssl rand -base64 32` (secret, salt) and `openssl rand -hex 32` (64 hex chars). Never change `SALT` after keys exist; `ENCRYPTION_KEY` encrypts sensitive data at rest |

## Frequently used optional settings

- `PORT` (3000 web, 3030 worker), `HOSTNAME` (set `0.0.0.0` where the container is otherwise unreachable, such as Cloud Run).
- `LANGFUSE_LOG_LEVEL` (`trace` to `fatal`, default `info`), `LANGFUSE_LOG_FORMAT` (`text` or `json`).
- `LANGFUSE_CACHE_API_KEY_ENABLED` / `_TTL_SECONDS` (default true, 300), `LANGFUSE_CACHE_PROMPT_ENABLED` / `_TTL_SECONDS` (default true, 300).
- `LANGFUSE_AUTO_POSTGRES_MIGRATION_DISABLED`, `LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED`: migrations run on start by default; disabling is not recommended.
- `CLICKHOUSE_READ_ONLY_URL`: route UI and public-API reads to a replica.
- `LANGFUSE_S3_CONCURRENT_WRITES` / `_READS` (default 50): raise on `socket usage at capacity` warnings.
- `TELEMETRY_ENABLED` (Compose) / `langfuse.features.telemetryEnabled` (Helm): the web container sends aggregated usage statistics to Langfuse via PostHog at `eu.posthog.com`; raw traces, prompts and scores are not sent. Set false for air-gapped or strict-privacy installs.
- `LANGFUSE_CSP_ENFORCE_HTTPS=true` when served over TLS.

## Authentication

- Email and password sign-up is on by default. Restrict it: `AUTH_DISABLE_SIGNUP=true` (existing users only; also blocks invited users with no account), `AUTH_DISABLE_USERNAME_PASSWORD=true` (SSO only), `AUTH_DOMAINS_WITH_SSO_ENFORCEMENT=domain1.com,domain2.com`.
- SSO providers (Google, GitHub, GitLab, Azure AD/Entra ID, Okta, Keycloak, Auth0, Cognito, Authentik, custom OAuth and others) are configured with provider-specific `AUTH_*` variables; the OAuth callback URL must match `NEXTAUTH_URL`. See https://langfuse.com/self-hosting/security/authentication-and-sso.
- Project-level RBAC roles are Enterprise.

## Networking and exposure

Only `langfuse-web` must be reachable by users and SDKs. Put a TLS-terminating proxy or load balancer in front; keep Postgres, ClickHouse, Redis, the worker and the MinIO console on localhost or private networks (the shipped Compose file binds them to `127.0.0.1`). Langfuse needs no outbound internet except optional LLM API access for the playground and evaluators.

## Health endpoints

| Container | Endpoint                  | Meaning                                                                       |
| --------- | ------------------------- | ----------------------------------------------------------------------------- |
| web       | `/api/public/health`      | API up; add `?failIfDatabaseUnavailable=true` to include Postgres             |
| web       | `/api/public/ready`       | Ready for traffic                                                             |
| worker    | `/api/health` (port 3030) | Up and DB connected; `?failIfEventPropagationStuck=true` during v4 dual write |

## Enterprise features

Core features and scale are the same in OSS and Enterprise. A license key (`LANGFUSE_EE_LICENSE_KEY` on both containers) unlocks: project-level RBAC, protected prompt labels, data retention policies, audit logs, server-side data masking, UI customization, organization creators, org management API and SCIM, instance management API. Removing the variable and restarting disables them again.

## Official links

- https://langfuse.com/self-hosting/configuration
- https://langfuse.com/self-hosting/security/authentication-and-sso
- https://langfuse.com/self-hosting/security/networking
- https://langfuse.com/self-hosting/configuration/health-readiness-endpoints
- https://langfuse.com/self-hosting/license-key
- https://langfuse.com/self-hosting/security/telemetry
