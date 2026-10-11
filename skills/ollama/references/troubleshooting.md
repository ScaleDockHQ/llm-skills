# Ollama: troubleshooting

> Verified against Ollama v0.40.3, 2026-10-11

Docs: troubleshooting, faq, gpu, docker, windows, import; source: server/routes.go host check, cmd/cmd.go, server/create.go

Start with `ollama -v`, `ollama ps`, `GET /api/ps` and the logs (`observability.md`). Add `OLLAMA_DEBUG=1` before filing an issue.

| Symptom                                                                                        | Cause and fix                                                                                                                                                                                                                                                              |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prompts truncated, agents "forget", tools misbehave                                            | Default context is 4k below 24 GiB VRAM. Set `OLLAMA_CONTEXT_LENGTH` (64000+ for agents) or Modelfile `num_ctx`. Verify CONTEXT in `ollama ps`                                                                                                                             |
| `ollama ps` shows `100% CPU` or a CPU/GPU split; slow                                          | Model plus context does not fit VRAM, or the GPU was not discovered. Lower context or `OLLAMA_NUM_PARALLEL`, use `OLLAMA_KV_CACHE_TYPE=q8_0`, smaller quant; otherwise see GPU sections below                                                                              |
| Requests hang, time out behind a proxy                                                         | Memory is short, so requests queue until another model unloads. Preload, lower `OLLAMA_MAX_LOADED_MODELS`, raise proxy timeouts, or reduce sizes                                                                                                                           |
| HTTP 503                                                                                       | Queue exceeded `OLLAMA_MAX_QUEUE` (512). Slow down clients or raise it                                                                                                                                                                                                     |
| HTTP 403, empty body, through nginx, a tunnel or a custom hostname, while bound to `127.0.0.1` | Host header rejected. Allowed: `localhost`, machine hostname, `*.local`, `*.localhost`, `*.internal`, private/loopback IPs. Rewrite `Host` to `localhost:11434` in the proxy or tunnel (`serve-config.md`)                                                                 |
| Browser or extension gets CORS errors                                                          | Add the origin to `OLLAMA_ORIGINS`                                                                                                                                                                                                                                         |
| Connection refused from another machine                                                        | Default bind is loopback. Setting `OLLAMA_HOST=0.0.0.0:11434` exposes an unauthenticated API; put auth or a VPN in front first. In systemd the variable must be in the unit, not your shell                                                                                |
| Settings do nothing                                                                            | Wrong place for the platform: macOS app needs `launchctl setenv` plus restart; systemd needs `systemctl edit` plus `daemon-reload` and `restart`; Windows needs a user variable and an app restart; Docker needs `-e`. Check the effective values with the discovery block |
| Two servers on port 11434                                                                      | App plus manual `ollama serve`, Windows plus WSL2, or a stale container. The client prints `Warning: client version is X` when server and client differ. Stop one                                                                                                          |
| `LoRA adapters are no longer supported`                                                        | `ADAPTER` in a Modelfile or adapter GGUF/API `adapters`. Merge into the base weights and import the merged model                                                                                                                                                           |
| Import fails on a split GGUF                                                                   | Keep the original shard names and use `FROM ./model-*.gguf` (or one `FROM` per shard). Mixed model types and non-GGUF inputs are rejected                                                                                                                                  |
| Imported GGUF answers with garbage or never stops                                              | Wrong or missing `TEMPLATE`/stop tokens. The template comes from GGUF metadata (`tokenizer.chat_template`) when present; set `TEMPLATE` and `PARAMETER stop` explicitly, or use `hf.co/...` with a `template` file in the repo                                             |
| `hf.co/...` pull picks the wrong quant                                                         | Add `:<quant>` (for example `:Q8_0`) or the exact `.gguf` file name                                                                                                                                                                                                        |
| Pull fails behind a proxy                                                                      | Set `HTTPS_PROXY` only (not `HTTP_PROXY`), install the proxy CA as a system certificate; containers need the env var too                                                                                                                                                   |
| Model store full or in the wrong place                                                         | `OLLAMA_MODELS`; on Linux `sudo chown -R ollama:ollama <dir>`. `ollama rm` unused tags; shared blobs stay                                                                                                                                                                  |
| Model deleted from a shared store by a second server                                           | Startup pruning. Set `OLLAMA_NOPRUNE=1` on every server sharing the store                                                                                                                                                                                                  |
| Cloud model errors or "unauthorized"                                                           | Run `ollama signin` (local server) or send `Authorization: Bearer $OLLAMA_API_KEY` to `https://ollama.com`. If `OLLAMA_NO_CLOUD=1` is set, cloud is disabled (`GET /api/status`)                                                                                           |
| Structured output rejected on a cloud model                                                    | Cloud models do not support structured outputs; use a local model                                                                                                                                                                                                          |
| `tool_choice` ignored                                                                          | Not supported on `/v1/chat/completions` or `/v1/messages`; instruct in the prompt or validate in code                                                                                                                                                                      |
| `/v1` ignores my context size                                                                  | The OpenAI API has no context field. Use the env var or a Modelfile-derived model                                                                                                                                                                                          |

