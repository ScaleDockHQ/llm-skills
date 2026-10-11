# NVIDIA NIM install

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: NIM for LLM and VLM docs (prerequisites, installation, Helm, NIM Operator, air-gap pages).

## Requirements

| Item              | Minimum                                           |
| ----------------- | ------------------------------------------------- |
| CPU               | AMD64 or ARM64                                    |
| GPU               | Any supported NVIDIA GPU (see the Support Matrix) |
| OS                | Ubuntu 22.04 LTS or later recommended             |
| Driver            | 580 or later                                      |
| CUDA SDK          | 12.9 or later                                     |
| Docker            | 24.0 or later                                     |
| Container Toolkit | 1.14.0 or later                                   |

Other Linux distributions may work but are not officially validated. Kubernetes needs 1.26 or later and
Helm 3. Memory per profile is shown by `list-model-profiles`; the docs example is Llama 3.1 8B Instruct
needing at least 24 GB.

## Images

```bash
docker pull nvcr.io/nim/meta/llama-3.1-8b-instruct:2.0.13   # model-specific
docker pull nvcr.io/nim/nvidia/model-free-nim:2.0.13        # model-free
```

The docs say the exact image and tag vary by container type and backend. Take them from the Support Matrix
or the NGC Catalog page. Model-free images are listed on NGC as "SGLang Model-Free NIM" and "vLLM
Model-Free NIM", so confirm which backend your tag carries.

## Login

Most current public NIM images pull without login. Authenticate when you use a Production Branch NIM, a
release before 2.0.10, or a private or gated image or model artifact.

```bash
printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin
```

`$oauthtoken` is a literal username. Keep the key in an environment variable or a `0600` file.

## Docker

See `templates/docker-compose.yml`. Mount a persistent directory on `NIM_CACHE_PATH` (default
`/opt/nim/.cache`). `NIM_WRITABLE_ROOT` (default `/opt/nim`) holds generated files such as the nginx
config; keep it writable if you run a read-only root filesystem.

## Air-gapped

1. On a connected host, run `download-to-cache` (all profiles with `--all`, or `-p <profile-id>`) with the
   cache directory mounted.
2. Mirror the NIM image, and any init containers or sidecars you enable, to a registry the cluster reaches.
3. Move the cache. For a model-free NIM, the first connected start can persist the generated manifest in
   the cache; later starts with the same cache need no outbound calls or keys.
4. Set `NIM_DISABLE_MODEL_DOWNLOAD` if you want startup to fail rather than reach out.
5. `create-model-store -p <profile> -m <path>` materialises a cached profile as a plain model store, and
   `mirror s3|gcs -b <bucket>` copies cached profiles to a bucket.

## Kubernetes with Helm

```bash
export HELM_CHART_VERSION="<version from NGC>"
helm fetch "https://helm.ngc.nvidia.com/nim/charts/nim-llm-${HELM_CHART_VERSION}.tgz" \
  --username='$oauthtoken' --password="${NGC_API_KEY}"
tar -xzf "nim-llm-${HELM_CHART_VERSION}.tgz"
helm show values nim-llm/ | less
helm install my-nim nim-llm/ -f values.yaml
```

Key values: `image.repository`, `image.tag`, `model.ngcAPISecret`, `imagePullSecrets`, `persistence`,
`resources`, `customArgs`, `env`, `statefulSet.enabled` and `deployment.strategy`. Use a `Recreate`
strategy when spare GPU capacity is scarce during upgrades. `model.nimCache` (default `/model-store`)
derives `NIM_CACHE_PATH`, `HF_HOME` and `OUTLINES_CACHE_DIR`. For credentials create the secrets from the
environment (`kubectl create secret ... --from-literal=NGC_API_KEY="${NGC_API_KEY}"`), never from a
file in git. See `templates/helm-values.yaml`.

`customArgs` entries are separate list items (option and value each) and preserve any image-provided
`NIM_PASSTHROUGH_ARGS`. Do not override `NIM_PASSTHROUGH_ARGS` itself in `env`; Kubernetes replaces the
image value.

## Kubernetes with the NIM Operator

Needs the GPU Operator, a storage provisioner and NIM Operator 3.0.2 or later. Two resources:
`NIMCache` (`apps.nvidia.com/v1alpha1`, pre-populates the model cache; set `engine` to `vllm` or `sglang`
to match the image) and `NIMService` (deployment, probes, service, GPU scheduling). Create the image pull
secret and an `NGC_API_KEY` secret first, wait for the `NIMCache` to be Ready, then apply the
`NIMService`. See `templates/nim-operator.yaml`. Verify with `kubectl get nimcache,nimservice -n <ns>`
and a port-forward to `/v1/models`.

Other documented targets: KServe, OpenShift, Run:ai, vGPU, and cloud pages for AWS, Azure, Google Cloud
and Oracle.
