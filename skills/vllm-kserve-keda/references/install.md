# Install KServe, KEDA and a pinned vLLM runtime

> Verified against KServe v0.21.0, KEDA v2.21.0 (KServe pins 2.20.2), vLLM v0.31.0, 2026-10-11

## Versions and what pins what

| Item                                     | Value                                                  | Source                                          |
| ---------------------------------------- | ------------------------------------------------------ | ----------------------------------------------- |
| KServe release                           | v0.21.0, published 2026-09-25                          | GitHub releases `kserve/kserve`                 |
| KEDA release                             | v2.21.0, published 2026-09-23                          | GitHub releases `kedacore/keda`                 |
| KEDA version in KServe scripts           | 2.20.2 (`KEDA_VERSION` in `kserve-deps.env`)           | KServe repo at tag v0.21.0                      |
| KEDA OTel add-on in KServe scripts       | v0.0.6                                                 | same file                                       |
| Kubernetes minimum                       | 1.32                                                   | KServe quickstart docs                          |
| vLLM in `kserve-huggingfaceserver` image | 0.24.0 (Dockerfile `VLLM_VERSION`)                     | KServe repo at tag v0.21.0                      |
| vLLM in `kserve-vllmserver` runtime      | `vllm/vllm-openai:v0.21.0` in the v0.21.0 release YAML | `install/v0.21.0/kserve-cluster-resources.yaml` |

The last row looks like a release-tooling artefact (the tag matches KServe's version, not vLLM's). Read what your cluster has and override it:

```bash
kubectl get clusterservingruntime kserve-vllmserver -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Both projects are actively maintained (releases within the last month, repos not archived).

## Install paths

KServe v0.21.0 publishes install scripts as release assets. Download, read, then run them. Do not pipe to bash blindly.

```bash
V=v0.21.0
mkdir -p ~/kserve-install && cd ~/kserve-install
for f in kserve-standard-mode-dependency-install.sh keda-dependency-install.sh \
         kserve-standard-mode-full-install-with-manifests.sh; do
  curl -fsSLO "https://github.com/kserve/kserve/releases/download/$V/$f"
done
less kserve-standard-mode-dependency-install.sh      # review, then ask the user to approve
```

Options, in order of preference:

1. **Release scripts (Standard mode, v0.21.0 images).** `kserve-standard-mode-full-install-with-manifests.sh` installs cert-manager, the KServe controller and the bundled runtimes in Standard mode. It leaves `LLMInferenceService` off by default (`ENABLE_LLMISVC` is `False` in the script). Add that with `llmisvc-dependency-install.sh` and `llmisvc-full-install-with-manifests.sh` only when you need it.
2. **KEDA from its own chart (recommended for the autoscaler).** Gives you control of the KEDA version:

   ```bash
   helm repo add kedacore https://kedacore.github.io/charts
   helm repo update
   helm search repo kedacore/keda --versions | head -5
   helm install keda kedacore/keda --namespace keda --create-namespace --version 2.20.2
   ```

   Use 2.20.2 to match what KServe tested. Move to 2.21.0 only after reading the KEDA 2.21 breaking changes (the `keda` skill, or the KEDA release notes: bound service account token audience change). Do not skip the `helm search` check: chart versions can lag app versions.

3. **KServe Helm charts.** The OCI charts under `oci://ghcr.io/kserve/charts/` had only `v0.20.0` and `v0.21.0-rc1` tags on 2026-10-11, no final `v0.21.0`, and the chart image tag follows the chart appVersion. Prefer the release scripts for v0.21.0. If you must use Helm, pick `v0.20.0` and say so, or accept rc1 knowingly. Recheck with the registry before relying on this.

Installing `kserve-standard-mode-dependency-install.sh` pulls its own pinned cert-manager. If cert-manager, Gateway API or Prometheus already exist, say so in the approval request so the script does not overwrite them.

## Set Standard mode

Standard mode is required for KEDA. Check the cluster default and the controller:

```bash
kubectl get cm inferenceservice-config -n kserve -o json | jq -r '.data.deploy'
kubectl get pods -n kserve
kubectl get crd inferenceservices.serving.kserve.io llminferenceservices.serving.kserve.io
```

Per service you can always set `serving.kserve.io/deploymentMode: "Standard"` instead of changing the default.

## Model access

```bash
kubectl create namespace llm-serving
umask 077
printf '%s' "$HF_TOKEN" > /tmp/hf-token && \
kubectl -n llm-serving create secret generic hf-token --from-file=HF_TOKEN=/tmp/hf-token
rm -f /tmp/hf-token
```

Never echo `HF_TOKEN`. Public models do not need it. For `hf://` model URIs the storage initializer reads the token from the Secret referenced by the `InferenceService` service account or the `HF_TOKEN` env var; confirm with `kubectl describe isvc` events if download fails (see the `kserve` skill for the Secret and ServiceAccount wiring).

## Pinned vLLM runtime

Copy the upstream `kserve-vllmserver` runtime under your own name and pin the image. Fetch the current upstream version first so you inherit probes and env:

```bash
kubectl get clusterservingruntime kserve-vllmserver -o yaml > /tmp/vllm-runtime.yaml
```

Edit the copy (new `metadata.name`, drop `uid`, `resourceVersion`, `creationTimestamp`, `managedFields`, `ownerReferences`, set the image) so that the important fields are:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ClusterServingRuntime
metadata:
  name: vllm-pinned
  annotations:
    serving.kserve.io/server-type: vllmserver
spec:
  annotations:
    prometheus.kserve.io/port: "8080"
    prometheus.kserve.io/path: "/metrics"
  supportedModelFormats:
    - { name: vLLM, version: "1", autoSelect: false }
  containers:
    - name: kserve-container
      image: vllm/vllm-openai:v0.31.0 # tag exists on Docker Hub, 2026-10-11
      command: [python, -m, vllm.entrypoints.openai.api_server]
      args:
        ["--port=8080", "--served-model-name={{.Name}}", "--model=/mnt/models"]
```

Keep the upstream `env`, probes (`/v1/models`, long `startupProbe`), `/dev/shm` volume and `securityContext` from the copy. Then:

```bash
kubectl apply --dry-run=server -f /tmp/vllm-runtime.yaml     # review, then ask to apply
```

`vllm/vllm-openai:v0.31.0` and `vllm/vllm-openai-cpu:v0.31.0` both exist. KServe rewrites the image to the `-cpu` sibling when the service requests no GPU. Engine flags go in `args` on the `InferenceService`; see the `vllm` skill.

The alternative is the `kserve-huggingfaceserver` runtime (`modelFormat: huggingface`), which bundles vLLM 0.24.0 and also supports a Hugging Face backend. Use it when you want KServe's own OpenAI/embedding handling and can live with the older engine.
