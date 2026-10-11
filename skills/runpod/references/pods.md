# Runpod Pods: rent a GPU and serve an LLM

> Verified against docs.runpod.io pods/overview, pods/storage/types, pods/templates/overview, pods/connect-to-a-pod, runpodctl v2.15.0 (pod, template, gpu, network-volume, datacenter references), 2026-10-11

A Pod is a dedicated GPU container billed per second while it exists. Use a Pod for development, long jobs and a single always-on model. Use Serverless (`serverless-vllm.md`) when traffic is bursty.

## Pick hardware

```bash
runpodctl gpu list                        # available GPUs: gpuId, memoryInGb, stockStatus, secureCloud, communityCloud
runpodctl gpu list --include-unavailable
runpodctl datacenter list                 # data center IDs, needed for network volumes
runpodctl template search vllm --type official
runpodctl template get <template-id>      # README, env vars, exposed ports
```

Use the `gpuId` string exactly as listed (for example `"NVIDIA GeForce RTX 4090"`). Size VRAM with the `choosing-hardware` skill. Secure Cloud and Community Cloud differ in hosting and price; network volumes are Secure Cloud only.

## Storage types

| Type           | Survives stop | Survives terminate | Notes                                                                                                                             |
| -------------- | ------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| Container disk | No            | No                 | Fast local scratch, erased on stop                                                                                                |
| Volume disk    | Yes           | No                 | Mounted at `/workspace` by default; still billed while stopped                                                                    |
| Network volume | Yes           | Yes                | Tied to one data center, Secure Cloud only, attach at deploy time only, mounts at `/workspace`, shared across Pods and Serverless |

Put model weights on a volume disk or network volume so a restart does not re-download them. Set `HF_HOME` to a path under `/workspace` when the template does not.

## Create a Pod (approval first)

Creating a Pod starts billing. State GPU, cloud type, disk sizes and a maximum runtime, and get a yes.

```bash
runpodctl pod create \
  --name vllm-qwen \
  --template-id <template-id> \
  --gpu-id "NVIDIA GeForce RTX 4090" \
  --cloud-type SECURE \
  --ports "8000/http" \
  --wait
```

Verified flags: `--template-id`, `--image`, `--gpu-id`, `--name`, `--compute-type`, `--cloud-type`, `--public-ip`, `--ports`, `--ssh`, `--wait`, `--wait-timeout` (default 10m). Run `runpodctl pod create --help` for disk, volume and env flags, which the fetched docs did not list. Accepted values of `--cloud-type` are unverified; check `--help`.

If `--wait` times out the CLI exits with error code `wait_timeout` **and the Pod still exists and bills**; the error body carries the Pod `id`. Poll it or delete it.

```bash
runpodctl pod list                        # add --all to include stopped Pods (verify with --help)
runpodctl pod get <pod-id>                # runtimeStatus: running | initializing | stopped | terminated | unknown
runpodctl pod logs <pod-id> --tail 100    # also --follow, --since, --source
runpodctl pod stop <pod-id>               # keeps volume disk, still bills for storage
runpodctl pod delete <pod-id>             # terminate: removes the Pod and its volume disk
```

## Serve vLLM from a Pod

1. Use a template or image that runs `vllm serve` (for example `vllm/vllm-openai:<pinned-version>`). Pin the version; do not use `latest`.
2. Expose port 8000 as `8000/http`. Set `HF_TOKEN` through a Runpod secret for gated models.
3. Start the server bound to all interfaces: `vllm serve <model> --host 0.0.0.0 --port 8000 --api-key "$VLLM_API_KEY"`. Engine flags belong to the `vllm` skill.
4. The proxy URL is `https://<pod-id>-8000.proxy.runpod.net`. Test `GET /v1/models` with the key.

```bash
curl -s https://<pod-id>-8000.proxy.runpod.net/v1/models -H "Authorization: Bearer $VLLM_API_KEY" | jq '.data[].id'
```

Caveats:

- `--api-key` protects the `/v1`, `/v2` and `/inference` paths only. `/health`, `/metrics` and docs routes stay open on the proxy URL.
- Treat the proxy URL as public: always run vLLM with `--api-key`, and keep the real consumer behind your own gateway.
- A `502` from the proxy means the app is not running yet, no GPU is attached, or the server is not bound to `0.0.0.0` on the exposed port. Read `runpodctl pod logs` and the template README first. Large models can take several minutes to load; the proxy returns 502 until the port opens.
- The proxy's request timeout is unverified here; stream long generations (`stream: true`) so connections stay active.

## SSH and file transfer

- `runpodctl ssh` manages SSH keys and connection info (see `runpodctl ssh --help`). Add a public key in the console or via `runpodctl doctor`.
- `runpodctl send <file>` and `runpodctl receive <code>` move files peer to peer with a one-time code.
- Network volumes also expose an S3-compatible API (console credentials page creates the S3 key) for uploading weights without a running Pod.

## Network volumes

```bash
runpodctl network-volume create --name models --size 100 --data-center-id US-GA-1   # size 1-4000 GB
runpodctl network-volume list
runpodctl network-volume update <volume-id> --size 200                               # can only grow
runpodctl network-volume delete <volume-id>                                          # permanent, deletes data
```

A network volume bills even with no Pod attached.
