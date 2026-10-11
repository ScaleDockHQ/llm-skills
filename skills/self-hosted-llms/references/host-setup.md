# Host setup

> Verified against NVIDIA Container Toolkit 1.20.1 install guide, Docker Engine Ubuntu install and Linux post-install docs, NVIDIA DGX Spark user guide and "Connect two Sparks" playbook (updated 2026-07-21), 2026-10-11

Prepare every node the same way: OS, Docker, NVIDIA Container Toolkit, service user, SSH between
nodes, disk layout, stack directories and systemd units. Do the steps on node-a, then repeat on
node-b. Hardware sizing is in `hardware-dgx-spark.md` / `hardware-generic.md`.

## 1. OS and NVIDIA driver

- **DGX Spark (DGX OS)**: DGX OS is Ubuntu-based and ships the NVIDIA stack, including Docker and the
  NVIDIA Container Runtime. Do not reinstall the driver or toolkit; apply NVIDIA's DGX OS updates
  and go to the GPU test in step 2.
- **Generic Ubuntu (x86_64 or arm64)**: install the NVIDIA driver with the distribution package
  manager first (NVIDIA's recommended route; see the Driver Installation Quickstart Guide). Reboot,
  then confirm `nvidia-smi` lists every GPU.

## 2. Docker and NVIDIA Container Toolkit

Docker Engine supports Ubuntu on x86_64/amd64 and arm64. Install it from Docker's apt repository
(follow https://docs.docker.com/engine/install/ubuntu/ for the repository setup), then:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world
```

Install the toolkit (same commands on arm64 and x86; apt picks the architecture):

```bash
sudo apt-get update && sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg2
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.20.1-1
sudo apt-get install -y \
  nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
sudo nvidia-ctk runtime configure --runtime=docker   # edits /etc/docker/daemon.json
sudo systemctl restart docker
```

Test GPU access from a container on every node (both platforms):

```bash
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

Pitfall: NVIDIA documents a known issue where, with systemd cgroup drivers, running containers lose
access to their GPUs after `systemctl daemon-reload`. After any `daemon-reload` (step 7), check that
the engines still serve; restart the affected model through llama-swap if not. See the toolkit
troubleshooting docs.

## 3. Service user

Run the stack as one dedicated user (example: `llm`) with the **same name and UID on every node**,
so file ownership, paths and SSH work identically.

```bash
id llm 2>/dev/null || sudo useradd -m -u <uid> -s /bin/bash llm   # pick one free UID for all nodes
sudo usermod -aG docker llm
ssh node-b 'id llm'                                              # must print the same uid/gid
```

Membership in `docker` grants root-level privileges (Docker's own warning); see `security.md`.
Log out and back in (or `newgrp docker`) before using it.

## 4. Passwordless SSH between nodes (two-node setups)

Follow NVIDIA's "Connect two Sparks" playbook; the same steps work for other ConnectX hosts.

1. Same username on both nodes (`whoami`).
2. Cable the same physical QSFP port on each node; `ibdev2netdev` shows which interfaces are `Up`.
   Each physical port appears as two logical interfaces.
3. Assign static addresses with netplan, e.g. `/etc/netplan/40-cx7.yaml`:

   ```yaml
   network:
     version: 2
     ethernets:
       <cx7-iface>:
         addresses: [10.0.0.1/24] # 10.0.0.2/24 on node-b
         dhcp4: no
   ```

   ```bash
   sudo chmod 600 /etc/netplan/40-cx7.yaml && sudo netplan apply
   ```

   `ip addr add` also works but does not survive a reboot. With two cables, address all four
   interfaces. Rollback: `sudo rm /etc/netplan/40-cx7.yaml && sudo netplan apply`.

4. Exchange keys both ways: the playbook's `discover-sparks` script, or
   `ssh-copy-id -i ~/.ssh/id_ed25519.pub llm@10.0.0.2` (and the reverse from node-b).
5. Verify without a prompt from each side: `ssh 10.0.0.2 hostname`, `ssh 10.0.0.1 hostname`.

Add `node-b` as a host alias in `~/.ssh/config` so commands in this skill (`ssh node-b ...`) work.

## 5. Disk layout

- Put model weights on the fastest local NVMe with the most free space. Check with
  `lsblk -o NAME,SIZE,MODEL,MOUNTPOINT` and `df -h`.
- The Hugging Face cache defaults to `~/.cache/huggingface/hub`. To move it, set `HF_HOME` (the hub
  cache becomes `$HF_HOME/hub`) in the service user's environment **and** in the engine containers
  (mount the same host path; see `models-and-weights.md`).
- Use the same path on every node; wrappers and llama-swap configs assume it.
- Keep enough free space for one extra model plus one rollback image (see `cleanup.md`).

## 6. Stack directories

```bash
sudo install -d -m 755 -o root -g root /opt/llm-stack /opt/llm-stack/models.d
sudo install -d -m 750 -o root -g llm  /etc/llm-stack
sudo install -d -m 755 -o llm  -g llm  /var/lib/llm-stack /var/lib/llm-stack/catalog
sudo install -m 755 assets/start-model.sh assets/common.sh /opt/llm-stack/
sudo install -m 640 -o root -g llm assets/llama-swap.yaml /etc/llm-stack/llama-swap.yaml
sudo install -m 640 -o root -g llm assets/litellm-config.yaml /etc/llm-stack/litellm-config.yaml
sudo install -m 600 -o root -g root /dev/null /etc/llm-stack/litellm.env  # then edit with sudoedit
```

Scripts are root-owned and not writable by the service user; configs are readable by its group;
`litellm.env` (holds `LITELLM_MASTER_KEY`) is root-only, mode 600, and read by systemd. Copy the same
tree to node-b (`rsync -a` then re-check owners and modes there).

## 7. systemd units

Install the units from `assets/systemd/`:

```bash
sudo install -m 644 assets/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llama-swap.service litellm.service llm-catalog.service
sudo systemctl enable --now cloudflared.service      # only with exposure-cloudflare.md
sudo apt install earlyoom && sudo systemctl enable --now earlyoom   # see memory-safety.md
systemctl --no-pager status llama-swap litellm llm-catalog
```

Install only the units you use. After editing a unit: `daemon-reload`, then restart that unit, then
re-check engine GPU access (step 2 pitfall). Use `systemctl cat <unit>` with care: it shows inline
`Environment=` values (see `security.md`).

## 8. Root-owned files from containers

Containers run as root by default, so weights, caches and build output they write on bind mounts
end up owned by root and break later downloads or cleanup as the service user. Prevent it:

- Run engines with `--user "$(id -u llm):$(id -g llm)"` when the image supports a non-root user, and
  mount the HF cache at a path that user can write.
- Otherwise chown afterwards, after checking what you are about to change:
  `sudo find <path> -user root | head` then `sudo chown -R llm:llm <path>`.

Detection and cleanup across both nodes are in `cleanup.md`.

## sysctl

No sysctl changes are required by this stack, and none are recommended here without a documented
source. Leave kernel defaults unless an engine's official docs ask for a specific setting.

## Official links

- Docker Engine on Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Docker post-install: https://docs.docker.com/engine/install/linux-postinstall/
- NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
- DGX Spark playbooks: https://github.com/NVIDIA/dgx-spark-playbooks
