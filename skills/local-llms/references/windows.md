# Windows desktops and laptops

> Verified against Ollama v0.40.3 Windows docs, llama.cpp b11555 release assets, LM Studio 0.4.26 system requirements, 2026-10-11

## What it is and when to choose it

Windows 10 22H2+ and Windows 11 run Ollama, LM Studio, and llama.cpp natively with GPU acceleration. You do not need WSL2 for local inference. Use WSL2 only when the rest of your toolchain (Python stacks, Linux-only servers) already lives there.

## Discover (PowerShell, read-only)

```powershell
[System.Environment]::Is64BitOperatingSystem; $env:PROCESSOR_ARCHITECTURE   # AMD64 or ARM64
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB            # RAM in GB
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion    # GPUs and driver versions
nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv   # NVIDIA VRAM
Get-NetTCPConnection -State Listen -LocalPort 11434,1234,9931,8080 -ErrorAction SilentlyContinue
Get-Command ollama, lms, llama-server -ErrorAction SilentlyContinue
```

`Win32_VideoController.AdapterRAM` is a 32-bit field and caps at 4 GB, so don't use it for VRAM. For NVIDIA use `nvidia-smi`. For AMD, read the VRAM in Task Manager → Performance → GPU (Dedicated GPU memory), or in the AMD Software app.

## Install

**NVIDIA (CUDA)**

- Update the GeForce/Studio driver first. Ollama needs NVIDIA 551.61 or newer on Windows.
- Ollama: `irm https://ollama.com/install.ps1 | iex`, or `OllamaSetup.exe`. Both install per-user without admin rights.
- LM Studio: the installer from lmstudio.ai. x64 needs AVX2; ARM64 (Snapdragon) is supported too.
- llama.cpp: `winget install llama.cpp`, or download `llama-<build>-bin-win-cuda-<ver>-x64.zip` **plus** the matching `cudart-llama-bin-win-cuda-<ver>-x64.zip` and extract both into the same folder.

**AMD**

- Ollama uses ROCm v7 / HIP7-capable drivers on supported Radeon RX 7000-series and PRO W7000 cards, and uses Vulkan otherwise. Vulkan is on by default and is the recommended fallback for RDNA2 (RX 6000) cards.
- llama.cpp: `llama-<build>-bin-win-vulkan-x64.zip` works on any recent AMD/Intel/NVIDIA driver. A `win-rocm` zip also exists.
- LM Studio: pick the Vulkan or ROCm runtime with `lms runtime ls` / `lms runtime select`, or in the app's runtime settings.

**Intel Arc / iGPU:** llama.cpp `win-vulkan` or `win-sycl` builds.

**CPU only / Snapdragon:** llama.cpp `win-cpu-x64` / `win-cpu-arm64` builds; LM Studio ARM64.

## Minimal working config

```powershell
# llama.cpp, CUDA build extracted to C:\llama
C:\llama\llama-server.exe -hf ggml-org/<model>-GGUF:Q4_K_M -c 16384 --host 127.0.0.1 --port 9931

# Ollama (service already running in the tray)
ollama pull <model>
ollama run <model> "hello"
```

## How it plugs in

Same ports as on other OSes (Ollama 11434, LM Studio 1234, llama-server 9931). Environment variables for Ollama: quit Ollama from the tray, set the user variable under _Edit environment variables for your account_ (or run `setx OLLAMA_HOST 127.0.0.1:11434`), then start Ollama again.

## WSL2 vs native

|                                       | Native                | WSL2                                                                              |
| ------------------------------------- | --------------------- | --------------------------------------------------------------------------------- |
| GPU                                   | Full CUDA/ROCm/Vulkan | CUDA via the Windows driver (do **not** install a Linux NVIDIA driver inside WSL) |
| Model files on `C:`                   | Fast                  | Slow through `/mnt/c`; keep models inside the WSL filesystem                      |
| Reaching the server from Windows apps | `localhost`           | `localhost` forwarding usually works; mirrored networking mode makes it reliable  |
| Memory                                | All RAM               | WSL2 VM limit (set in `%UserProfile%\.wslconfig`)                                 |

Pick one side. Don't run Ollama on both Windows and WSL2: they would both try to use port 11434 (see "one runtime per port").

## Firewall prompts

Windows Defender Firewall prompts the first time an app listens on a non-loopback address. **Choose "Private networks" only, or cancel** if you didn't mean to share. To allow a single port on the local subnet deliberately (admin PowerShell):

```powershell
New-NetFirewallRule -DisplayName "llama-server LAN" -Direction Inbound -Protocol TCP -LocalPort 9931 -RemoteAddress LocalSubnet -Profile Private -Action Allow
Remove-NetFirewallRule -DisplayName "llama-server LAN"     # undo
```

See `sharing-on-lan.md` before doing this.

## Operating

- Ollama logs: `%LOCALAPPDATA%\Ollama\server.log`. Binaries: `%LOCALAPPDATA%\Programs\Ollama`. Models: `%USERPROFILE%\.ollama\models` (change with `OLLAMA_MODELS`).
- Ollama updates itself (tray → "Restart to update"). Update llama.cpp with `winget upgrade llama.cpp` or a new zip. LM Studio updates in-app.
- Disable autostart: Task Manager → Startup apps → Ollama → Disable.

## Tuning knobs worth knowing

- Laptops with hybrid graphics: make sure the runtime uses the discrete GPU (Settings → System → Display → Graphics → High performance). With Vulkan on mixed iGPU/dGPU systems, `GGML_VK_VISIBLE_DEVICES=<index>` selects the discrete GPU.
- Use the "Best performance" power mode and plug in AC power for benchmarks.
- `CUDA_VISIBLE_DEVICES` selects NVIDIA GPUs for Ollama and llama.cpp.

## Known pitfalls

- A CUDA zip extracted without the `cudart` zip either fails with a missing `cudart64_*.dll` or silently runs on the CPU.
- Windows sometimes moves VRAM overflow into shared system memory (the NVIDIA "sysmem fallback"), which makes things very slow instead of failing. Watch "Shared GPU memory" in Task Manager.
- Antivirus can quarantine freshly downloaded `llama-*.exe` files. Restore and allow them, or install via winget.
- Very old terminal fonts render Ollama's progress bars as boxes. This is cosmetic.

## Official links

- Ollama Windows: https://docs.ollama.com/windows
- Ollama GPU support: https://docs.ollama.com/gpu
- llama.cpp releases: https://github.com/ggml-org/llama.cpp/releases
- LM Studio system requirements: https://lmstudio.ai/docs/app/system-requirements
- WSL CUDA guide: https://docs.nvidia.com/cuda/wsl-user-guide/
