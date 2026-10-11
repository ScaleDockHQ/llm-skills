# Traefik: routers, services and providers

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "Routing Configuration" (HTTP routers, load balancing service, Docker and file providers), "Docker provider".

## Model

Entrypoint -> router (rule, middlewares, tls) -> service (`loadBalancer.servers`). Rules use v3 syntax such as `Host(\`llm.example.com\`)`, `PathPrefix(\`/v1\`)`, combined with `&&`and`||`.

## File provider (fixed backends)

`providers.file.directory` (recommended over `filename`; they are mutually exclusive), `watch: true` default. See `templates/dynamic-llm.yml`:

```yaml
http:
  routers:
    llm:
      rule: "Host(`llm.example.com`)"
      entryPoints: [websecure]
      middlewares: [llm-auth, llm-rate]
      service: llm
      tls: { certResolver: le }
  services:
    llm:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:4000" # LiteLLM, vLLM, llama-swap ...
```

Traefik in a container cannot reach `127.0.0.1` of the host: use the Compose service name, `host.docker.internal` (with `extra_hosts: host-gateway`), or the host IP.

## Docker provider (labels)

Options (defaults): `endpoint` unix socket, `exposedByDefault` true (set false), `network` empty (set it when a container has several networks, or per container `traefik.docker.network`), `defaultRule` `Host(normalize .Name)`, `watch` true, `constraints`. Labels:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.llm.rule=Host(`llm.example.com`)
  - traefik.http.routers.llm.entrypoints=websecure
  - traefik.http.routers.llm.tls.certresolver=le
  - traefik.http.services.llm.loadbalancer.server.port=4000
```

The port label is required when the container exposes several ports or none.

## Service tuning

- Health checks: `loadBalancer.healthCheck` (path, interval, timeout).
- `serversTransport` `forwardingTimeouts` example values in the docs: `dialTimeout` 30s, `responseHeaderTimeout` 10s, `idleConnTimeout` 60s. A `responseHeaderTimeout` shorter than a model's time to first token returns 504; the upstream default is 0 (none), so only set it deliberately.
- `responseForwarding.flushInterval` default 100ms; negative flushes immediately; streaming responses are flushed immediately anyway.
- Other providers: Swarm, Consul Catalog, Nomad, ECS, KV, HTTP, Kubernetes CRD/Ingress/Gateway.
