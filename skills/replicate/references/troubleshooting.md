# Replicate troubleshooting

> Verified against replicate.com/docs reference/error-codes, topics/predictions/rate-limits, lifecycle, topics/billing, topics/deployments, 2026-10-11

## Error codes

| Code  | Meaning                                    | Action                                                              |
| ----- | ------------------------------------------ | ------------------------------------------------------------------- |
| E1000 | Unknown error                              | Retry once, then contact support with the prediction ID             |
| E1001 | Out of memory                              | Use larger hardware, smaller inputs or lower resolution             |
| E4875 | Webhook URL is empty                       | Provide an HTTPS URL or drop the field                              |
| E6716 | Timeout starting the prediction            | Cold boot or capacity. Retry, use a deployment with a warm instance |
| E8367 | Prediction stopped in a non-terminal state | Re-run. Report the ID if it repeats                                 |
| E8765 | Model health check failed                  | A broken version. Pin a known good version                          |
| E9243 | Error starting the prediction              | Check the logs on the prediction, then retry                        |
| E9825 | Failed to upload file                      | Check output size and retry                                         |

## HTTP

| Status       | Cause                                                                                                                                          |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 401          | Missing, wrong or disabled token (including auto-disabled for a GitHub leak)                                                                   |
| 404          | Wrong `owner/name`, or a community model called without a version                                                                              |
| 429          | `Request was throttled. Expected available in N second(s).` Back off. Near-zero balance throttles harder                                       |
| Work blocked | Prepaid balance at zero blocks new work (billing docs). Add credit or enable auto-reload. Other statuses: unverified, check the HTTP reference |

## Symptoms

- **First request is very slow:** a cold boot of a public model on shared capacity. Wait, use `Prefer: wait` plus polling or a webhook, or deploy with `min_instances >= 1`.
- **Prediction `aborted`:** it was canceled before it started, so it is not charged. Likely `Cancel-After` was too short for a cold boot.
- **Output URL returns 404 later:** API outputs are deleted after an hour. Download immediately.
- **Webhook never arrives:** the URL must be HTTPS, must not redirect and must answer quickly. Check `webhook_events_filter`.
- **Webhook signature mismatch:** sign the raw body, with `${id}.${timestamp}.${body}`, using the base64 part of the secret after `whsec_`.
- **Cannot delete a deployment:** it must be offline and unused for at least 15 minutes. Set `min_instances` to 0 and wait.
- **Cannot delete a model:** it has versions or you do not own it, or it is public.
- **Bill higher than expected:** private models and deployments bill idle time. Check `min_instances` and idle deployments.
- **`cog push` fails:** run `cog login`, make sure the model exists under your username, and check Docker is running.

## Where to look

- Prediction logs: `GET /v1/predictions/{id}` shows `logs` and `error`.
- Status page and support: linked from https://replicate.com/docs. Never paste tokens.
