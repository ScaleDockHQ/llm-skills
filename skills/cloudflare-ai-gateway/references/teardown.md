# Teardown

> Verified against Cloudflare AI Gateway docs (changelog through 2026-10-06), 2026-10-11

Sources: configuration/manage-gateway, features/unified-billing, configuration/bring-your-own-keys under <https://developers.cloudflare.com/ai-gateway/>.

Nothing here bills by the hour, but credits, auto top-up and stored keys persist. Ask before deleting anything.

- [ ] List gateways: `GET /accounts/{id}/ai-gateway/gateways` (see SKILL.md discovery). Note which hold stored keys and spend limits.
- [ ] Turn off **auto top-up** (Credits Available > Manage) and decide what to do with remaining credits; refunds are a Cloudflare billing question, do not promise one.
- [ ] Remove BYOK provider keys on each gateway (Provider Keys), then delete the matching Secrets Store secrets if you created them.
- [ ] Delete test gateways: dashboard Settings > Delete Gateway, or `DELETE /accounts/{id}/ai-gateway/gateways/{gateway_id}`. Deletion is permanent. Deleting `default` is safe, an authenticated request recreates it.
- [ ] Revoke gateway tokens and API tokens that are no longer needed (My Profile > API Tokens). Tokens are account-scoped, so revoke the whole token.
- [ ] Remove client env vars (`ANTHROPIC_BASE_URL`, `ANTHROPIC_CUSTOM_HEADERS`, `CLOUDFLARE_API_TOKEN`) and delete dynamic routes you no longer use.
- [ ] Verify: the gateway list is empty or as expected, and a call with the old token returns 401 or 403.
