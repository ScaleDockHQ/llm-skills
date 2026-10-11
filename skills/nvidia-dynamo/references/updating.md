# NVIDIA Dynamo updating

> Verified against Dynamo v1.5.1, 2026-10-11

Releases: https://github.com/ai-dynamo/dynamo/releases (latest stable here: v1.5.1, 2026-10-07; `-dev` tags such as
`v1.6.0-...-dev.N` are model early-access pre-releases).

## Procedure

1. Read the release notes of every version you skip: breaking changes and known issues are listed there.
2. Check the support matrix (driver, CUDA, Python) and the mixed-version window: frontend and workers may differ by up
   to N-2 releases, but prefill-to-decode links are not covered. Upgrade a prefill/decode pair together.
3. Bump images, wheel (`ai-dynamo[<backend>]==X.Y.Z`) and Helm chart together. Kubernetes: `helm upgrade` the platform
   (CRDs follow `dynamo-operator.upgradeCRD`), then roll DGD images. Worker spec changes create new runtime namespaces,
   so frontends can serve old and new generations during the roll.
4. Smoke test (`/health`, one completion, one streamed request, metrics), re-run the AIPerf baseline, keep the old
   image tag for rollback.
5. Set a graceful shutdown timeout and enable migration so rolling updates and scale-downs do not drop requests.

## v1.5.1 changes that need action

- Workers fetching media through an ambient HTTP proxy need `DYN_MM_TRUST_EGRESS_PROXY=1` (not needed for direct or
  `NO_PROXY` hosts).
- SGLang diffusion `input_reference` local files need `DYN_MM_LOCAL_PATH` naming the allowed directory.
- Inline `data:` URLs over `DYN_MM_MAX_DATA_URL_MB` (16 MiB) return HTTP 400; set it on both frontend and workers to raise.
- Remote media size cap `DYN_MM_MAX_FILE_SIZE_MB` (64 MiB); vLLM-Omni image sides must be 1-4096.
- `DYN_HTTP_BACKEND=httpx` is ignored (aiohttp only).
- Responses omit absent optional fields (`usage`) instead of `null`: fix clients that index raw dicts.
- Backends in 1.5.1: SGLang 0.5.18, TensorRT-LLM 1.3.0rc25, vLLM 0.28.0; ModelExpress 0.6.0.
- Docs example Helm version (1.2.1) and the Release Artifacts page can lag: take versions from the releases page.

Known issues at v1.5.1 (fix targeted for v1.6.0): SGLang sidecar inference returns HTTP 500
`'GenerateReqInput' object has no attribute 'batch_size'`; some H.264 videos crash the worker (PyNvVideoCodec 2.2.3).
