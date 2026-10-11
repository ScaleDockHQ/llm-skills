# Hugging Face troubleshooting

> Verified against Inference Providers docs, Inference Endpoints docs (pause and resume, access, create), huggingface_hub CLI and Inference Endpoints guides, Hub security tokens page, 2026-10-11

| Symptom                                             | Likely cause                                                    | Fix                                                                                   |
| --------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `hf: command not found`; old `huggingface-cli` used | CLI not installed; command renamed.                             | `pip install -U huggingface_hub`; use `hf`.                                           |
| `hf auth logout` does nothing                       | `HF_TOKEN` is set.                                              | `unset HF_TOKEN` and remove it from profiles.                                         |
| 401 on the Hub or router                            | Missing, expired or wrong token.                                | `hf auth whoami`; create a new fine-grained token.                                    |
| 403 on router                                       | Token lacks "Make calls to Inference Providers", or org policy. | Add the permission; for orgs check fine-grained-only or approval policy.              |
| 403 on an org's resources, "token has been revoked" | Org admin revoked or denied the token.                          | Create a new token; ask the admin to approve.                                         |
| Gated model download denied                         | Terms not accepted, or token without access.                    | Accept on the model page; use a token that has read access.                           |
| Disk full after downloads                           | Cache growth.                                                   | `hf cache ls`, `hf cache rm`, `hf cache prune`; `--local-dir` elsewhere.              |
| Router model not found or no provider               | Model not served; provider disabled.                            | `hf models ls --warm`; list `/v1/models`; name another provider.                      |
| Behavior or price changes between calls             | `:fastest` picked another provider.                             | Pin a provider (`:groq`) or `:preferred`.                                             |
| Inference credits exhausted                         | Monthly credits used.                                           | Buy credits or move to a custom provider key (ask the user).                          |
| 502 from an endpoint                                | Scaled to zero and waking, or still initializing.               | Retry with backoff; `endpoint.wait()`; keep `--min-replica 1` for steady use.         |
| Endpoint stuck `pending` or fails to start          | Hardware unavailable, quota, bad image or flags.                | `hf endpoints describe`; check logs in the dashboard; try another instance or region. |
| Endpoint deploy rejected                            | Quota in namespace used up (scaled-to-zero endpoints count).    | Pause or delete unused endpoints; `hf endpoints hardware` shows quota.                |
| Only one GPU in use on a big instance               | vLLM or SGLang parallelism not set.                             | `--tensor-parallel-size N` (TP times DP equals GPUs).                                 |
| 404 on OpenAI route of an endpoint                  | `/v1` missing or wrong server image.                            | Append `/v1`; use a vLLM, SGLang or TGI image.                                        |
| LiteLLM `huggingface/` call goes to the wrong place | Provider segment missing or api_base wrong.                     | Use `huggingface/<provider>/<org>/<model>` or the OpenAI-compatible router form.      |
| Space file writes vanish                            | Pause and restart reset the ephemeral filesystem.               | Use a volume or bucket.                                                               |
| Job exits non-zero                                  | Script failure.                                                 | `hf jobs logs <id>`; use `--attempts` for retries.                                    |
| Unexpected charges                                  | Endpoint, Space hardware or Job left running.                   | `teardown.md` list step; pause or delete.                                             |
