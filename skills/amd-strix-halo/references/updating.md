# Updating

> Verified against ROCm 10.1.0 release notes (2026-10-05), toolboxes README, Lemonade v2026.41.1 release notes, 2026-10-11

## What to update and in what order

1. **Kernel and firmware** (distro packages; reboot). ROCm 10.1.0 lists Ubuntu 26.04.1 with kernel 7.0 GA and Ubuntu 24.04.5 with kernel 7.0 HWE for this chip. Keep the previous kernel entry until the new one passes the checks.
2. **linux-firmware and Mesa** (distro packages). Check `vulkaninfo --summary` afterwards.
3. **ROCm** (only if installed on the host): change the apt source for the new release and `sudo apt install amdrocm10.1-gfx1151` style packages. ROCm 10.1.0 removed `rocm-smi` from the standard build; use `amd-smi`.
4. **Engine containers and apps:** the toolbox project recommends AI Toolbox Cockpit for updates; for a manual Toolbx setup `./refresh-toolboxes.sh all` in the toolbox repository refreshes to the latest nightly or stable build. Lemonade: update through the package you installed (MSI, PPA, deb or rpm).

## Before and after

```bash
uname -r; dpkg -l | grep -E 'linux-firmware|mesa-vulkan' | head   # or rpm -q on Fedora
for f in mem_info_gtt_total; do cat /sys/class/drm/card*/device/$f; done
vulkaninfo --summary | grep -E 'deviceName|driverName'
```

After an update confirm: the GTT total is unchanged (a kernel or modprobe change can reset it), the engine still names the Radeon device, and a model near your usual size loads without a stall.

## Image and release drift

- Toolbox `-mtp` tags are deprecated; do not pin them.
- Lemonade v2026.41.1 moved ROCm backends to ROCm 10 and downloads a new runtime (about 2.6 GB) the first time a ROCm model loads after upgrading.
- Pin one image tag per environment and record its digest (`docker inspect --format '{{index .RepoDigests 0}}' <image>`); rolling back is a redeploy of the old tag.
- Re-run your evals (`llm-evals`) after a backend change.
