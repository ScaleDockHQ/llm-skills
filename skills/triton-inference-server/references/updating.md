# Updating Triton

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Releases: https://github.com/triton-inference-server/server/releases (monthly; v2.73.0 = 26.09 on 2026-09-30,
v2.72.0 = 26.08, v2.71.0 = 26.07).

1. Read the release notes and known issues for every release you skip; check the compatibility matrix for driver and
   CUDA changes (26.09 vLLM image: CUDA 13.4.1, driver 615.71.09; 26.07 TensorRT-LLM image: CUDA 13.1, driver 590.44.01).
2. Confirm the image flavor you need exists for the target release: **26.09 ships no TensorRT-LLM backend container**.
3. Pull the new tag on a staging host; run the same repository with `--disable-auto-complete-config` and compare
   `/v2/repository/index` and per-model `config` output with production.
4. Rebuild TensorRT engines (`.plan`) for the new TensorRT version: plans are not portable across TensorRT versions or GPU
   architectures. ONNX and TorchScript models usually carry over; check framework version mismatches ("undefined symbol").
5. Re-run `perf_analyzer` baselines; keep the previous image for rollback.
6. Update clients (`tritonclient`) to the matching release.

Changes in v2.73.0 (26.09): initial Rubin support; C++20 build; `preserve_ordering` restored; fixed
`default_model_filename` autofill for Python-runtime PyTorch models; Python backend shutdown segfault with metrics fixed;
graceful `UNAVAILABLE` for shared-memory requests instead of a crash; OpenAI frontend stream cancellation improved;
`developer_tools` C API wrapper documented as deprecated.
