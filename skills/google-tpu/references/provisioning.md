# Provisioning TPUs

> Verified against Google Cloud docs (TPU software versions, Queued resources, Manage TPU resources, GKE TPU how-to and concepts, TPU7x), vLLM TPU docs (Cloud TPU Setup), 2026-10-11

Every command that creates, resizes or deletes a resource needs the user's approval. Set `PROJECT_ID` and `ZONE` first; take the zone from where the project has TPU quota (https://cloud.google.com/tpu/docs/regions-zones and https://cloud.google.com/tpu/docs/quota).

## Which API for which generation

| Generation  | Path                                                                                         |
| ----------- | -------------------------------------------------------------------------------------------- |
| v6e, v5p    | Compute Engine (`gcloud compute instances create`), or GKE                                   |
| v5e, v4, v3 | Cloud TPU API queued resources (`gcloud alpha compute tpus queued-resources create`), or GKE |
| TPU7x       | GKE (or Compute Engine); the Cloud TPU API does not support TPU7x. No Flex-start.            |

Google marks the Cloud TPU API as no longer under active development (bug and security fixes only), so prefer Compute Engine or GKE for new work where the generation allows it.

## Compute Engine: v6e (from the vLLM TPU setup guide)

```bash
gcloud compute instances create my-tpu-vm \
  --zone="$ZONE" \
  --machine-type=ct6e-standard-8t \
  --image-project=ubuntu-os-accelerator-images \
  --image-family=ubuntu-accel-2204-amd64-tpu-v5e-v5p-v6e \
  --maintenance-policy=TERMINATE
gcloud compute ssh my-tpu-vm --zone "$ZONE"
gcloud compute instances describe my-tpu-vm --zone "$ZONE" --format='value(status)'
```

`ct6e-standard-1t`, `-4t` and `-8t` are the single-VM shapes (1, 4, 8 chips). v5p uses `ct5p-hightpu-4t`. 16+ chip v6e topologies need multi-host managed instance groups or GKE.

Flex-start (discounted, runs up to 7 days, v5e, v5p and v6e only) adds `--provisioning-model=FLEX_START --request-valid-for-duration=2h --max-run-duration=4h --instance-termination-action=DELETE`. Check the current flags in the Compute Engine TPU docs before use: https://cloud.google.com/tpu/docs/tpus-in-compute-engine

## Cloud TPU API: v5e queued resource

```bash
gcloud compute tpus versions list --zone "$ZONE"            # runtime versions available in the zone
gcloud alpha compute tpus queued-resources create my-queued-resource \
  --node-id my-tpu-name \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --accelerator-type v5litepod-8 \
  --runtime-version v2-alpha-tpuv5-lite \
  --service-account "$SERVICE_ACCOUNT"
gcloud alpha compute tpus queued-resources describe my-queued-resource --zone "$ZONE"
gcloud compute tpus tpu-vm ssh my-tpu-name --zone "$ZONE"
```

Add `--spot` for Spot capacity or `--reserved` to use a reservation. Wait for the queued resource state to become `ACTIVE`; a request can sit in a queue until capacity exists.

Runtime versions for PyTorch and JAX (docs table): v6e `v2-alpha-tpuv6e`, v5p `v2-alpha-tpuv5`, v5e `v2-alpha-tpuv5-lite`, v4 and older `tpu-ubuntu2204-base`.

## GKE

Request TPUs with the resource name `google.com/tpu` and select the slice with node selectors:

```yaml
nodeSelector:
  cloud.google.com/gke-tpu-accelerator: <TPU_ACCELERATOR> # tpu-v6e-slice, tpu-v5-lite-podslice, tpu7x-standard-4t (TPU7x per the how-to)
  cloud.google.com/gke-tpu-topology: <TPU_TOPOLOGY> # for example 2x4 (v6e) or 2x2x2 (TPU7x)
  cloud.google.com/placement-policy-name: <WORKLOAD_POLICY> # required for TPU7x only
resources:
  limits:
    google.com/tpu: 8 # must equal the chips the pod uses on the node
```

- TPU slice nodes carry a `google.com/tpu` taint by default.
- TPU7x needs GKE `1.34.1-gke.2541000` or later and, per Google's guidance, a JAX AI image such as `jax0.8.1-rev1` or later.
- For multi-host slices the number of nodes is topology chips divided by chips per VM (a `2x2x2` TPU7x slice with 4-chip VMs is 2 nodes).
- Google's tested serving recipes: v6e on GKE at https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-vllm-tpu, vLLM TPU recipes at https://github.com/AI-Hypercomputer/tpu-recipes (`inference/trillium/vLLM` for v6e on Compute Engine, `inference/ironwood/vLLM` for TPU7x on GKE).

## Discovery during and after creation

```bash
gcloud compute tpus queued-resources list --zone "$ZONE"
gcloud compute tpus tpu-vm describe my-tpu-name --zone "$ZONE" --format='value(state,acceleratorType)'
kubectl get nodes -L cloud.google.com/gke-tpu-accelerator,cloud.google.com/gke-tpu-topology
kubectl describe node <node> | grep -A3 'google.com/tpu'
```

## Capacity models

| Model                | Notes                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------- |
| Standard (on-demand) | Immediate allocation if capacity exists, standard rates                                |
| Flex-start (DWS)     | Discounted, runs uninterrupted up to 7 days; v5e, v5p, v6e only                        |
| Spot                 | Queued resources `--spot`; can be preempted                                            |
| Reservation          | Calendar or future reservations; consume with `--reserved` or GKE reservation affinity |

Read live pricing at https://cloud.google.com/tpu/pricing. Do not copy numbers into skills or notes.
