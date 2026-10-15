# llama-swap on DGX Spark

> Verified against llama-swap v263 (docker/unified README, releases), 2026-10-11

- Release `linux_arm64` tarball for the host binary, or `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (multi-arch; the only arm64 image, built because GB10 `sm_121` needs a CUDA 13 `nvcc`).
- Run the host binary when engines are separate containers: it needs no GPU and starts them with `docker run`. Give the service user the `docker` group and `TimeoutStopSec` of 180 or more so wrapper scripts can stop containers.
- Raise `unloadTimeout` (90 s) and `healthCheckTimeout` (900 s); large models on unified memory take minutes to load.
- Dual-node models: have a wrapper script start and stop both nodes in `cmd` and `cmdStop`; llama-swap only knows the head process. The stack wrapper and assets live in the `self-hosted-llms` skill; platform memory and networking details in `nvidia-dgx-spark`.
- Memory is shared with the OS: a container started outside llama-swap holds memory it cannot see (`docker ps`).

Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark` and `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
