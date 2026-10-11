# Driver branches, Fabric Manager and versions

> Verified against NVIDIA Data Center GPU Driver 580.178.04 release notes and NVIDIA product pages, 2026-10-11

## Branches (NVIDIA data center lifecycle table)

| Branch | Designation       | End of life |
| ------ | ----------------- | ----------- |
| R535   | Long Term Support | June 2026   |
| R580   | Long Term Support | June 2028   |
| R595   | Production        | March 2027  |
| R610   | New Feature       | August 2026 |

R580 supports CUDA 13 without a forward-compatibility package; R535 is CUDA 12 only. Check the live table before choosing: <https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html>. A `releases.json` is published for scripting.

## R580 release 580.178.04 (Linux)

- Fabric Manager ships with the same version (check `nv-fabricmanager -v`). Install the matching packages for the branch.
- Compatible only with DCGM 4.3.x or newer.
- Hopper GPUs with subrevision 3 need VBIOS 96.00.68.00.xx or newer, or the driver fails to initialize. Update VBIOS first, only with the vendor's procedure.
- Upgrading from the closed to the open kernel module may make `nvidia-smi` fail; NVIDIA's documented workaround for SUSE is removing the old driver package and installing the open one. Reboot and verify.
- Supported platforms listed include HGX B300, HGX B200, GB300 NVL72, HGX GB200 NVL, HGX H200, HGX H100 (4- and 8-GPU), GH200.

## NVSwitch systems

HGX 8-GPU nodes need `nvidia-fabricmanager` running or CUDA reports initialisation errors. Check:

```bash
systemctl status nvidia-fabricmanager --no-pager
nvidia-smi -q | grep -A3 -i fabric
nvidia-smi topo -m
```

Blackwell requires the open kernel modules. Enable persistence mode (`nvidia-persistenced`) so GPUs stay initialised.

## Sources

- <https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html>
- <https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-178-04/index.html>
