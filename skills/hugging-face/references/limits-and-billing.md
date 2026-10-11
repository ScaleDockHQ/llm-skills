# Hugging Face limits, credits and billing

> Verified against Inference Providers Pricing and Billing page, huggingface_hub Inference Endpoints guide, HF Inference Endpoints docs (pause and resume, create), CLI guide, 2026-10-11

## What bills how

| Product               | Billing                                                                                       | Where to see price                                   |
| --------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Inference Providers   | Provider rates passed through, no markup, pay as you go on your HF account                    | `GET router.../v1/models` per provider; pricing page |
| HF Inference provider | Compute time times hardware price                                                             | pricing page                                         |
| Inference Endpoints   | Per minute while running (replicas times instance price); free while paused or scaled to zero | `hf endpoints hardware`                              |
| Spaces hardware       | While running; paused time is not billed                                                      | `hf spaces hardware`                                 |
| Jobs                  | Per use, pre-paid credits required                                                            | CLI guide Hardware section, Jobs docs                |

Do not hardcode any of these rates; read them from the commands above.

## Credits

PRO users get monthly included credits and Team or Enterprise organizations get credits per seat. They are general-purpose compute credits usable on Inference Providers, Inference Endpoints, Spaces upgraded hardware and Jobs, applied before pay-as-you-go. Free users can buy credits. Current amounts: https://huggingface.co/docs/inference-providers/en/pricing. Team and Enterprise orgs: pass `X-HF-Bill-To: <org>` to charge the org, and set a spending limit and provider allow-list in org settings.

## Quotas and limits

- Inference Endpoints accelerator quota is per namespace (user or org): see `hf endpoints hardware --namespace <ns>`; a scaled-to-zero endpoint still occupies quota.
- Rate limits for Inference Providers depend on the plan and the provider. Unverified: exact numbers; check https://huggingface.co/docs/inference-providers and the 429 body.
- Hub download and API rate limits depend on whether you are authenticated; use a token.

## Seeing spend

- Billing page in account settings; Inference Providers settings page shows last-month usage by model and provider.
- Organizations on paid plans: org settings, and (Enterprise) `GET /api/organizations/<org>/billing/usage/inference` with a billing-capable token. Rows appear up to two hours after requests, costs round to cents.
- Endpoint cost by hand: running replicas times hourly price from `hf endpoints hardware`, times hours running.

## Cost controls

- Prefer Inference Providers for spiky or low traffic; dedicated endpoints for steady traffic, custom weights, or isolation.
- On endpoints set `--min-replica 0` only if 502 while waking is acceptable; pause when idle; delete when done.
- Name a provider (`:groq`) if a cheaper-than-fastest policy gives acceptable latency, or use `:cheapest`.
- Spending limits: org settings for Team and Enterprise. Personal spending caps: unverified, check billing settings.

## Official links

- Pricing and billing: https://huggingface.co/docs/inference-providers/en/pricing
- Inference Endpoints: https://huggingface.co/docs/inference-endpoints