## NVIDIA (Linux)

- Needs driver 550+ (570+ for compute capability 5.0 to 6.2). Check `nvidia-smi`.
- Errors in the log such as codes `3`, `46`, `100`, `999`: container runtime working? `docker run --gpus all ubuntu nvidia-smi`. Is `nvidia_uvm` loaded (`sudo nvidia-modprobe -u`)? Reload with `sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm`. Then reboot, then update the driver.
- After suspend/resume Ollama may fall back to CPU: reload `nvidia_uvm` as above.
- More logs: `CUDA_ERROR_LEVEL=50`, `sudo dmesg | grep -i nvrm`, `sudo dmesg | grep -i nvidia`.
- Docker works at first, then falls back to CPU with discovery failures: set `"exec-opts": ["native.cgroupdriver=cgroupfs"]` in `/etc/docker/daemon.json`, restart Docker.
- Jetson in a container: set `JETSON_JETPACK=5` or `6`.

## AMD

- Linux needs the ROCm v7 kernel driver (`amdgpu-install`); the distribution's in-kernel driver is often older. Symptom of an old driver: log lines `failure during GPU discovery ... failed to finish discovery before timeout` and `bootstrap discovery took duration=30s`, then CPU fallback. Upgrade, reboot, restart Ollama.
- Permissions: user or `ollama` in `video` and `render` groups for `/dev/kfd`. Containers: `--device /dev/kfd --device /dev/dri`, extra `--group-add <numeric gid>` from `ls -lnd /dev/kfd /dev/dri /dev/dri/*`, and on SELinux `sudo setsebool container_use_devices=1`.
- Unsupported card: try `HSA_OVERRIDE_GFX_VERSION` (for example `10.3.0`); on Windows RX 6000 try Vulkan (default) or set `GGML_VK_VISIBLE_DEVICES`.
- Diagnostics: `AMD_LOG_LEVEL=3`, `OLLAMA_DEBUG=1`, `sudo dmesg | grep -i amdgpu`, `sudo dmesg | grep -i kfd`.
- Gibberish across several AMD GPUs on Linux: see AMD's multi-GPU known issues (https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installrad/native_linux/mgpu.html#mgpu-known-issues-and-limitations).

## Vulkan

- Enabled by default where the backend exists. `OLLAMA_VULKAN=0` or `GGML_VK_VISIBLE_DEVICES=-1` turns it off; pick a discrete GPU on iGPU/dGPU systems with `GGML_VK_VISIBLE_DEVICES=<index>`.
- Linux needs Vulkan drivers (Mesa or vendor) and either root or `sudo setcap cap_perfmon+ep /usr/local/bin/ollama` for free-VRAM reporting; without it scheduling uses approximate sizes. AMD users may need the `ollama` user in the `render` group.

## Crashes and odd backends

`OLLAMA_LLM_LIBRARY=cpu_avx2` (or `cpu_avx`, `cpu`) forces a CPU library to bypass GPU crashes (experimental). Check CPU flags with `grep -m1 flags /proc/cpuinfo`. Rosetta on macOS works with the `cpu` library.

## Linux specifics

- `/tmp` mounted `noexec`: set `OLLAMA_TMPDIR` to a path the `ollama` user can write and execute from (for example `/usr/share/ollama/`).
- Old libraries after a manual upgrade: `sudo rm -rf /usr/lib/ollama` before extracting.
- Install script wants `zstd` for `.tar.zst` packages; install it and retry.
- WSL2 without systemd: the installer warns; run `ollama serve` manually. Slow downloads on Windows 10 WSL2: disable Large Send Offload V2 (IPv4/IPv6) on the `vEthernet (WSL)` adapter.

## Windows specifics

- Garbled escape sequences (`←[?25h`) or "The parameter is incorrect": update Windows 10 to 22H1 or newer (needs 22H2+ for Ollama).
- Terminal shows squares instead of spinners: change the terminal font.
- Models location is a user variable `OLLAMA_MODELS`; restart the tray app after changing it.

## macOS specifics

- App plus Homebrew service or a manual `ollama serve` collide on 11434.
- Environment variables set with `launchctl setenv` vanish on reboot.
- Docker Desktop has no GPU passthrough: run natively to use Metal.

## Gathering a report

`ollama -v`, OS and driver versions, `nvidia-smi` or `rocm-smi`, the first 200 log lines after startup with `OLLAMA_DEBUG=1`, `ollama ps`. Remove prompts and keys before sharing. Upstream help: https://github.com/ollama/ollama/issues and https://discord.gg/ollama.
