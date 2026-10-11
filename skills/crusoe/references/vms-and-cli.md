# Crusoe: VMs and disks with the CLI

> Verified against Crusoe Cloud docs (CLI reference for compute vms, storage disks, locations; VM lifecycle and billing), 2026-10-11

## Discover

```bash
crusoe locations list
crusoe compute vms types
crusoe compute images list
crusoe compute vms list
crusoe storage disks list
```

## Create

```bash
crusoe compute vms create --name "$NAME" --type "$TYPE" --location "$LOCATION" \
  --image "$IMAGE" --keyfile "$HOME/.ssh/id_ed25519.pub"
```

Take `TYPE` from `crusoe compute vms types` and `LOCATION` from `crusoe locations list`; GPU availability differs per location. After creation the VM must be started:

```bash
crusoe compute vms start "$NAME"      # unverified argument form: check `crusoe compute vms start --help`
crusoe compute vms get "$NAME"
```

SSH with the public IP from `get`, then serve with vLLM as in `self-hosted-llms`. Expose ports narrowly (firewall rules or an SSH tunnel), never an unauthenticated model server to the internet.

## Stop and billing

- A stopped on-demand VM is not billed and does not count toward quota.
- Persistent and shared disks bill even when detached.
- Ephemeral GPU local disks are wiped on stop: keep weights and results on a persistent disk or object storage.

## Delete

```bash
crusoe compute vms delete "$NAME"
crusoe storage disks delete "$DISK_NAME"
```

Confirm names with the list commands first. Then see `teardown.md`.
