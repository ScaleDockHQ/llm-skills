# Updating DGX OS, firmware and containers

> Verified against DGX Spark User Guide (OS and Component Update Guide, System Recovery) and release notes (DGX OS 7.5.0), 2026-10-11

Applies to the Founders Edition; partner systems follow their vendor's procedure.

## OS, driver and firmware

NVIDIA strongly recommends the DGX Dashboard for all updates (security patches, driver, firmware, status). Before any update: stable power, applications closed, a recovery plan, a maintenance window. Manual path (works, less tested):

```bash
sudo apt update
sudo apt dist-upgrade
sudo fwupdmgr refresh
sudo fwupdmgr upgrade
sudo reboot
```

Over-the-air updates are not installed during first setup; apply them afterwards. After an update re-run the baseline: `nvidia-smi`, `docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi`, `ibdev2netdev`. In a cluster update both nodes in the same window and compare versions (a multi-node performance regression after DGX OS 7.4.0 was fixed in February 2026).

Read the release notes first: <https://docs.nvidia.com/dgx/dgx-spark/release-notes.html>. Enterprise options (USB or local-repository updates, air-gapped, cloud-init custom ISOs, PXE) are in the Enterprise Manageability guide.

## Recovery

Needs a 16 GB or larger USB drive, keyboard and display. Download the recovery archive (tar.gz) from developer.nvidia.com, create the USB key with `CreateUSBKey.sh` (Linux), `CreateUSBKeyMacOS.sh` or `CreateUSBKey.cmd`, then boot it through UEFI Boot Override. Recovery restores factory state: back up first.

## Containers and engines

Engines update independently of DGX OS. Pin tags, pull on both nodes, compare image IDs, keep one rollback image (`combos/dual-node-cluster.md`). Per-engine update procedures are in the engine skills.

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html>
- <https://docs.nvidia.com/dgx/dgx-spark/system-recovery.html>
