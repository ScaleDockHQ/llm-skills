# Updating

> Verified against llama.cpp b11557 release assets and docs/build.md, 2026-10-11

llama.cpp releases are tagged `bNNNN`. Update deliberately and re-measure.

```bash
llama-server --version                                   # before
git -C llama.cpp fetch --tags && git -C llama.cpp describe --tags --always
git -C llama.cpp pull && cmake -B build && cmake --build build --config Release -j
llama-bench -m model.gguf -t 8 -p 512 -n 128 -r 3        # compare with the saved baseline
```

- Keep the previous binary until the new one matches or beats the baseline on your model and thread count.
- Re-read `llama-server --help` after an update: flags such as the load mode (`-lm`) change names between releases.
- After a CPU, kernel or hypervisor change (new host, new VM type), re-run discovery and `llama-bench`: the best thread count and NUMA mode can change.
