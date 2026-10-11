# Unified memory, sizing and the GPU wired limit

> Verified against mlx-lm 0.32.0 (README "Large Models"), mlx 0.32.3, llama.cpp b11557, macOS 26.6 (`sysctl iogpu.wired_limit_mb` read locally), 2026-10-11

Behaviour that upstream does not document is marked (community) or (OS, observed on macOS).

## Budget

```text
weights (size of the quantized checkpoint)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_seqs
+ runtime overhead (compute buffers, prefill; measure)
+ macOS and apps headroom (at least 8 GB on 32 GB+ machines; more with a browser, IDE or VM open)
<= unified memory
```

Rough weights: parameters in billions x bits per weight / 8, in GB (arithmetic, not an upstream rule). Read `layers`, `num_key_value_heads` and `head_dim` from the model's `config.json`. Measure the peak during a long-context request, not at idle.

Check pressure while generating:

```bash
memory_pressure | tail -2           # system-wide free percentage
sysctl vm.swapusage                 # growing "used" means the model does not fit
```

Yellow or red pressure, or swap growth during generation: pick a smaller quant or context. Do not raise the wired limit to compensate.

## The wired limit (`iogpu.wired_limit_mb`)

macOS caps how much unified memory the GPU may wire (pin so it cannot be paged out). A model larger than the cap loads slowly, is refused or spills. mlx-lm wires model and cache memory itself on macOS 15+; if the model is large relative to RAM it prints:

> [WARNING] Generating with a model that requires ...

and upstream says that if the model fits in RAM it can often be sped up by raising the system wired limit to a value larger than the model in MB and smaller than machine memory.

```bash
sysctl iogpu.wired_limit_mb                 # read, no sudo; 0 = system default, not unlimited
sudo sysctl iogpu.wired_limit_mb=N          # N in MB; ASK FIRST, state N and the undo
sudo sysctl iogpu.wired_limit_mb=0          # undo: back to the default
```

Rules:

- It needs `sudo` and changes system state: get approval, name N and the undo command.
- Choose N from model size + KV + headroom, not "total minus a little". Setting it near total RAM can starve macOS: swapping, freezes, a kernel panic (community).
- It applies immediately; restart the runtime so it picks the new value up. (OS)
- It resets at reboot (community; Apple does not document the key). Persisting it through `/etc/sysctl.conf` or a root LaunchDaemon is possible but not recommended: every boot then runs with less headroom.
- It does not create memory; it only changes how much of it the GPU may lock.
- Default share is community-reported at roughly two thirds to three quarters of RAM and varies with RAM size and macOS. llama.cpp prints the real figure at startup as `recommendedMaxWorkingSetSize` in the `ggml_metal_init` log lines.

```bash
llama-server -m model.gguf -ngl all 2>&1 | grep -i recommendedMaxWorkingSetSize   # read the cap the Metal backend sees
```

Reduce memory before touching the limit: smaller quant, lower `-c`, quantized KV cache (`-ctk q8_0 -ctv q8_0` in llama.cpp; `--kv-bits` in mlx-lm), MLX `--prefill-step-size` lower (peak memory on long prompts).

## Official links

- https://github.com/ml-explore/mlx-lm#large-models
- https://github.com/ggml-org/llama.cpp/issues/16646
