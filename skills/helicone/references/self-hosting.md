# Self-hosting

> Verified against Helicone docs (self-host overview and Docker) and Helicone/helicone main (last commit 2026-09-16), 2026-10-11

Sources: <https://docs.helicone.ai/getting-started/self-host/overview>, <https://docs.helicone.ai/getting-started/self-host/docker>, <https://github.com/Helicone/helicone> (Apache-2.0), <https://github.com/Helicone/ai-gateway> (GPL-3.0, last push 2025-11-21).

Deployment options in the docs: manual, Docker Compose, Kubernetes with Helm charts, and a cloud guide. Support is community Discord only unless you buy an enterprise agreement. The maintenance-mode announcement applies to self-hosting too: expect security and bug fixes, not features.

## Docker all-in-one (local)

```bash
docker pull helicone/helicone-all-in-one:latest        # pin a tag or digest for anything real
docker run -d --name helicone -p 3000:3000 -p 8585:8585 -p 9080:9080 helicone/helicone-all-in-one:latest
curl -sS http://localhost:8585/healthcheck            # Jawn API
```

Dashboard on `http://localhost:3000`. Jawn (port 8585) no longer proxies LLM traffic: the `/v1/gateway/*` routes were removed, so to proxy requests through a self-hosted deployment, run the AI Gateway alongside Jawn (per the docs). Note that the gateway repo has had no recent releases; treat that setup as unsupported-by-default and test it.

## Remote server

Set the public URLs and a real secret:

```bash
export PUBLIC_URL="http://YOUR_HOST:3000" JAWN_URL="http://YOUR_HOST:8585" S3_URL="http://YOUR_HOST:9080"
docker run -d --name helicone -p 3000:3000 -p 8585:8585 -p 9080:9080 \
  -e SITE_URL="$PUBLIC_URL" -e BETTER_AUTH_URL="$PUBLIC_URL" -e NEXT_PUBLIC_APP_URL="$PUBLIC_URL" \
  -e BETTER_AUTH_SECRET="$(openssl rand -base64 32)" \
  -e NEXT_PUBLIC_HELICONE_JAWN_SERVICE="$JAWN_URL" -e S3_ENDPOINT="$S3_URL" -e NEXT_PUBLIC_IS_ON_PREM=true \
  helicone/helicone-all-in-one:latest
```

Env vars from the docs: `NEXT_PUBLIC_HELICONE_JAWN_SERVICE` (browser-reachable API URL), `S3_ENDPOINT` (browser-reachable presigned URL base), `S3_ACCESS_KEY` and `S3_SECRET_KEY` (default `minioadmin`, change them), `S3_BUCKET_NAME` (`request-response-storage`), `BETTER_AUTH_SECRET` (default `change-me-in-production`; generate a value, persist it in a `0600` file so restarts keep sessions), `SITE_URL`, `BETTER_AUTH_URL`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_IS_ON_PREM`.

All three ports must be reachable by browsers. Put TLS in front (`caddy`, `cloudflare-tunnel`, `tailscale`) and persist data with volumes per the Docker page.

## Security note

A security fix landed on 2026-09-16 (platform-admin takeover and cross-tenant query issues). Pull the latest image before exposing an instance and keep following the repo's commits.
