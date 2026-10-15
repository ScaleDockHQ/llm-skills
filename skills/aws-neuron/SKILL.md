---
name: aws-neuron
description: Set up and operate AWS Inferentia2 and Trainium (Inf2, Trn1, Trn2, Trn3) with the Neuron SDK to serve LLMs through vLLM Neuron or NxD Inference, using Neuron DLAMIs and DLCs. Use for neuron-ls, vllm-neuron, NxD Inference, NEURON_LOGICAL_NC_CONFIG, trn2.48xlarge, Inf2 sizing, compile cache, NEFF bucketing, tensor-parallel degree, slow first compile. Not for managed Bedrock (aws-bedrock), SageMaker endpoints (aws-sagemaker) or vLLM GPU flags (vllm).
license: MIT
compatibility: An AWS account with Inf2, Trn1, Trn2 or Trn3 quota; Linux with bash, aws CLI, docker, curl and jq. Launching instances, endpoints or capacity reservations bills the account, so each needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# AWS Neuron

Get LLMs serving on AWS Inferentia2 or Trainium with the Neuron SDK: the right instance and plugin line for the model, a pinned environment (DLAMI or DLC), a working `vllm serve`, and a teardown.

**Scope:** the platform: instance families, Neuron SDK components and versions, the two vLLM paths (vLLM Neuron plugin, and vLLM with NxD Inference), NeuronCore and LNC sizing, compile and bucketing behaviour. Managed model APIs belong to `aws-bedrock`; managed endpoints to `aws-sagemaker`; GPU engine flags to `vllm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints secrets.

```bash
aws --version; aws sts get-caller-identity --query Account --output text >/dev/null && echo aws-auth-ok   # no ids printed
aws ec2 describe-instance-types --filters "Name=instance-type,Values=inf2.*,trn1*.*,trn2*.*,trn3*.*" \
  --query 'InstanceTypes[].[InstanceType,NeuronInfo.NeuronDevices[0].Count,NeuronInfo.NeuronDevices[0].Name]' --output text 2>&1 | head -20
aws ec2 describe-instances --filters "Name=instance-type,Values=inf2.*,trn1*.*,trn2*.*,trn3*.*" "Name=instance-state-name,Values=pending,running,stopped" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output text
# On a Neuron instance:
neuron-ls                                   # devices, NeuronCores, memory, topology
ls /dev/neuron* 2>/dev/null | head -3
pip list 2>/dev/null | grep -iE '^(vllm|vllm-neuron|neuronx|torch-neuronx|neuronx-distributed-inference|nki) '
python3 --version; docker ps --format '{{.Names}}\t{{.Image}}'
echo "$NEURON_LOGICAL_NC_CONFIG"; echo "$VLLM_CACHE_ROOT"; echo "$NEURON_COMPILED_ARTIFACTS"
```

Find what exists and what runs before proposing anything. Neuron instances bill while they run, idle or not.

## Decision flow

1. **Choose instance and plugin line** from the model, instance family and Neuron SDK release (`references/instances-and-sdk.md`). The vLLM Neuron plugin (Beta) is Trn2 and Trn3 only; Inf2 and Trn1 use vLLM with NxD Inference (maintenance line).
2. **Pick the environment:** the Neuron multi-framework or vLLM DLAMI (Ubuntu 24.04), or the `vllm-inference-neuronx` DLC image (`references/setup.md`). Do not install the Neuron driver or SDK by hand on a DLAMI.
3. **Serve:** `vllm serve` with a tensor-parallel size that matches the NeuronCores you want (`references/vllm-neuron.md`). Check the model against the plugin's tested list first.
4. **Compile behaviour:** first start compiles per bucket and can take minutes; keep the compile cache on local NVMe and pre-compile for production (`references/vllm-neuron.md`).
5. **Gateway and clients:** the server is an OpenAI-compatible endpoint on port 8000; front it with LiteLLM (`litellm`, `llm-gateway`).
6. **Broken:** `references/troubleshooting.md`.
7. **Done or pausing:** `references/teardown.md`.

## Rules

- **Ask before anything billable.** Name instance type, region, count, storage and a stop time, then wait for approval.
- **Match the plugin to the instance.** `vllm-neuron` 0.24.x targets Trn2 and Trn3 only. Inf2 and Trn1 need the NxD Inference line (plugin 0.5.x), which is in maintenance.
- **Use DLAMI or DLC for the SDK.** Neuron's driver, runtime, compiler and PyTorch must match; the images ship matched sets.
- **Pin everything.** Neuron SDK, plugin tag, vLLM version, image tag and model revision. The plugin version string encodes the vLLM version.
- **Secrets stay out of output.** `HF_TOKEN` comes from a `0600` file or the environment.
- **Do not hardcode prices or quotas.** Read them from the AWS pricing pages and Service Quotas.
- **Neuron is not CUDA.** No `nvidia-smi`, no CUDA wheels; use `neuron-ls` and `neuron-top`-style tools from `aws-neuronx-tools`. Static shapes mean compile time and bucketing matter.
- **Always tear down.** Terminate instances and remove volumes and reservations (`references/teardown.md`).
- **Verify upstream.** The Neuron SDK ships monthly; docs pages and READMEs lag each other, so re-read the release notes and the plugin README before pinning.

## Workflows

- [ ] Baseline: run Discover; record instance type, Neuron SDK, plugin, Python -> `references/instances-and-sdk.md`
- [ ] Launch (after approval) the DLAMI or run the DLC -> `references/setup.md`
- [ ] Verify the platform loads: `neuron-ls`, plugin device name -> `references/setup.md`
- [ ] Serve and smoke test `GET /v1/models` plus one completion -> `references/vllm-neuron.md`
- [ ] Tune TP, buckets and cache; pre-compile for production -> `references/vllm-neuron.md`
- [ ] Hand off to the gateway (`litellm`) and monitoring (`llm-observability`).
- [ ] Tear down -> `references/teardown.md`
- [ ] Verify: `neuron-ls` lists the expected devices, the endpoint answers, no Neuron instances remain.

## Reference index

- `references/instances-and-sdk.md`: families, memory, NeuronCores and LNC, SDK components and the plugin matrix.
- `references/setup.md`: DLAMI, SSM lookup, DLC image, manual install, verification.
- `references/vllm-neuron.md`: vLLM Neuron plugin and the NxD Inference line: serve commands, features, buckets, cache, parallelism.
- `references/troubleshooting.md`: symptom to fix.
- `references/teardown.md`: ordered removal and verification.

## Companion skills

- `vllm`: engine flags and tuning (GPU-centred). Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `aws-bedrock`: managed models instead of self-managed accelerators. Install: `npx skills add ScaleDockHQ/llm-skills --skill aws-bedrock`.
- `aws-sagemaker`: managed endpoints. Install: `npx skills add ScaleDockHQ/llm-skills --skill aws-sagemaker`.
- `litellm`: gateway in front of the endpoint. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `choosing-hardware`: compare accelerators. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
