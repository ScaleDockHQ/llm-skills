# Multi-GPU, power, cooling and MIG

> Verified against NVIDIA RTX PRO Blackwell datasheets, CUDA Toolkit 13.4 Update 1 and driver 580 README, 2026-10-11

## Topology

The datasheets list PCIe 5.0 x16 as the system interface and no NVLink connector. Multi-GPU traffic therefore crosses PCIe, so tensor parallelism pays more than on NVLink systems. Check what you actually have:

```bash
nvidia-smi topo -m                 # PHB/PXB/SYS paths between cards
nvidia-smi --query-gpu=index,pcie.link.gen.current,pcie.link.width.current --format=csv
```

Cards behind a x8 slot or a chipset lane lose bandwidth. Prefer pipeline or expert parallelism, or run one model per card, when the link is slow. Validate with `nccl-tests` before trusting tensor parallel. If peer access is off, engines may need `NCCL_P2P_DISABLE=1`; measure instead of assuming.

## Power and cooling

- Workstation Edition 600 W via one 16-pin connector; Max-Q 300 W; 5000 300 W; 4500 200 W; 4000 145 W (datasheets).
- Budget the PSU for all cards plus CPU with headroom for transients; confirm the 16-pin cable seating and that the circuit supports the load.
- The Workstation Edition uses a double flow-through cooler; Max-Q and others use active blower-style coolers designed for dense stacking. Do not stack 600 W cards without airflow planning.
- Cap power if needed (ask first): `sudo nvidia-smi -i 0 -pl <watts>`; check the allowed range with `nvidia-smi -q -d POWER`.
- Watch temperature and clocks: `nvidia-smi dmon -s pucvmet`.

## MIG

The RTX PRO 6000 supports up to 4x 24 GB, 2x 48 GB or 1x 96 GB instances. Enabling MIG needs a GPU reset and changes how containers address devices; ask first, and list profiles with `nvidia-smi mig -lgip`. Not every RTX PRO card supports MIG; check the datasheet.

## Sources

- <https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-6000-max-q/>
- <https://www.nvidia.com/content/dam/en-zz/Solutions/data-center/rtx-pro-6000-blackwell-workstation-edition/workstation-blackwell-rtx-pro-6000-workstation-edition-nvidia-us-3519208-web.pdf>
