# Unified memory: GART, GTT, TTM and sizing

> Verified against Linux kernel amdgpu docs (docs.kernel.org/gpu/amdgpu/driver-misc.html), strix-halo-toolboxes.com host guide, Strix Halo Wiki AI overview (2025-08), 2026-10-11

## Three pools

- **GART / UMA carveout:** a fixed block of RAM the BIOS reserves for the GPU. The wiki's advice for AI use is to set it to the minimum (for example 512 MB) and let the GPU use GTT instead. Some BIOSes expose the choice at runtime through `uma/carveout_options` and `uma/carveout` under the device's sysfs directory (a write applies on next boot); if the files are absent the BIOS does not support it.
- **GTT:** system RAM the GPU maps dynamically. On Linux its upper limit is managed by the TTM subsystem. `amdgpu.gttsize` is a deprecated parameter some software still reads; the wiki recommends setting it to match.
- **System RAM:** whatever the OS, page cache, containers and your other jobs need. GTT is carved out of the same RAM.

## Check the current pool (read-only)

```bash
for f in mem_info_vram_total mem_info_gtt_total mem_info_gtt_used; do
  echo "$f $(cat /sys/class/drm/card*/device/$f 2>/dev/null | tr '\n' ' ')"   # bytes
done
dmesg | grep -i amdgpu | grep -i -E 'gtt|vram' | tail
free -h
```

`mem_info_gtt_total` is the number that matters for a model's weights plus KV cache.

## Raise the limit (Linux, approval needed)

The toolbox maintainer's current host settings on a 128 GB Framework Desktop (`strix-halo-toolboxes.com`), appended to `GRUB_CMDLINE_LINUX` without removing existing options:

```text
amd_iommu=off amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

Then rebuild GRUB (`sudo grub2-mkconfig -o /boot/grub2/grub.cfg` on Fedora, `sudo update-grub` on Ubuntu or Debian) and reboot.

| Parameter                  | Meaning                                                                                                                                                                                                                                                                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `amdgpu.gttsize=126976`    | Maximum GTT in MiB, about 124 GB. Deprecated but still read by some software.                                                                                                                                                                                                                                                       |
| `ttm.pages_limit=32505856` | Maximum pinned pages (4 KiB each), about 124 GB. This is what the kernel actually enforces.                                                                                                                                                                                                                                         |
| `amd_iommu=off`            | Disables the IOMMU. The maintainer reports a 5 to 12 percent gain over passthrough in one user's benchmark (`strix-halo-toolboxes` issue 66). **Trade-off:** the NPU stops working and the system loses DMA protection against rogue or compromised external devices. Leave the IOMMU on if you need the NPU, VMs or DMA isolation. |

The wiki's alternative is a modprobe file, with the same units (pages of 4 KiB):

```text
# /etc/modprobe.d/amdgpu_llm_optimized.conf  (uncomment deliberately)
options ttm pages_limit=31457280       # 120 GiB
options ttm page_pool_size=15728640    # optional pre-allocated pool, never usable by the system
```

Regenerate the initramfs if the GPU driver loads from it (`update-initramfs -u -k all` on Debian and Ubuntu, `dracut -f` on Fedora). `page_pool_size` pre-allocates memory the OS cannot use; set it to 0 or lower than `pages_limit` unless you dedicate the machine to AI. A conflicting `amdgpu.gttsize` boot parameter can override a modprobe value and prints a deprecation warning; keep one source of truth.

Keep a margin: the wiki's 120 GiB example leaves 8 GiB for a 128 GB machine; the toolbox maintainer runs about 124 GB with a headless desktop. If the host swaps or the OOM killer fires, lower the limit.

## Ryzen AI Halo (systemd-boot) with `amd-ttm`

On the Debian-based Ryzen AI Halo distribution, which uses systemd-boot, the toolbox guide uses the `amd-ttm` tool in place of the two memory parameters:

```bash
sudo apt install pipx && pipx ensurepath
pipx install amd-debug-tools
sudo amd-ttm --set 124          # prints the pages limit it set; reboot when prompted
```

IOMMU on that distribution is changed through `/etc/kernel/cmdline` and `kernel-install add`; do not edit `/boot/loader/entries/` directly because those files are regenerated on each kernel update.

## Sizing

```text
weights (quantized checkpoint size)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x parallel_sequences
+ compute buffers and runtime overhead (several GB; measure)
+ OS headroom (desktop, containers, page cache)
<= GTT pool, and the pool must leave headroom in total RAM
```

Read `layers`, `num_key_value_heads` and `head_dim` from the model `config.json`. A model close to the pool size gets killed once KV cache and buffers are added: the community llama.cpp notes record a 105 GB Q8_0 exceeding a 120 GiB pool while Q6_K and Q4_K_M ran. The toolbox project ships `gguf-vram-estimator.py` (usage in its `docs/vram-estimator.md`) to estimate a GGUF with a context length.

Tools that show NVIDIA-style VRAM figures can mislead on this chip; use `free -h` and the sysfs GTT counters above, and read the engine's own memory line at load time.
