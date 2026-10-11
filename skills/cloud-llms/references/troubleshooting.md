# Troubleshooting cloud LLMs

> Verified against vLLM v0.31.0 docs (Kubernetes troubleshooting, RunPod 502 guide, security), worker-vllm v2.29.0 README, Hugging Face Inference Endpoints autoscaling docs, AWS Bedrock model access docs, LiteLLM v1.105.0 docs (fallbacks, budgets, health), OpenAI and Anthropic rate-limit docs, 2026-10-11

Start with the symptom. Every check below is read-only unless stated; none prints secrets.

## Authentication and access

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| 401 from a vendor API | Key missing in the gateway's environment, revoked, or for another project | `[ -n "${OPENAI_API_KEY:-}" ] && echo set`; check the gateway process environment; rotate if exposed |
| Bedrock `AccessDeniedException` after first calls worked | Marketplace subscription failed in the background; missing `aws-marketplace:*` permissions; model needs extra account-level access | Grant `aws-marketplace:Subscribe`, `Unsubscribe`, `ViewSubscriptions`; wait a few minutes; contact AWS for gated models |
| Bedrock "model not supported in region" or validation error on model ID | Model not in that Region, or it requires an inference profile ID | `aws bedrock list-foundation-models --region <region>`; use the profile ID |
| Agent Platform 403 | Missing role on the serving identity, API not enabled, wrong project | `gcloud config list`; `gcloud services list --enabled --filter='name:aiplatform.googleapis.com'` |
| Azure 404 (deployment not found) | Using the model name instead of the deployment name, or wrong resource | `az cognitiveservices account deployment list -g <rg> -n <resource> -o table` |
| vLLM 401 on `/v1/...` | `VLLM_API_KEY` set on the server and not sent by the gateway | Set `api_key: os.environ/...` on the gateway deployment |

## Rate limits and quotas

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| 429 from OpenAI / Anthropic / Gemini | RPM/TPM or tier limit; shared model-family limit | Backoff and retry; fallback alias; check the console limits page; request higher tier |
| 429 / `ThrottlingException` on Bedrock | Per-model, per-Region quota | Service Quotas increase; geographic cross-Region inference profile if residency allows |
| Cannot launch GPU instance | Regional GPU quota is zero or capacity unavailable | Request quota; try another zone or region; different GPU type |
| Requests dropped when budget hit | Gateway provider or key budget reached | Check gateway spend; raise budget deliberately, not by removing it |

## Endpoints and deployments

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| 502 from RunPod proxy | Server still loading; bound to `127.0.0.1`; port mismatch; GPU OOM | Check pod logs; `--host 0.0.0.0`; match exposed port; smaller model or larger GPU |
| 502 from Hugging Face Inference Endpoint after idle | Scale-to-zero cold start; no request queue | Retry with backoff; keep one replica; gateway fallback |
| RunPod Serverless worker restarts silently | Unrecoverable startup error (model too big, `MAX_MODEL_LEN` above KV capacity, bad flag, gated model without `HF_TOKEN`) | `runpodctl serverless logs <id>`; fix the config, do not just restart |
| RunPod load-balancer endpoint errors on first request | No queue: no worker ready yet | Client retries through cold starts; keep an active worker |
| Kubernetes pod killed during startup, logs show `KeyboardInterrupt: terminated` | Probe failure threshold shorter than model load time | Add a startup probe or raise `failureThreshold` / `initialDelaySeconds` |
| Pod `Pending` with GPU request | No GPU nodes, device plugin missing, taints | `kubectl describe pod`; check GPU Operator pods; node pool autoscaler and GPU quota |
| CUDA out of memory at load | Model + KV cache exceed GPU memory | Lower `--max-model-len` or `--max-num-seqs`, use a quantized model, or add GPUs with `--tensor-parallel-size` |
| Weights re-download on every restart | Cache on ephemeral disk | Persistent volume or network volume for the Hugging Face cache |
| KServe `READY` stays False | Storage initializer cannot fetch `hf://` (token), runtime image pull, GPU scheduling | `kubectl describe inferenceservice <name>`; storage-initializer logs |

## Gateway behavior

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Fallback never triggers | Retries not exhausted; error type covered by a different fallback list (context window, content policy) | Check `num_retries`; add `context_window_fallbacks`; test with a real failure (mock flags are ignored by the proxy) |
| Restricted data reached a cloud provider | Shared model group or fallback across trust zones | Separate alias without fallbacks; keys scoped to allowed models |
| Budgets not enforced | No database configured | Set `database_url` / `DATABASE_URL`; Redis for multiple instances |
| `/health/readiness` returns 503 | Configured database unreachable | Check database connectivity and credentials (without printing them) |

## Latency and throughput

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| High TTFB only from some clients | Client far from region; gateway in another region | Measure from the right region; co-locate gateway and backend |
| Throughput collapses under load | Engine queueing (`vllm:num_requests_waiting` rising); rate limits upstream | Add replicas; autoscale on queue depth; raise quotas |
| Numbers vary run to run | Shared provider capacity; cold starts; fallbacks during the run | Repeat at several times; separate cold and warm runs; check gateway logs for fallbacks |

## Costs

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Bill higher than gateway spend | Idle GPUs, storage, egress, load balancers are invisible to the gateway | Teardown checklist in `cost-and-quotas.md`; cloud budgets with alerts |
| Serverless bill like an always-on VM | Active/minimum workers kept warm | Reduce warm workers; accept cold starts where allowed |

## Official links

- vLLM Kubernetes troubleshooting: https://docs.vllm.ai/en/latest/deployment/k8s/
- vLLM on RunPod (502 guide): https://docs.vllm.ai/en/latest/deployment/frameworks/runpod/
- RunPod vLLM worker: https://github.com/runpod-workers/worker-vllm
- Hugging Face Inference Endpoints autoscaling: https://huggingface.co/docs/inference-endpoints/en/autoscaling
- Bedrock model access: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
- LiteLLM fallbacks: https://docs.litellm.ai/docs/proxy/reliability
- LiteLLM health: https://docs.litellm.ai/docs/proxy/health
