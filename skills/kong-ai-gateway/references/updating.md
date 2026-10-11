# Updating, versions and migration

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

## Version lines

- **Kong AI Gateway 2.x** (Konnect data plane `kong/kong-ai-gateway`): new minor roughly every 4 weeks, the two most recent minors are supported, no LTS. 2.2.0 was released 2026-09-30 (changelog: FIPS artifacts renamed `kong-ai-gateway-fips-140-3` and image tags `<version>-<distro>-fips-140-3`, TLS 1.2 cipher list narrowed in the FIPS build, a Distroless image added). Backports can bring features or breaking changes at any version level, so read each changelog entry.
- **Kong Gateway EE 3.x:** 3.16.0.0 released 2026-09-15, supported until 2027-09-15 per the support table. From 3.10 there is one LTS per year (planned each March, supported 3 years). Pick LTS for slow-moving fleets.
- **Kong Gateway OSS (`kong` image):** latest tag read was 3.9.3. The OSS image is a different line from Enterprise; AI plugin availability and provider lists differ (see `references/plugins-ai-proxy.md`).
- Helm chart `kong/kong-ai-gateway` pins its own default image tag (2.0.3 in chart 0.2.1). Set `image.tag`.

## Check what is current

```bash
curl -s 'https://hub.docker.com/v2/repositories/kong/kong-ai-gateway/tags?page_size=25&ordering=last_updated' | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$|^[0-9]+\.[0-9]+\.[0-9]+-ubuntu$'
curl -s 'https://hub.docker.com/v2/repositories/library/kong/tags?page_size=50' | jq -r '.results[].name' | grep -E '^3\.[0-9]+\.[0-9]+$' | sort -V | tail -3
helm repo update && helm search repo kong/kong-ai-gateway --versions | head -4
```

Changelogs: `https://developer.konghq.com/ai-gateway/changelog/` (2.x runtime) and the Kong Gateway changelog for 3.x.

## Upgrade steps

1. Read the changelog entries between your version and the target; note breaking changes.
2. Record the current image tag or digest and the rendered config (`deck gateway dump -o backup.yaml` against a DB-backed gateway; the rendered file for DB-less; `kongctl dump`-style export or the source YAML for 2.x). Backups hold secrets: keep them `0600`.
3. DB-backed 3.x: run `kong migrations up` then `kong migrations finish` per the upgrade guide, rolling nodes. DB-less and 2.x data planes are stateless: swap the image tag and roll one node first.
4. Test with a non-streaming and a streaming request, one failing upstream and one authenticated and one anonymous request.
5. Rollback: previous tag; for DB-backed with `migrations finish` done, restore from the database backup instead.

## 3.x to 2.x migration (Konnect)

The docs' flow: install the converter (`kongctl install extension Kong/kongctl-ext-aigw-converter`), `deck gateway dump` the plugin config from the 3.x control plane, prepare a `./config` directory with the target control plane, auth strategies, Vaults and per-model ACLs (the converter cannot recover these), run `kongctl convert ai-gateway`, review the output, then `kongctl apply` to a new AI Gateway 2.x control plane. Requirements: every `ai-proxy` or `ai-proxy-advanced` plugin needs a model name and target auth; `ai-proxy-advanced`, `ai-mcp-proxy` and `ai-a2a-proxy` must sit on a Service that has at least one Route. Run both stacks side by side and move traffic gradually.

## Discover

```bash
docker run --rm kong:3.9.3 kong version
docker inspect --format '{{.Config.Image}} {{.Image}}' "$(docker ps -q --filter ancestor=kong:3.9.3 | head -1)" 2>/dev/null
kubectl get deploy -A -o wide 2>/dev/null | grep -i kong
helm list -A 2>/dev/null | grep -i kong
```
