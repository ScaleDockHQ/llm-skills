# Gemini API: troubleshooting

> Verified against Gemini API docs: Troubleshooting guide, Rate limits, Billing, Using Gemini API keys, OpenAI compatibility, 2026-10-11

For the full error table see the API errors page linked from the troubleshooting guide.

| Symptom                                               | Cause                                                               | Fix                                                                                                                                |
| ----------------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `402 Payment Required`                                | Prepay credit balance is $0; stops all keys on the billing account  | Add credits or enable auto-reload; do not retry                                                                                    |
| `429 RESOURCE_EXHAUSTED`                              | RPM, TPM or RPD limit, or the rolling 10-minute spend limit         | Back off with jitter; reduce load; check AI Studio limits; request an increase                                                     |
| `503 UNAVAILABLE` or other 5xx, 408                   | Transient service issue                                             | Retry with exponential backoff and a maximum                                                                                       |
| `400` or `403` on a previously working key            | Invalid or restricted key, bad syntax, wrong API version or model   | Do not retry; check key restrictions, model ID and `/v1` vs `/v1beta`                                                              |
| "Your API key was reported as leaked"                 | Key was publicly exposed and blocked                                | Create a new key in AI Studio; audit usage                                                                                         |
| Key rejected though valid format                      | Unrestricted standard key, or dormant key shown as Blocked          | Restrict it to the Gemini API or create an auth key                                                                                |
| Cannot create a key ("no permission in this project") | Missing IAM permissions                                             | Ask an admin for a role with the permissions listed in `references/setup-and-auth.md`                                              |
| Limits unexpectedly low                               | Free tier, preview model or no tier upgrade yet                     | Link billing; upgrades take effect within about 10 minutes                                                                         |
| High latency or token use                             | Gemini 3.x thinking is on by default                                | Lower the thinking level (or `reasoning_effort`) per the thinking guide                                                            |
| Looping or degraded reasoning                         | Temperature below 1.0, `top_p` or `top_k` changed on Gemini 3.x     | Keep defaults on 3.x                                                                                                               |
| Empty output, `BlockedReason.OTHER`                   | Safety block, terms violation or unsupported content                | Review safety settings and the prompt                                                                                              |
| Output stops with `RECITATION`                        | Output resembles source data                                        | Make the prompt more unique; use a higher temperature (not on 3.x)                                                                 |
| Repeated text with structured output                  | Field order differs from the schema, or optional fields             | Make all fields required; do not specify field order in the prompt                                                                 |
| Repeated newlines in JSON                             | `\u` or `\t` escape sequences in the input                          | Use UTF-8 characters; allow only `\\`, `\n`, `\"` in a system instruction                                                          |
| Repeated tool calls                                   | Model loses its prior reasoning                                     | Add a short "recap progress" instruction to the system prompt                                                                      |
| Batch job `JOB_STATE_EXPIRED`                         | Pending or running more than 48 hours                               | Resubmit, split into smaller batches                                                                                               |
| Batch results gone                                    | Kept only 6 weeks                                                   | Resubmit                                                                                                                           |
| File not found later                                  | Files delete after 48 hours                                         | Re-upload                                                                                                                          |
| `cached_content` ignored or rejected                  | Wrong `extra_body` nesting, expired cache, or Interactions API used | Use `extra_body.extra_body.google.cached_content` in the OpenAI SDK; recreate the cache; use `generateContent` for explicit caches |
| `reasoning_effort` plus `thinking_config` conflict    | They overlap                                                        | Use only one                                                                                                                       |
| LiteLLM calls hit Vertex instead of AI Studio         | Model name lacks the `gemini/` prefix                               | Use `gemini/<model>`                                                                                                               |
| Over-spend despite a cap                              | Cap and billing data lag by about 10 minutes; batch jobs overshoot  | Lower caps for batch workloads; monitor usage                                                                                      |

## Quick diagnostics

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://generativelanguage.googleapis.com/v1beta/models" -H "x-goog-api-key: $GEMINI_API_KEY"
```

## Where to read more

- https://ai.google.dev/gemini-api/docs/troubleshooting
- https://ai.google.dev/gemini-api/docs/rate-limits
