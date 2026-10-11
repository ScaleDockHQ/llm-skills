# Scaling, cold starts, GPUs, Volumes and budgets

> Verified against Modal docs (Scaling out, Servers, Cold start performance, GPU acceleration, Volumes, Budgets and Billing guides; CLI reference for `modal billing`), modal 1.6.1, 2026-10-11

## Autoscaler parameters

Passed to `@app.server`, `@app.function` or `@app.cls` (scale guide, Servers guide):

| Parameter            | Meaning                                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `min_containers`     | Containers kept warm even when idle. Costs money while idle, removes cold starts.                    |
| `max_containers`     | Upper bound. Also a spend cap.                                                                       |
| `buffer_containers`  | Extra idle containers kept while active.                                                             |
| `scaledown_window`   | Seconds a container may idle before scale-down.                                                      |
| `scaleup_window`     | Servers only: how responsive scale-up is.                                                            |
| `target_concurrency` | Servers: soft per-container request target that drives autoscaling. Must be set to autoscale.        |
| `max_concurrency`    | Servers: hard per-container limit. Excess requests get a 503. Must be at least `target_concurrency`. |
| `startup_timeout`    | Servers: seconds to become ready on the port before the container is failed.                         |
| `exit_grace_period`  | Servers: seconds in-flight requests may finish on scale-down (max 3600).                             |

Rules from the Servers guide:

- If `target_concurrency` is unset but `min_containers` provisions several, requests are spread across them.
- For a single container, leave `target_concurrency` unset rather than using `max_containers=1`, which blocks the replacement container during a rolling redeploy.
- A Server that scales to zero returns **503** until the first container is ready. Keep `min_containers=1` for interactive traffic or have the gateway retry.

Dynamic changes without redeploying (reset by the next deploy):

```python
import modal
server = modal.Server.from_name("my-vllm", "Server")
server.update_autoscaler(min_containers=2)
```

Confirm the exact `from_name` call in the SDK reference for `modal.Server` before use. A scheduled Function with `modal.Cron` can raise `min_containers` in working hours and lower it at night.

## Cold starts

The Cold start guide covers the options. In order of effort:

1. Cache weights and compile artifacts in Volumes (`vllm-server.md`).
2. `FAST_BOOT` (`--enforce-eager`) trades throughput for boot time.
3. GPU memory snapshots to restore a warm engine (see the guide for current status and constraints).
4. `min_containers` to avoid cold starts entirely.

## GPU choice

GPU type is a string such as `"H200:1"` on the decorator. A list gives fallbacks in order. Check the GPU guide for the current list and `modal billing rates` for what each costs. Match VRAM to weights plus KV cache using `choosing-hardware`. Account limits on concurrent GPUs depend on the workspace plan.

## Volumes

Volumes are a shared disk for model weights and caches (Volumes guide).

- Mount with `volumes={"/path": modal.Volume.from_name("name", create_if_missing=True)}`.
- Writes made inside a container become visible to others after `volume.commit()`; readers pick up new data after `volume.reload()`. Model download by vLLM into the HF cache usually needs a commit if other containers must see it.
- Prefer one Volume for the Hugging Face cache and one for vLLM compile caches, as in Modal's example.
- Volumes v2 has different limits (including file counts) from v1. Read the Volumes guide's limits section for the current numbers rather than relying on a copy.
- Volumes are billed for storage. Delete them in `teardown.md`.

```bash
modal volume list
modal volume ls huggingface-cache /
modal volume delete huggingface-cache --yes   # irreversible
```

## Hard limit

A single Function can run at most 4,000 concurrent containers. Concurrent container and GPU limits depend on the plan. See `scaling-and-volumes.md` for spend controls.

## GPU strings

Values for `gpu=`: `T4`, `L4`, `A10`, `L40S`, `A100` (`A100-40GB`, `A100-80GB`), `RTX-PRO-6000`, `H100` (`H100!` blocks the automatic upgrade to `H200`), `H200`, `B200` (`B200+`), `B300`. Count with a colon (`"H100:8"`); a list gives fallbacks (`["H100", "A100-40GB:2"]`). Modal suggests starting with `L40S`. Billing is per second with no minimum increment, and `compute_region` choices can carry a price multiplier.

## Set a cap before traffic

| Control                        | Scope                                    | Notes                                                                                                                            |
| ------------------------------ | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Workspace budget (usage limit) | Whole workspace, monthly, before credits | Set on the dashboard's Usage & Billing page by an Owner or Manager. The maximum you can set depends on prior successful charges. |
| Workspace spend limit          | Net charges after credits                | When reached, Modal stops workloads that would cause out-of-pocket charges. Defaults to usage limit minus credits.               |
| Environment budget             | Compute in one Environment, monthly      | Team and Enterprise plans only. Excludes storage, reservations and egress, so it is not an invoice total.                        |

Budgets and spend limits are dashboard settings; the CLI cannot set them. State what exists, and if none exists, ask the user to set one before deploying. Use separate Environments (`dev`, `prod`) so a runaway experiment hits its own cap.

## Read costs from the CLI

```bash
modal billing rates --json                         # current prices; never copy them into docs
modal billing summary --for "this month"
modal billing report --for "this month" --tag-names team,project --show-resources
modal billing report --for yesterday -r h --csv
```

`modal billing report` and `summary` front the Workspace billing API; plan availability for the API is not stated on the CLI page (unverified: check <https://modal.com/docs/guide/billing>). Reports cover full intervals only, with start inclusive and end exclusive.

## Tag workloads

Tag Apps so reports can attribute spend (billing guide). Pass the tag names to `--tag-names`. Check the billing guide for how to set tags on an App.

## Per-App controls that act as spend caps

- `max_containers` and `max_concurrency` on a Server bound parallel GPUs.
- `min_containers` is the main idle cost. Set to `0` when nothing needs to stay warm.
- `scaledown_window` sets how long a finished container keeps billing.
- Lower `startup_timeout` limits the cost of a stuck start.

## Platform limits to know

- Concurrent containers and GPUs depend on the workspace plan; the hard single-Function ceiling is 4,000 concurrent containers.
- Servers do not queue: excess traffic gets 503 at zero containers or at `max_concurrency`.
- Rate limits for the Modal web endpoints and the exact request rate limit are not copied here (unverified: check <https://modal.com/docs/guide/webhooks>).
- Endpoint stats and `modal server stats` are best-effort and not for autoscaler management.

## Cost monitoring routine

- [ ] Before deploying: `modal billing rates`, note GPU price, estimate idle cost for `min_containers`.
- [ ] During: `modal billing report --for today -r h`.
- [ ] After: tear down (`teardown.md`), then check `modal billing report --for today` again the next day.
