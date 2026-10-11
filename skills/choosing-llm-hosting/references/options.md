# Hosting options: the seven tiers

> Verified against provider documentation pages linked below (OpenAI, Anthropic, Google Gemini API, AWS Bedrock, Gemini Enterprise Agent Platform, Microsoft Foundry, RunPod, Modal, Hugging Face), 2026-10-11

Each tier below lists what it is, advantages, disadvantages, best for, and avoid when. Tiers are ordered from most control to least control. Hybrid, which combines tiers, is covered in `hybrid-patterns.md`.

## 1. Laptop / desktop local

**What it is.** A model runs on the machine in front of you, through a runtime such as Ollama, LM Studio, llama.cpp or MLX. Apple Silicon unified memory and consumer NVIDIA GPUs are the common hardware.

**Advantages**

- Data never leaves the device. Works offline.
- No per-token cost; the hardware is already paid for.
- Fast iteration for prototyping, prompt work and private notes or code.

**Disadvantages**

- Memory limits model size. Large models need heavy quantization or do not fit.
- Single user. Concurrency is poor and the machine is busy while it generates.
- Battery, heat and noise. Quality is well below frontier models for hard tasks.

**Best for:** individual developers, sensitive personal or client data, offline work, prototyping before committing to a server.

**Avoid when:** several people or services need the model, uptime matters, or the task needs frontier-level reasoning.

## 2. Owned server (DGX Spark, GPU workstation, rack server)

**What it is.** Hardware you buy and run, on-prem or in a colocation rack, serving models through engines such as vLLM, SGLang or llama.cpp behind a gateway. A compact box like a DGX Spark, a multi-GPU workstation, or a datacenter server all fit here.

**Advantages**

- Full data control; can be air-gapped.
- Lowest marginal cost per token when the hardware is busy most of the day.
- Fixed, predictable cost. No per-token surprises. No vendor model deprecations.
- Any open-weight model, any quantization, any fine-tune.

**Disadvantages**

- Capex up front, and the hardware depreciates as newer accelerators ship.
- You own drivers, engines, upgrades, monitoring, security and on-call.
- Capacity is fixed: bursts queue, idle hours are wasted.
- Power, cooling, network and physical security are your problem.

**Best for:** steady internal workloads on open models, regulated or air-gapped data, teams with ops capacity, high utilization.

**Avoid when:** load is spiky or unknown, nobody can own the box, or the quality bar requires frontier models.

## 3. Rented GPU VM

**What it is.** A cloud instance with GPUs (Lambda, RunPod pods, Vast.ai, CoreWeave, or hyperscaler GPU instances on AWS, Google Cloud, Azure) running the same self-hosted stack as tier 2.

**Advantages**

- No capex; start and stop by the hour.
- Access to accelerators you could not buy or host.
- Same software stack as an owned server, so it doubles as a burst or test environment.

**Disadvantages**

- You still run the stack: drivers, engine, gateway, security.
- Billing runs while the instance is up, busy or idle.
- Quotas and capacity shortages for popular GPUs; spot instances can be interrupted.
- Ephemeral disks lose model caches; egress fees apply to traffic leaving the cloud.

**Best for:** pilots before buying hardware, steady workloads where renting beats owning at your utilization, burst capacity, large models that need datacenter GPUs.

**Avoid when:** usage is a few hours a week (APIs are cheaper), or nobody can operate the stack.

## 4. Serverless GPU

**What it is.** You supply a container or function; the platform runs it on GPUs per request and can scale to zero. Examples: RunPod Serverless (including its vLLM worker), Modal, Hugging Face Inference Endpoints with scale-to-zero.

**Advantages**

- Pay for active time, not idle time.
- Custom or fine-tuned models without operating VMs.
- Automatic scale-out for bursts.

**Disadvantages**

- Cold starts: loading weights onto a GPU takes time, and some platforms return errors rather than queueing during a cold start.
- Keeping workers warm to avoid cold starts brings back idle cost.
- Per-second GPU pricing is higher than the hourly VM rate; sustained load is cheaper elsewhere.
- Platform-specific packaging and limits.

**Best for:** custom models with spiky or low average traffic, async or batch jobs, demos.

**Avoid when:** interactive latency must be consistent and traffic is sparse (cold starts will hit users), or load is steady all day.

## 5. Managed open-model API

**What it is.** A provider hosts open-weight models behind a per-token, usually OpenAI-compatible, API. Examples: Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter (a router across providers), Hugging Face Inference Providers.

