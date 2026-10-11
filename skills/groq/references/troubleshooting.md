# Groq troubleshooting

> Verified against GroqDocs: Errors, Rate Limits, Spend Limits, Model Permissions, Flex Processing, OpenAI Compatibility, Structured Outputs, Batch, 2026-10-11

| Symptom                                                            | Cause                                                                       | Fix                                                                                                   |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 401                                                                | Missing, wrong or deleted key                                               | Check `env \| cut -d= -f1`; create a new key in the right project                                     |
| 400 with `blocked_api_access` on every call                        | Organization monthly spend limit reached                                    | Raise or remove the limit in console billing limits, or wait for the 1st; spend lags 10 to 15 minutes |
| 400 on `logprobs`, `logit_bias`, `top_logprobs`, `messages[].name` | Unsupported OpenAI field                                                    | Remove it; also keep `n` at 1                                                                         |
| 400 on `response_format` json_schema                               | Model lacks structured outputs, or invalid schema                           | Check the model page; use JSON Object Mode on other models                                            |
| 403 "model blocked at organization or project level"               | Model permissions                                                           | Org owner or project admin allows it at settings/limits or settings/project/limits                    |
| 403 elsewhere                                                      | Key lacks permission, or feature not enabled for the org (for example LoRA) | Check the role and the plan                                                                           |
| 404                                                                | Wrong URL or model ID; missing `/openai` in the base URL                    | Use `https://api.groq.com/openai/v1`; list `/models` (fine_tunings live under `/v1/fine_tunings`)     |
| 413                                                                | Request body too large                                                      | Shrink the prompt or split                                                                            |
| 422                                                                | Malformed semantic content (can be model output, such as a bad tool call)   | Fix input or retry                                                                                    |
| 424                                                                | Remote MCP dependency failed                                                | Check MCP server authentication                                                                       |
| 429                                                                | RPM, RPD, TPM or TPD hit                                                    | Honor `retry-after`, read `x-ratelimit-*`, reduce parallelism, use Batch or flex for volume           |
| 498 `capacity_exceeded`                                            | Flex tier out of capacity                                                   | Retry with jittered backoff or fall back to `on_demand`                                               |
| 5xx                                                                | Server side, not billed                                                     | Retry with backoff                                                                                    |
| Batch rejected at upload                                           | File over line or size cap, or not `.jsonl`                                 | Split to the documented limits                                                                        |
| Batch `expired`                                                    | Window too short for capacity                                               | Use a longer `completion_window` (up to `7d`)                                                         |
| Batch with `service_tier` fails                                    | Batch does not accept it                                                    | Remove the parameter                                                                                  |
| Responses API `previous_response_id` ignored or rejected           | Listed as unsupported                                                       | Send history yourself                                                                                 |
| Cache discount missing                                             | Model not supported, prefix changed, or cache expired (2 hours)             | Keep prefix stable; check supported models                                                            |
| Batch or fine-tuning unavailable                                   | Zero Data Retention enabled                                                 | Disable it in Data Controls if policy allows                                                          |

If an error is not listed, read the `error.code` and `error.message` from the JSON body and search https://console.groq.com/docs with that text.

## Sources

- https://console.groq.com/docs/errors
- https://console.groq.com/docs/rate-limits
- https://console.groq.com/docs/spend-limits
- https://console.groq.com/docs/model-permissions
- https://console.groq.com/docs/flex-processing
- https://console.groq.com/docs/openai

## Quick diagnosis

```bash
# Is the key valid and what can it call?
curl -s -o /dev/null -w '%{http_code}\n' https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY"

# Inspect the error body of a failing call without printing the key
curl -s https://api.groq.com/openai/v1/chat/completions -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" -d '{"model":"<MODEL_ID>","messages":[{"role":"user","content":"hi"}]}' | jq '.error'
```

Check order: key and project, model permissions, spend limit, rate-limit headers, then request parameters.
