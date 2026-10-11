# RTX PRO Blackwell lineup

> Verified against NVIDIA RTX PRO Blackwell datasheets, CUDA Toolkit 13.4 Update 1 and driver 580 README, 2026-10-11

Figures are NVIDIA datasheet or product-page values; verify the exact SKU with your vendor.

| Card                                             | Memory                   | Bandwidth  | Max power      | Form factor                         |
| ------------------------------------------------ | ------------------------ | ---------- | -------------- | ----------------------------------- |
| RTX PRO 6000 Blackwell Workstation Edition       | 96 GB GDDR7 ECC, 512-bit | 1,792 GB/s | 600 W (16-pin) | dual slot, 5.4 in x 12 in           |
| RTX PRO 6000 Blackwell Max-Q Workstation Edition | 96 GB GDDR7 ECC          | 1,792 GB/s | 300 W          | dual slot, 4.4 in x 10.5 in, active |
| RTX PRO 5000 Blackwell                           | 48 GB or 72 GB GDDR7 ECC | 1,344 GB/s | 300 W          | dual slot, 4.4 in x 10.5 in         |
| RTX PRO 4500 Blackwell                           | 32 GB GDDR7 ECC, 256-bit | 896 GB/s   | 200 W (16-pin) | dual slot, full height              |
| RTX PRO 4000 Blackwell                           | 24 GB GDDR7 ECC          | 672 GB/s   | 145 W          | single slot, 4.4 in x 9.5 in        |

All use 5th-generation Tensor Cores with FP4, PCIe 5.0 x16 (6000 and 4500 datasheets), and DisplayPort 2.1b. The 6000 has 24,064 CUDA cores. The Max-Q is designed for up to four GPUs in one system (NVIDIA). MIG on the 6000: up to 4x 24 GB, 2x 48 GB or 1x 96 GB.

## Choosing

- Decode speed tracks memory bandwidth; capacity decides which model fits. A 96 GB card holds a quantised model in the 70B to 120B class with context; check with `choosing-hardware`.
- Same 96 GB and bandwidth in the Max-Q at half the power: one Max-Q per 300 W budget scales to four cards; fewer, 600 W cards need a bigger PSU and airflow.
- For the full memory and bandwidth lineup across vendors, see `choosing-hardware`.
- Larger-than-workstation memory with coherent HBM is DGX Station (`nvidia-dgx-station`).
- Prices and stock vary by vendor and are not listed here.

## Sources

- <https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-6000-max-q/>
- <https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-5000/>
- <https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-4000/>
