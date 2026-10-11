# Troubleshooting CPU inference

> Verified against llama.cpp b11557 (build.md, server README, bench README), 2026-10-11

| Symptom                                     | Cause                                                                 | Fix                                                                                                 |
| ------------------------------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `Illegal instruction` (SIGILL) on start     | Binary built for a newer CPU than the host (AVX-512, AMX, newer Arm)  | Rebuild on the host with `GGML_NATIVE=ON`, or build portable (`GGML_NATIVE=OFF`) / dynamic backends |
| Much slower than expected                   | Generic or no-AVX build, wrong thread count, NUMA cross-traffic, swap | Compare `system_info` with `lscpu`; sweep `-t` in `llama-bench`; try `--numa`; check `free -h`      |
| Decode flat above N threads                 | Memory bandwidth saturated                                            | Use fewer threads; smaller quant; faster memory (`sizing.md`)                                       |
| Prompt processing very slow on long prompts | Prefill is compute-bound on CPU                                       | More `-tb`, BLAS for batch above 32, AMX or KleidiAI-capable CPU, shorter prompts, prompt caching   |
| Process killed (OOM) at load or under load  | Weights + KV + overhead exceed RAM, or a cgroup limit                 | Smaller quant or context (`-c`), fewer slots (`-np`); `free -h`; check container memory limit       |
| Swap in use, speed collapses                | Model does not fit alongside other processes                          | Smaller model; `-lm mlock` on a dedicated host (needs memlock limit); stop other workloads          |
| `mlock` fails / "failed to mlock"           | Memory-lock limit too low                                             | Raise `ulimit -l` (or systemd `LimitMEMLOCK`) with approval; or drop `mlock`                        |
| Slower after enabling `--numa`              | Wrong mode for the model size                                         | Try `isolate` for one-node models, `distribute` for larger; drop the page cache first               |
| BLAS build not faster for generation        | BLAS only helps prompt processing at batch > 32                       | Expected; tune threads and quant instead                                                            |
| `--list-devices` shows no GPU               | CPU-only build, which is correct here                                 | Use a GPU build only if a GPU exists (`llama-cpp`)                                                  |
| Results vary run to run                     | Shared host, turbo/thermal limits, other jobs                         | Pin with `-C`/`-Cr`, quiet the host, use `-r 3` or more                                             |
| Docker run is slower than native            | Generic image kernels, CPU quota limits                               | Raise `--cpus`, build natively, check cgroup CPU limits                                             |
