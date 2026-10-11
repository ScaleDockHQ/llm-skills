---
name: google-tpu
description: Pick, provision and operate Google Cloud TPUs (v5e, v6e Trillium, TPU7x Ironwood) to serve LLMs with vLLM TPU (tpu-inference, vllm-tpu) on Compute Engine or GKE, then tear down. Use for TPU quota, ct6e-standard-8t, v6e-8, queued-resources, gke-tpu-topology, vllm/vllm-tpu image, libtpu, JAX recompilation, "TPU not found", HBM sizing. Not for GPU clouds (cloud-llms), Vertex AI managed models (google-vertex-ai) or vLLM flags (vllm).
license: MIT
compatibility: Needs bash, gcloud, jq, curl, and for GKE kubectl. A Google Cloud project with TPU quota and billing. Creating TPU VMs, node pools or reservations bills the project, so each needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Google TPU

Get a Cloud TPU slice serving an OpenAI-compatible vLLM endpoint: right generation and topology for the model, provisioning path that the generation supports, a pinned `vllm-tpu` install, and a clean teardown.

**Scope:** the platform: TPU generations, slice shapes, HBM sizing, provisioning (Compute Engine, Cloud TPU API, GKE), the vLLM TPU backend and TPU-specific failures. Engine flags belong to `vllm`; managed Gemini and Model Garden belong to `google-vertex-ai`; GPU clouds belong to `cloud-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints secrets.

```bash
gcloud --version | head -1; gcloud config list --format='value(core.project,compute.zone)' 2>/dev/null
gcloud auth list --format='value(account)'                       # who is signed in; no tokens
gcloud compute tpus tpu-vm list --zone "$ZONE" 2>&1              # legacy Cloud TPU API VMs (v5e and older)
gcloud compute instances list --filter='machineType~ct6e OR machineType~ct5' --format='table(name,zone,machineType.basename(),status)'
gcloud compute tpus queued-resources list --zone "$ZONE" 2>&1    # pending or active queued resources
gcloud compute tpus accelerator-types list --zone "$ZONE" 2>&1 | head -20   # what the zone offers
gcloud compute tpus versions list --zone "$ZONE" 2>&1 | head -20             # runtime versions
kubectl get nodes -L cloud.google.com/gke-tpu-accelerator,cloud.google.com/gke-tpu-topology 2>&1 | head
# On a TPU VM:
python3 --version; pip list 2>/dev/null | grep -iE '^(vllm|vllm-tpu|tpu.inference|jax|jaxlib|libtpu) '
docker ps --format '{{.Names}}\t{{.Image}}'
```

Find what already exists and what runs before proposing anything. TPU resources bill while they exist, even idle.

## Decision flow

1. **Choose the generation** from model size and the provisioning path you can use (`references/generations-and-sizing.md`). v6e and v5e are the common single-host serving targets; TPU7x is GKE or Compute Engine only and capacity-gated.
2. **Provision** with the path the generation supports (`references/provisioning.md`): Compute Engine `gcloud compute instances create` for v6e and v5p, Cloud TPU API queued resources for v5e and older, GKE for TPU7x and multi-host.
3. **Install and serve** vLLM TPU, pinned: `uv pip install vllm-tpu` in Python 3.12, or the `vllm/vllm-tpu:<tag>` image (`references/vllm-tpu.md`). Check the model against the project's recommended-models matrix first.
4. **Multi-host or very large models:** GKE and the `tpu-recipes` repository (`references/provisioning.md`, `references/vllm-tpu.md`).
5. **Gateway and clients:** vLLM TPU speaks the OpenAI API on port 8000; put LiteLLM in front (`litellm`, `llm-gateway` skills).
6. **Broken:** `references/troubleshooting.md`.
7. **Done or pausing:** `references/teardown.md`.

## Rules

- **Ask before anything billable.** Name the accelerator type, zone, capacity model (on-demand, Spot, Flex-start, reservation), expected run time and teardown command, then wait.
- **Match the API to the generation.** The Cloud TPU API (`gcloud compute tpus ...`) is in maintenance and not supported on TPU7x; use Compute Engine or GKE there.
- **Pin versions.** Pin `vllm-tpu` or the image tag, the model revision and the runtime or JAX AI image. Never run `:latest` or `:nightly` in production.
- **Secrets stay out of output.** `HF_TOKEN` comes from a `0600` file or the environment; never from a logged command line. Never print `gcloud auth print-access-token` output.
- **Do not hardcode prices or quotas.** Read them from the Cloud TPU pricing page, the Cloud Billing console and `gcloud` quota views.
- **TPUs are not CUDA.** No `nvidia-smi`, CUDA images or GPU-only quantization formats. The first request after a new shape compiles, so warm up before judging latency.
- **Always tear down.** Reservations, disks and queued resources can keep billing after the VM is gone; finish with `references/teardown.md` and check Cloud Billing.
- **Verify upstream.** Generations, machine types, versions and supported models change quarterly; re-read Google Cloud and vLLM TPU docs.

## Workflows

- [ ] Baseline: run Discover, record project, zone, quota and existing TPU resources.
- [ ] Choose generation and slice from the model's weights plus KV cache against HBM -> `references/generations-and-sizing.md`
- [ ] Provision after approval -> `references/provisioning.md`
- [ ] Install `vllm-tpu` or the image, verify JAX sees the chips, serve -> `references/vllm-tpu.md`
- [ ] Smoke test `GET /v1/models` and one completion, then warm up with representative lengths.
- [ ] Hand off to the gateway (`litellm`) and monitoring (`llm-observability`).
- [ ] Tear down -> `references/teardown.md`
- [ ] Verify: `jax.devices()` lists the expected chips, the endpoint answers, nothing TPU-related is left in `gcloud` listings.

## Reference index

- `references/generations-and-sizing.md`: v5e, v6e, TPU7x specs, slice shapes, machine types, HBM budget formula.
- `references/provisioning.md`: Compute Engine, queued resources, GKE node selectors, capacity models, runtime versions.
- `references/vllm-tpu.md`: vllm-tpu install, image, serve command, env vars, supported models and features, recipes.
- `references/troubleshooting.md`: symptom to fix.
- `references/teardown.md`: ordered removal and verification.

## Companion skills

- `vllm`: engine flags, parsers, tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `google-vertex-ai`: managed Gemini and Model Garden instead of self-managed TPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill google-vertex-ai`.
- `litellm`: gateway in front of the endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `choosing-hardware`: compare TPU against GPU options. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `cloud-llms`: other providers. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
