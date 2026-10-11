# Traefik: static configuration

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "EntryPoints", "API and dashboard", "Providers overview", "Healthcheck".

Static options need a restart. Minimal file (`templates/traefik.yml`):

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint: { to: websecure, scheme: https, permanent: true }
  websecure:
    address: ":443"
    transport:
      respondingTimeouts:
        { readTimeout: 0s, writeTimeout: 0s, idleTimeout: 180s }
providers:
  file: { directory: /etc/traefik/dynamic, watch: true }
api: { dashboard: true } # insecure stays false
ping: {}
```

## Entrypoint timeouts (defaults from the docs)

| Option                                          | Default | Note                                                                                                         |
| ----------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| `transport.respondingTimeouts.readTimeout`      | 60s     | Time to read the whole request including body; 0 = none. Large prompts or uploads over slow links can hit it |
| `transport.respondingTimeouts.writeTimeout`     | 0s      | Covers request header end to response end; 0 = none. Keep 0 for streaming                                    |
| `transport.respondingTimeouts.idleTimeout`      | 180s    | Keep-alive idle                                                                                              |
| `transport.lifeCycle.graceTimeOut`              | 10s     | Active requests finish before stop                                                                           |
| `transport.lifeCycle.requestAcceptGraceTimeout` | 0s      | Keep accepting before the grace period                                                                       |

## API and dashboard

`api.dashboard` defaults to true once `api` is set; `api.insecure` (default false) serves both on the `traefik` entrypoint (:8080) with no auth; it is incompatible with `api.basePath`. `api.debug` adds profiling endpoints. Routes: `/api/http/routers`, `/api/http/services`, `/api/overview`, `/api/rawdata`. To expose the dashboard safely, create a router for `api@internal` with an auth middleware on a restricted entrypoint.

## Ping

`ping: {}` enables `/ping` (200 `OK`) on the `traefik` entrypoint, or set `ping.entryPoint`. `traefik healthcheck --ping` exits 0 when healthy; use it as the container healthcheck.

## Providers

`providers.providersThrottleDuration` debounces reloads. See `routing-and-providers.md`.
