# Vast.ai instances: search, rent, serve vLLM, connect

> Verified against vastai CLI 1.8.3, docs.vast.ai guides/instances/connect/networking, guides/instances/storage/volumes, cli/reference (create-instance, destroy-instances, create-volume), docs.vast.ai/llms.txt, 2026-10-11

## 1. Search offers

```bash
vastai search offers 'gpu_name=RTX_4090 num_gpus=1 verified=true direct_port_count>=1 rentable=true' -o 'dlperf_usd-' --raw | jq '.[0:5] | .[] | {id, gpu_name, dph_total, geolocation, reliability2, inet_down, disk_space}'
vastai search offers --help          # all filter fields and sort keys
```

- `verified=true` limits to verified hosts; prefer Secure Cloud (datacenter) offers for sensitive data (the console has a Secure Cloud filter).
- `direct_port_count>=1` (or higher) is needed for direct open ports such as vLLM on 8000.
- Add `disk_space>=<GB>` large enough for the image and model weights, and `inet_down` high enough to download weights quickly.
- `dph_total` is the hourly total for GPU, storage and the other components. **Bandwidth is billed separately and is not in that figure.** Check bandwidth prices in the offer details before moving large data.
- Offers come in three types: on-demand, reserved (up to 50% discount, committed term) and interruptible (bid price, can be paused). The type cannot be changed after rental, except on-demand to reserved.

## 2. Create an instance (approval first)

Creating an instance starts billing for GPU, storage and bandwidth. State offer id, hourly price, disk size, max runtime and teardown plan, then get a yes.

```bash
vastai create instance <OFFER_ID> \
  --image vllm/vllm-openai:<pinned-version> \
  --disk 80 --ssh --direct \
  --env '-p 8000:8000' \
  --onstart-cmd 'vllm serve <model> --host 0.0.0.0 --port 8000 --api-key "$VLLM_API_KEY" > /var/log/vllm.log 2>&1 &'
```

It prints `{"success": true, "new_contract": <INSTANCE_ID>}`; the new contract id is the instance id. Record it for teardown.

Notes:

- `--env` holds Docker options: ports (`-p 8000:8000`), env vars (`-e KEY=value`) and volumes (`-v V.<name>:/mnt`). Keep secrets out of `-e` values (shell history): set `HF_TOKEN` and `VLLM_API_KEY` as account env vars (`setup-and-auth.md`), which the instance receives, and reference them in the start command. Confirm with `env | cut -d= -f1` inside the instance that both names exist.
- `--ssh --direct` selects SSH launch mode with direct connections. `--jupyter` is an alternative that opens port 8080.
- `--onstart-cmd` is limited to 16 KB. Long scripts belong in a template or in a file fetched at start.
- `--bid_price <x>` creates an interruptible instance at that bid; `--template_hash <hash>` starts from a template; `vastai launch instance` searches and creates in one step (use `--help`).
- Exact flags for entrypoint and args vary by image mode; check `vastai create instance --help`. Pin a version tag, never `latest`. The `vllm-openai` image uses `vllm serve` flags; the `vllm` skill covers them.
- Docker-in-Docker is not supported on Vast instances.

Wait for `running`:

```bash
vastai show instance <INSTANCE_ID> --raw | jq '{actual_status, cur_state, status_msg, public_ipaddr, ports}'
```

`actual_status` values include `loading`, `running`, `exited`, `unknown`, `offline`, `scheduling` and `connecting`. GPU billing starts at `running`.

## 3. Networking and ports

Instances rarely have their own IP. Each internal port you open (22, 8080, and `-p` ports) maps to a **random external port** on a shared public IP. Limit: 64 open ports per instance.

- Find the mapping in the console's IP Port Info, in `vastai show instance --raw` (look at `public_ipaddr` and `ports`), or inside the instance via `$VAST_TCP_PORT_8000` (one variable per internal TCP port; `VAST_UDP_PORT_<n>` for UDP).
- For a same-number mapping use ports above 70000 (`-p 70000:70000`) and read `$VAST_TCP_PORT_70000`.
- `OPEN_BUTTON_PORT` and `JUPYTER_PORT` control the console buttons only.
- Direct ports are plain HTTP. Keep the vLLM `--api-key` on, and for anything beyond a quick test use an SSH tunnel (`ssh -N -L 8000:localhost:8000 root@<host> -p <ssh-port>`; get host and port from `vastai ssh-url <ID>`), Tailscale or Cloudflare Tunnel (see `tailscale` and `cloudflare-tunnel` skills).
- Test the mapping first with `python -m http.server 8081`.

```bash
vastai ssh-url <INSTANCE_ID>                               # ssh://root@host:port
curl -s "http://<public_ipaddr>:<external-port>/v1/models" -H "Authorization: Bearer $VLLM_API_KEY" | jq '.data[].id'
```

## 4. Storage

- **Container storage** is fixed at creation (`--disk`, default minimum 10 GB), is deleted on destroy, and keeps billing while the instance is stopped.
- **Local volumes** are separate and tied to one physical machine: `vastai search volumes`, `vastai create volume <offer_id> -s <GB> -n <name>`, `vastai show volumes`, mount with `--env '-v <volume_name>:/mnt'`, `vastai delete volume <id>`. Volumes cannot be resized or moved, work only for Docker (not VM) instances, and can only be deleted after the instance using them is destroyed.
- Move data with `vastai copy <src> <dst>` (`C.<instance_id>:/path`, `V.<volume_id>:/path`, cloud storage with `s3.<connection_id>:`). Copying between a volume and your local machine directly is not supported.
- Downloading weights on every rental is slow and costs bandwidth; use a volume only if you will return to the same machine, otherwise pick offers with fast `inet_down`.

## 5. Lifecycle

```bash
vastai show instances                         # all instances with status and cost
vastai stop instance <ID>                     # stops GPU billing; storage keeps billing; the GPU may be taken by someone else
vastai start instance <ID>                    # may be unavailable if the GPU was rented out
vastai destroy instance <ID>                  # irreversible; stops all billing, deletes the container disk
vastai destroy instances <ID> <ID>            # several at once
```

A stopped instance's GPU can be rented by another user, so `start` may fail or queue. Treat stopping as a short pause only. Destroy when you are done. Expired (reserved) instances may be deleted 48 hours after expiry.

## 6. Interruptible instances

Bid instances can be paused when outbid. Use them for restartable jobs, checkpoint to a volume or off-host storage, and do not serve production traffic from them.
