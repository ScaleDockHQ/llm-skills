# Updating DCGM Exporter

> Verified against dcgm-exporter 4.8.4 (GitHub releases, install docs), 2026-10-11

Latest release at verification is 4.8.4 with DCGM 4.6.1 (2026-09-18).

```bash
gh api repos/NVIDIA/dcgm-exporter/releases/latest --jq '.tag_name,.published_at'
docker inspect dcgm-exporter --format '{{.Config.Image}} {{.Image}}'        # record for rollback
dcgm-exporter --version                                                      # package installs
```

- **Container:** replace with the same configuration and a new pinned tag (`<dcgm>-<exporter>-<variant>`), then `scripts/check.sh`.
- **Package:** update DCGM and the exporter together; the exporter package and `nvidia-dcgm` must be paired. Re-check any systemd drop-in `ExecStart`.
- **Helm:** `helm repo update && helm upgrade dcgm-exporter gpu-helm-charts/dcgm-exporter -n gpu-monitoring --reuse-values`.
- **GPU Operator:** upgrade through the Operator.
- Read the release notes for removed fields: 4.8.x rejects custom CSVs that use the retired PCIe throughput fields.
- Restart or reload resets exporter-owned counters (`DCGM_EXP_*_TOTAL`); use `rate()`/`increase()`.
- A collector CSV change reloads live; flags and YAML need a restart.
- Rollback: previous image tag or package version with the same DCGM pairing.

## Official links

- Release notes: https://docs.nvidia.com/datacenter/dcgm/latest/release-notes/dcgm-exporter.html
- Releases: https://github.com/NVIDIA/dcgm-exporter/releases
