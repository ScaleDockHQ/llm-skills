# BMC, telemetry and power

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

- **BMC:** dedicated 1 GbE RJ45 for out-of-band management; web UI and Redfish; out-of-band telemetry; hardware root of trust and enterprise secure boot (NVIDIA product page, Development Guide). Put it on a management VLAN, never on the internet, and set a strong password from a `0600` file or a password manager.
- **Firmware updates:** secure update workflow through the BMC and UEFI capsule updates via Redfish `UpdateService`, with OEM-provisioned keys. The update method is OEM-defined; follow your vendor's procedure.
- **Recovery:** re-image with USB boot media or BMC virtual media; images come from OEM repositories.
- **Monitoring:** `nvidia-smi`, DCGM (preinstalled; `dcgmi discovery -l`, `dcgmi dmon -e 203,252`), BMC telemetry. Metrics pipelines: `llm-observability`.
- **Power:** 1,600 W total system power and a 20 A circuit (NVIDIA specs). Check the circuit and any UPS rating before first boot, and the power policy in the BMC.
- **Headless:** SSH or the web server works; display needs the add-in GPU.

```bash
curl -sk -u "$BMC_USER:$(cat ~/.config/bmc-pass)" https://<bmc-ip>/redfish/v1/Systems   # read-only, adjust per OEM
```

## Sources

- <https://docs.nvidia.com/dgx/dgx-station-development-guide/porting/software-requirements.html>
- <https://www.nvidia.com/en-us/products/workstations/dgx-station/>
