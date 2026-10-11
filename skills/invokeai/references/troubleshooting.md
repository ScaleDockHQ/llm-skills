# InvokeAI: troubleshooting

> Verified against InvokeAI v6.14.2 (docs faq, lowvram, manual install, config_default.py at tag v6.14.2), 2026-10-11

Start with the server log, `invokeai.yaml`, `nvidia-smi` (or the equivalent) and `/api/v1/app/version`.

| Symptom                                        | Cause                                                         | Fix                                                                                          |
| ---------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `ValidationError` at startup naming a setting  | invalid or unknown key in `invokeai.yaml` or `INVOKEAI_*` env | fix or remove the key; it may exist only in another version                                  |
| Runs on CPU or GPU unused                      | wrong torch backend                                           | reinstall with the right `--torch-backend` (`install.md`) and check the startup log          |
| CUDA out of memory                             | working memory too small, other processes, huge image         | `memory-and-performance.md`: raise `device_working_mem_gb`, quantized model, smaller size    |
| Very slow on Windows NVIDIA when VRAM fills    | sysmem fallback                                               | set Prefer No Sysmem Fallback                                                                |
| Crash with memory allocation errors on Windows | page file limit                                               | system managed page file, free disk                                                          |
| RAM climbs on Linux over time                  | glibc allocator                                               | `MALLOC_MMAP_THRESHOLD_=1048576`                                                             |
| Black or garbled images, NaN                   | wrong precision or VAE for the model, or broken model install | reidentify or reinstall the model; try a different VAE as the model's docs say               |
| UI unreachable from another machine            | bound to `127.0.0.1`                                          | publish via tunnel, proxy or `host`; read `configuration.md` first                           |
| Docker container no GPU                        | missing runtime or driver                                     | `--runtime=nvidia --gpus=all`, host driver, `nvidia-smi` inside the container                |
| Docker entrypoint "no such file" on WSL2       | CRLF line endings                                             | convert `docker-entrypoint.sh` to LF                                                         |
| ROCm generation broken after torch update      | torch 2.12 with rocm7.1                                       | pin `"torch<2.12"` as the install docs say                                                   |
| `401` from the API                             | multi-user mode                                               | login and send the Bearer token (`api.md`)                                                   |
| Model download fails with 401 or 403           | gated repo or missing token                                   | accept the licence, add `remote_api_tokens`                                                  |
| Certificate error installing models on macOS   | Python certs                                                  | run the `Install Certificates.command`                                                       |
| Custom node fails to load                      | missing Python dependency or incompatible release             | install its requirements into the Invoke env, Reload, or remove the pack                     |
| External model errors                          | key missing, quota, provider outage                           | check `api_keys.yaml` key names and the provider account                                     |
| Queue stuck                                    | processor paused or failed item                               | `GET /api/v1/queue/default/status`, resume with `PUT /api/v1/queue/default/processor/resume` |
