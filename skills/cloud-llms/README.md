# Cloud LLMs Skill

An agent skill for running and consuming language models in the cloud: frontier APIs (OpenAI, Anthropic, Google Gemini), managed open-model APIs (Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter, Hugging Face Inference Providers), hyperscaler platforms (AWS Bedrock, Google's Gemini Enterprise Agent Platform, Microsoft Foundry), managed endpoints, rented GPU VMs, serverless GPU and Kubernetes. The agent discovers which cloud CLIs are installed and authenticated, then works through checklists to pick a tier, provision, deploy, connect everything to one LiteLLM endpoint next to your local models, secure it, set budgets, benchmark, scale, update and tear down.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cloud-llms
```

## Rules

- **Least privilege, short-lived credentials.** Prefer IAM roles, workload identity and managed identities over static keys; scope keys per project.
- **Budgets and alerts before traffic.** Set cloud budgets, provider spend limits and gateway budgets before the first real request.
- **Pin model versions.** Use dated or versioned model IDs and image tags, never "latest", in anything that serves users.
- **Know the data path.** For every provider: retention, region, training use, and every hop (gateway, logs, traces).
- **Request quota before you need it.** GPU and model quotas start low and increases take time.
- **Scale to zero only where cold starts are acceptable.** Interactive users should not wait for weights to load.
- **Idle GPUs and egress are the hidden bill.** Stop what is idle; keep traffic in-region.
- **Measure before and after.** Benchmark every deploy, scale or update with the same protocol.
- **Secrets never touch output.** No keys in logs, shell history, manifests, tickets or chat; reference them by name.
- **Downtime is a decision.** Updates and teardowns that interrupt traffic are scheduled and announced, or done with a fallback in place.

## References

The `SKILL.md` overview is always loaded; the agent pulls a reference only when a workflow step needs it.

- [`references/frontier-apis.md`](references/frontier-apis.md): stack note for OpenAI, Anthropic, Gemini. Depth in `openai-api`, `anthropic-api`, `gemini-api`.
- [`references/open-model-apis.md`](references/open-model-apis.md): stack note and base URLs. Depth in `together-ai`, `fireworks-ai`, `groq`, `cerebras`, `sambanova`, `deepinfra`, `hugging-face`.
- [`references/hyperscalers.md`](references/hyperscalers.md): stack note. Depth in `aws-bedrock`, `google-vertex-ai`, `azure-foundry`.
- [`references/managed-endpoints.md`](references/managed-endpoints.md): stack note. Depth in `aws-sagemaker`, `google-vertex-ai`, `azure-foundry`, `hugging-face`.
- [`references/gpu-vms.md`](references/gpu-vms.md): stack note. Depth in `runpod`, `lambda-cloud`, `vast-ai`, `coreweave`, `nebius`, `crusoe`, `hyperbolic`.
- [`references/serverless-gpu.md`](references/serverless-gpu.md): stack note. Depth in `runpod`, `modal`, `baseten`.
- [`references/kubernetes.md`](references/kubernetes.md): stack note. Depth in `kserve`, `llm-d`, `vllm-production-stack`, `aibrix`, `ray-serve`, `gateway-api-inference-extension`, `nvidia-gpu-operator`, `keda`.
- [`references/gateway-hybrid.md`](references/gateway-hybrid.md): cloud entries, fallbacks and budgets in LiteLLM next to local models.
- [`references/cost-and-quotas.md`](references/cost-and-quotas.md): budgets, alerts, quotas, cost formulas, teardown checks.
- [`references/security-compliance.md`](references/security-compliance.md): IAM, secrets, private endpoints, logging and PII, residency.
- [`references/benchmarking-cloud.md`](references/benchmarking-cloud.md): protocol and `scripts/bench.sh`.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom → cause → fix tables.
- [`references/example.md`](references/example.md): anonymized hybrid with a DGX Spark primary and cloud overflow.
- Templates: [`assets/litellm-hybrid.yaml`](assets/litellm-hybrid.yaml), [`assets/k8s/vllm-deployment.yaml`](assets/k8s/vllm-deployment.yaml), [`assets/k8s/kserve-inferenceservice.yaml`](assets/k8s/kserve-inferenceservice.yaml).

Upstream credit: the Kubernetes templates follow [vLLM's Kubernetes guide](https://docs.vllm.ai/en/latest/deployment/k8s/) and [KServe's text generation guide](https://kserve.github.io/website/docs/model-serving/generative-inference/tasks/text-generation); gateway config follows the [LiteLLM docs](https://docs.litellm.ai/docs/proxy/configs); serverless guidance follows [runpod-workers/worker-vllm](https://github.com/runpod-workers/worker-vllm) and [Modal's vLLM example](https://modal.com/docs/examples/vllm_inference).

## Companion skills

All in [ScaleDockHQ/llms-skills](https://github.com/ScaleDockHQ/llms-skills); install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `choosing-llm-hosting`: decide whether and which cloud tier to use.
- `self-hosted-llms`: the self-hosted stack (DGX Spark first-class, LiteLLM + llama-swap + engines); also the source of `scripts/bench.sh`.
- `llm-gateway`: general gateway features (keys, budgets, routing, fallbacks, API bridging).
- `llm-evals`: eval methods and quality gates.
- `llm-observability`, `llm-clients`, `local-llms`, `model-quantization`, `fine-tuning-llms`, `self-hosted-genmedia`.

## License

MIT