**Advantages**

- No infrastructure; pay per token.
- Same open models you could self-host later, so migration to tiers 2-4 is straightforward.
- Often very fast and cheap for popular models.

**Disadvantages**

- Data leaves your control; terms vary by provider and sometimes by model or upstream host.
- Model catalog and quantization chosen by the provider; models get retired.
- Rate limits and shared-capacity variance.

**Best for:** open-model workloads without an ops team, validating an open model before self-hosting, overflow capacity.

**Avoid when:** data terms do not meet your classification, or you need a model or fine-tune the provider does not host.

## 6. Frontier proprietary API

**What it is.** Closed models from the labs that train them: OpenAI, Anthropic (Claude), Google (Gemini API).

**Advantages**

- Highest capability on hard reasoning, coding, agentic and multimodal tasks.
- Zero ops; batch and prompt-caching features cut cost for suitable workloads.
- Enterprise programs exist for retention controls, residency and compliance.

**Disadvantages**

- Highest per-token cost for top models.
- Data leaves your control; default retention for abuse monitoring applies unless you qualify for reduced or zero retention.
- Model versions are deprecated on the vendor's schedule; behavior changes between versions.
- Rate-limit tiers gate throughput for new accounts.

**Best for:** tasks where only frontier quality passes your eval, low-to-moderate volume, teams that want zero ops.

**Avoid when:** data cannot leave your control, volume is very high on simple tasks (an open model will be far cheaper), or you need weights you control.

## 7. Hyperscaler platform

**What it is.** Models consumed through your cloud account: AWS Bedrock, Google's Gemini Enterprise Agent Platform (formerly Vertex AI; Google renamed it in 2026 and the API host is unchanged), and Microsoft Foundry (formerly Azure AI Foundry, including Azure OpenAI). They offer frontier and open models under your cloud contract, IAM and networking.

**Advantages**

- Existing contract, billing, committed-spend discounts and compliance attestations.
- IAM roles instead of static keys; private networking (AWS PrivateLink, Google Private Service Connect, Azure Private Link).
- Regional and data-zone deployment options for residency.
- Some frontier models available without a separate vendor contract.

**Disadvantages**

- Model availability lags or differs by region; new models may arrive later than on the vendor's own API.
- Quotas start low and need requests; provisioned capacity is a commitment.
- More setup (IAM, model access, endpoints) than a vendor API key.
- Each platform's API surface differs, though OpenAI-compatible endpoints exist.

**Best for:** enterprises already on that cloud, regulated workloads needing a BAA and private networking, teams that want frontier models under one cloud bill.

**Avoid when:** you need the newest model on day one, you have no cloud footprint, or you need a model only available elsewhere.

## Summary matrix

| Tier           | Control     | Ops burden | Cost shape               | Quality ceiling  | Elasticity  |
| -------------- | ----------- | ---------- | ------------------------ | ---------------- | ----------- |
| 1 Local        | Highest     | Low        | Already paid             | Low-medium       | None        |
| 2 Owned        | Highest     | High       | Capex + power            | Open-weight best | None        |
| 3 GPU VM       | High        | High       | Per hour                 | Open-weight best | Manual      |
| 4 Serverless   | Medium-high | Medium     | Per second active        | Open-weight best | Automatic   |
| 5 Open API     | Medium      | None       | Per token                | Open-weight best | Automatic   |
| 6 Frontier API | Low-medium  | None       | Per token                | Highest          | Automatic   |
| 7 Hyperscaler  | Medium-high | Low-medium | Per token or provisioned | High             | Quota-bound |

## Official links

- RunPod Serverless vLLM: https://docs.runpod.io/serverless/vllm/overview
- Modal vLLM example: https://modal.com/docs/examples/vllm_inference
- Hugging Face Inference Endpoints autoscaling: https://huggingface.co/docs/inference-endpoints/en/autoscaling
- Hugging Face Inference Providers: https://huggingface.co/docs/inference-providers/index
- AWS Bedrock model access: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
- Gemini Enterprise Agent Platform name changes: https://docs.cloud.google.com/gemini-enterprise-agent-platform/vertex-ai-name-changes
- Microsoft Foundry overview: https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry
- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- Anthropic API and data retention: https://platform.claude.com/docs/en/build-with-claude/zero-data-retention
- Gemini API terms: https://ai.google.dev/gemini-api/terms
