# Updating DGX Station

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

- DGX Station receives repository-based over-the-air updates; the base firmware is NVIDIA-supported with OS updates independent of it, and the exact method is OEM-defined (Development Guide).
- The DGX OS 7 notes: upgrades are cumulative; the system stays on its driver branch; GB300 can go to 7.6.0 but not yet to 8.x. Read <https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html> before any upgrade.
- Procedure: stable power, services drained, snapshot of `dpkg -l | grep -E 'nvidia|cuda|doca'`, update, reboot, re-run Discover, check `nvidia-smi`, container GPU access and `ibdev2netdev`. Update both stations in one window.
- Engines update independently: pin image tags, keep one rollback image.
- Recovery images come from your OEM; back up first.

## Sources

- <https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html>
- <https://docs.nvidia.com/dgx/dgx-station-development-guide/porting/software-requirements.html>
