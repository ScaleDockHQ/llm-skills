# Troubleshooting

> Verified against mistral.rs v0.9.4 (docs `reference/troubleshooting`, `guides/deploy/*`, `guides/perf/*`), 2026-10-11

First, always: `mistralrs doctor` (hardware, compiled accelerator features, Hugging Face connectivity), then `-v` logs.

| Symptom                                         | Likely cause                                                                        | Fix                                                                                                                 |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `mistralrs: command not found`                  | New shell lacks `~/.local/bin`                                                      | Open a new shell or `source "$HOME/.mistralrs/env"`; cargo installs use `~/.cargo/bin`                              |
| Installer builds from source or refuses a lane  | Driver too old for any lane, or unsupported GPU (pre-Ampere)                        | Update the driver, check the lane table in `install.md`; `MISTRALRS_INSTALL_ALLOW_CUDA_MISMATCH=1` is a last resort |
| `flash-attn` build error                        | Compute capability below 8.0                                                        | Rebuild without `flash-attn` (`cuda cudnn`, plus `nccl` if installed)                                               |
| Doctor shows no `cuda`, generation slow         | CPU build, or wrong image or binary                                                 | Install the CUDA build or a `cuda*-sm*` image; confirm `--gpus all` and the container toolkit                       |
| `mistralrs login` rejects the token             | Token not starting with `hf_`                                                       | Create a Hugging Face read token                                                                                    |
| 401 or 403 on download                          | Gated repo, license not accepted, or no token                                       | Accept the license, `mistralrs login` or `HF_TOKEN` (from a `0600` file)                                            |
| OOM at load                                     | Model plus KV pool exceed memory                                                    | `--quant 4`, `--quant 2`, `-n "0:N1;1:N2"`, lower `--pa-memory-fraction`, smaller `--max-model-len`                 |
| OOM after load, under traffic                   | `--max-seqs` too high for the KV pool, or another GPU tenant                        | Size the KV pool explicitly, lower `--max-seqs`, stop the other tenant                                              |
| Start takes many minutes                        | Download plus ISQ quantization                                                      | Wait; produce a UQFF once and use `--from-uqff`; persist `HF_HOME`                                                  |
| Probe passes but requests fail                  | `/health` is liveness only                                                          | Probe `/v1/models` `status == loaded`                                                                               |
| `Connection refused` from another host          | Bound to loopback, or published only to `127.0.0.1`                                 | Check the `Server listening on ...` line; use a reverse proxy rather than binding wide                              |
| Browser CORS errors                             | Not expected (any origin allowed); a proxy may be stripping headers                 | Check the proxy; CORS is only changeable by embedding the router                                                    |
| `413 Payload Too Large`                         | 50 MB body limit (large images, base64 files)                                       | Upload via `/v1/files`, shrink inputs, or embed the router with a larger limit                                      |
| `/ui` does not load                             | `--no-ui`, or the proxy rewrites the path                                           | Remove `--no-ui`; fix the proxy                                                                                     |
| Response cut off                                | `max_tokens` too low                                                                | Check `finish_reason`: `length` means the limit was hit                                                             |
| Sessions vanish                                 | 30-minute idle TTL or 128-session cap                                               | Export and import via `/v1/sessions/{id}`                                                                           |
| MTP load error                                  | Paged attention off (Metal, CPU, or `--paged-attn off`)                             | Use CUDA with paged attention; the assistant must match the target family                                           |
| `--mtp` fails on a UQFF                         | UQFF lacks `mtp.*` tensors                                                          | Re-quantize including them, or load the safetensors model                                                           |
| NCCL hang at startup (multi-node)               | Wrong network interface, head port unreachable                                      | `NCCL_SOCKET_IFNAME`, open the head port privately, same binary and flags on all nodes                              |
| Multi-GPU launch error about heads              | GPU count does not divide attention or KV heads                                     | Restrict `CUDA_VISIBLE_DEVICES` to a compatible count, or use `-n` layer mapping with `MISTRALRS_NO_NCCL=1`         |
| CUDA graph capture warnings                     | A path that cannot be captured                                                      | Logged and disabled for that pipeline; compare with `MISTRALRS_CUDA_GRAPHS=0`                                       |
| `ImportError` on `from mistralrs import Runner` | Wrong wheel (CPU or Metal wheel on NVIDIA, or wrong `+cudaNNN.smNN`)                | Install the CUDA wheel matching driver and GPU                                                                      |
| Agent request fails validation with `ask`       | Non-streaming request                                                               | Set `stream: true` for HTTP requests with `agent_permission: "ask"`                                                 |
| Code or shell tool refused                      | Tool not enabled, `--agent-permission deny`, or sandbox mode `on` without isolation | Enable the specific flag, check permission and `--sandbox` settings                                                 |
| Metrics 503                                     | `--disable-metrics`, or startup still initializing                                  | Remove the flag; wait for startup                                                                                   |
| `lora_runtime_unavailable` (409)                | Model started without dynamic LoRA                                                  | Add `--enable-lora` or preload with `--lora`                                                                        |
| LoRA load returns 429                           | Loads are serialized                                                                | Retry; verify the generation via `GET /v1/lora_adapters`                                                            |
| Tool call arrives as plain text                 | Model or template lacks tool support, or wrong template                             | Use a tool-capable model, `-c` with the right template (`.jinja` or `.json`)                                        |
| Unknown architecture                            | Not in the loader registry                                                          | Match `config.json` `architectures` to `reference/supported-models`; GGUF compatibility list; file an issue         |

## Collect before filing upstream

```bash
mistralrs --version; mistralrs doctor
nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.used,memory.total --format=csv
mistralrs serve -v ... 2>&1 | tee /tmp/mistralrs.log        # then redact any tokens before sharing
```

Never paste `HF_TOKEN` or the contents of a `--log` file that holds user prompts. Report at
`https://github.com/EricLBuehler/mistral.rs/issues` with a reproducer.
