# Teardown

> Verified against Helicone docs (self-host Docker, quick start), 2026-10-11

Sources: <https://docs.helicone.ai/getting-started/self-host/docker>, <https://docs.helicone.ai/getting-started/quick-start>.

- [ ] Hosted: delete API keys and provider keys in Settings, remove stored BYOK deployments, and decide what to do with remaining credits (a billing question for Helicone support; do not promise a refund).
- [ ] Export logs and datasets you need before removal; ask the user.
- [ ] Remove `HELICONE_API_KEY`, `Helicone-*` headers and the `helicone/` model prefix from apps and CI.
- [ ] Self-hosted: `docker rm -f helicone`; the data volumes and MinIO bucket hold request and response bodies, so delete or archive them only with the user's consent.
- [ ] Remove DNS, tunnel or proxy routes for ports 3000, 8585 and 9080.
- [ ] Verify: the old key returns an authentication error and nothing listens on the self-host ports.
