# Install driver and ROCm

> Verified against ROCm 10.1.0 install guide (rocm.docs.amd.com/en/latest/install/rocm.html), 2026-10-11

Everything here needs approval: it writes apt sources, builds a kernel module through DKMS and needs a reboot.

## Pick a method

| Method                                   | Use when                                                                      |
| ---------------------------------------- | ----------------------------------------------------------------------------- |
| Package manager (`apt`, `dnf`, `zypper`) | Server hosts; system-wide; updates via the package manager. Default.          |
| Runfile installer                        | Offline or scripted installs; `deps=install amdgpu` also installs the driver. |
| pip wheels (`rocm[...]`)                 | A per-project virtual environment with no system ROCm.                        |
| `amdgpu-install`                         | Documented for Radeon and Ryzen only, not for Instinct.                       |

For LLM serving a container with its own ROCm user space is usually simpler: install only the kernel driver on the host and follow `containers-and-engines.md`.

## 1. Prerequisites

```bash
# Ubuntu, listed by AMD for ROCm 10.1.0
sudo apt update && sudo apt install sudo wget gpg perl
sudo apt install libatomic1 libquadmath0
```

Enable the BIOS settings your server vendor lists for Instinct. AMD's page warns to enable Above 4G Decoding before installing.

## 2. Kernel driver (`amdgpu`)

Instinct hosts need the `amdgpu` driver from AMD. Follow the distro page "native installation" in the AMD Instinct documentation for the driver version the compatibility matrix lists, or use the runfile:

```bash
bash rocm-installer-10.1.0-5.run deps=install amdgpu   # then reboot
```

Reboot after the driver install. Verify with `dkms status | grep amdgpu` and `modinfo amdgpu | grep ^version`.

## 3. ROCm packages (apt, Ubuntu 26.04 example)

```bash
sudo mkdir --parents --mode=0755 /etc/apt/keyrings
wget https://stable.repo.amd.com/rocm/gpg/packages.gpg -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/amdrocm.gpg > /dev/null
sudo tee /etc/apt/sources.list.d/amdrocm-stable.sources << 'APTEOF'
X-Repo-Id: amdrocm-stable
Types: deb
URIs: https://stable.repo.amd.com/rocm/core/packages/ubuntu2604/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/amdrocm.gpg
Enabled: yes
APTEOF
sudo apt update
sudo apt install amdrocm10.1                 # core packages
sudo apt install amdrocm10.1-gfx942          # per-target meta package: -gfx950, -gfx90a, -gfx908
```

Other distros use a different repository block (the `URIs:` path differs; RHEL and SLES use `.repo` files). Copy the block for your distro from the install page instead of editing this one. Meta packages: `amdrocm10.1-<gfxNNN>`, `amdrocm-core-dev10.1-<gfxNNN>`, `amdrocm-core-sdk10.1-<gfxNNN>`, `amdrocm-developer-tools10.1` (profilers), `amdrocm-opencl10.1`.

## 4. pip wheels (no system ROCm)

```bash
python3.12 -m venv .venv && source .venv/bin/activate
python -m pip install --index-url https://stable.repo.amd.com/rocm/whl-next/ "rocm[libraries,device-gfx942]==10.1.0"
```

Use `device-gfx950`, `device-gfx90a` and so on for other targets, or `device-all`. The Python version AMD shows depends on the distro (3.11 to 3.14).

## 5. GPU access for users

```bash
sudo usermod -a -G render,video "$LOGNAME"     # log out and in afterwards
```

AMD's alternative is a udev rule with `MODE="0666"` on `kfd` and `renderD*`; it opens the GPUs to every local user, so prefer groups on shared hosts.

## 6. Verify

```bash
amd-smi version && amd-smi list
rocminfo | grep -E 'Name:\s+gfx' | sort -u    # expect gfx942, gfx950 and so on
sudo dmesg -T | grep -i amdgpu | grep -i error
```

If `amd-smi` is missing, install the core package. `rocm-smi` is no longer part of the standard ROCm 10.1 build.
