# CPU hardware and instruction sets

> Verified against llama.cpp b11557 (docs/build.md, ggml/CMakeLists.txt option list, tools/llama-bench and server READMEs), 2026-10-11

## What the CPU backend uses

llama.cpp's ggml CPU backend picks kernels from the instruction sets it was built with and the CPU reports. The CMake options in `ggml/CMakeLists.txt` name the sets it can target:

| Family  | Options (default per upstream CMake)                                                                                                                                                                                                                                                                            |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| x86     | `GGML_AVX`, `GGML_AVX2`, `GGML_FMA`, `GGML_F16C` (on by default for native builds); `GGML_AVX_VNNI`, `GGML_AVX512`, `GGML_AVX512_VBMI`, `GGML_AVX512_VNNI`, `GGML_AVX512_BF16`, `GGML_AMX_TILE`, `GGML_AMX_INT8`, `GGML_AMX_BF16` (off unless enabled, or picked up by `GGML_NATIVE=ON` on a CPU that has them) |
| AArch64 | NEON baseline; `GGML_CPU_KLEIDIAI=ON` adds Arm KleidiAI microkernels (arm64 only); runtime feature detection selects kernels                                                                                                                                                                                    |
| General | `GGML_CPU_REPACK` (on) repacks Q4_0 weights at load for faster CPU kernels; `GGML_LLAMAFILE`, `GGML_OPENMP` (on by default)                                                                                                                                                                                     |

`GGML_NATIVE` optimizes for the build machine and is on by default except in cross-compile cases upstream turns it off. With `GGML_NATIVE=ON`, the wanted instruction sets are normally detected from the host; flags are only forced when building for another machine.

## Read what the CPU has

```bash
lscpu | grep -E 'Model name|Architecture|Thread\(s\) per core|Core\(s\) per socket|Socket|NUMA node'
lscpu | grep -o -w -E 'avx2|avx512[a-z0-9_]*|avx_vnni|amx[a-z0-9_]*|asimddp|i8mm|sve2?|bf16' | sort -u
llama-server -m model.gguf --version 2>&1 | head -3            # build info; start the server once and read the CPU feature list it logs
```

llama.cpp logs the CPU features its running build enabled at startup (a `system_info` line in current builds; not re-checked in source, confirm on your build). Compare it with `lscpu`: a feature the CPU has but the build lacks is the common reason for a slow CPU run.

## Facts to anchor on

- **Cores versus threads.** Generation is memory-bound, so physical cores matter more than SMT siblings (see `tuning.md`).
- **Memory channels and speed set the ceiling,** not core count. Read DIMM population from the vendor spec or `sudo dmidecode -t memory` (needs sudo; read-only).
- **NUMA.** Multi-socket and some multi-die CPUs expose several nodes; cross-node access is slower (`tuning.md`).
- **Intel Macs** run the `macos-x64` build on CPU only; Apple Silicon belongs to the `apple-silicon` skill.
- **Windows:** `win-cpu-x64` and `win-cpu-arm64` release archives exist; upstream documents an arm64 clang build (`arm64-windows-llvm-release`) because MSVC NEON support may be incomplete.

## Official links

- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/ggml/CMakeLists.txt
