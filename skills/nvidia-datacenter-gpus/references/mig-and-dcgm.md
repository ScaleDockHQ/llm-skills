# MIG and DCGM

> Verified against NVIDIA Data Center GPU Driver 580.178.04 release notes and NVIDIA product pages, 2026-10-11

## MIG

H100 SXM supports up to 7 instances at 10 GB, H200 SXM up to 7 at 18 GB (NVIDIA datasheets). Enabling MIG needs the GPU idle and usually a reset; it changes device naming in containers. Ask first.

```bash
nvidia-smi -i 0 -mig 1                 # enable (needs approval, GPU idle)
nvidia-smi mig -lgip                   # available profiles
nvidia-smi mig -cgi <profile ids> -C   # create instances
nvidia-smi -L                          # list MIG devices and UUIDs
```

Use MIG for isolated small models or multi-tenant dev, not for one large model.

## DCGM

The R580 driver requires DCGM 4.3.x or newer. Read-only checks:

```bash
dcgmi discovery -l
dcgmi health -c                         # check health watches
dcgmi dmon -c 5                        # default field set, five samples
```

Run `dcgmi diag --help` first; diagnostic levels above the quickest stress the GPU, so run them only on idle nodes. Export to Prometheus with the DCGM exporter (`llm-observability`).

## Sources

- <https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-178-04/index.html>
- <https://www.nvidia.com/en-us/data-center/h200/>
- <https://resources.nvidia.com/en-us-gpu/h100-datasheet-24306>
