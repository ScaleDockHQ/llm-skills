---
name: vast-ai
description: Rent cheap GPUs on Vast.ai with the vastai CLI to serve LLMs (vLLM instances and Serverless endpoints), connect them to a gateway and destroy them. Use for Vast.ai setup, vastai search offers, create instance, onstart-cmd, mapped ports, Serverless workergroups, openai.vast.ai proxy, API key permissions, interruptible bids, stopped-instance storage billing. Not for other clouds (use cloud-llms), gateway design (llm-gateway) or vLLM flags (vllm).
license: MIT
compatibility: Needs bash, curl, jq and the vastai CLI (pip install vastai, Python 3.8+ assumed), network access to vast.ai and a Vast.ai account with prepaid credits. Creating instances, endpoints or volumes bills the account, so each needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Vast.ai

Rent a GPU on the Vast.ai marketplace (an instance or a Serverless endpoint), serve an LLM, reach it from OpenAI-compatible clients and your gateway, keep the spend and data exposure small, and destroy everything when done.

**Scope:** the `vastai` CLI, GPU offer search, instances, ports and SSH, volumes, Serverless endpoints and workergroups, the OpenAI proxy, API key permissions, billing behavior and teardown.

**Out of scope:** choosing between providers (`cloud-llms`, `choosing-llm-hosting`), gateway routing and keys (`llm-gateway`, `litellm`), vLLM engine tuning (`vllm`), GPU sizing (`choosing-hardware`), training recipes (`fine-tuning-llms`), image or video models (`self-hosted-genmedia`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print variable names, never values, and never `cat` key files.

```bash
command -v vastai && vastai --version
env | cut -d= -f1 | grep -E '^(VAST|HF|OPENAI|LITELLM|VLLM)_' || echo "no matching env vars"
ls -l ~/.config/vastai/vast_api_key 2>&1                       # permissions only; want -rw-------
vastai show instances                                          # running or stopped rentals, with cost
vastai show endpoints
vastai show volumes
vastai show ssh-keys
```

Learn what already exists and what it costs per hour before proposing anything. If `vastai` is missing or there is no key, go to workflow 1.

## Decision flow

1. **Quick experiment, dev box, or one always-on model?** Rent an **instance** (`references/instances.md`).
2. **Spiky traffic, can tolerate minutes of cold start, want an OpenAI-compatible URL?** Use **Serverless** with the vLLM template (`references/serverless.md`).
3. **Restartable batch job?** An **interruptible** instance, with checkpoints (`references/instances.md`).
4. **Sensitive data or strict uptime?** Use Secure Cloud or verified datacenter offers, or another provider (`cloud-llms`); read the security notes in `references/limits-and-costs.md`.
5. **Clients and gateway:** `references/litellm-and-clients.md`.
6. **Something broke:** `references/troubleshooting.md`.
7. **Done or pausing:** `references/teardown.md`. Destroy; do not just stop.

## Rules

- **Ask before anything billable.** Instances, endpoints, volumes and bids cost money. State offer id, hourly price, disk size, `max_workers` and a stop time, then wait for approval.
- **Secrets stay secret.** The Vast API key comes from a `0600` file or `VAST_API_KEY`, never printed, committed or pasted. Prefer account env vars over `-e` flags for `HF_TOKEN`. Use a scoped key for each job or client.
- **Treat hosts as untrusted.** Hosts can technically read files on their machines. No credentials, private datasets or unencrypted sensitive data on instances; prefer verified or Secure Cloud offers.
- **Pin versions.** Use `vllm/vllm-openai:<version>` and pinned model revisions, never `latest`.
- **Budget controls before traffic.** Cap `max_workers`, set an inactivity timeout, keep a balance buffer, and set `max_tokens` in clients.
- **Always destroy.** A stopped instance still bills for storage and can lose its GPU. Only destroying instances and endpoints stops all billing. Finish every session with workflow 8.
- **Protect ports.** Mapped ports are plain HTTP; use `--api-key` and an SSH tunnel, Tailscale or a tunnel service.
- **Do not hardcode prices.** Read them from `vastai search offers`.

## Workflows

### 1. Account and auth

- [ ] Account has credits (human step); note that Autobilling is card-only and there are no refunds.
- [ ] `pip install "vastai==1.8.3"` in a venv; `vastai --version`.
- [ ] User creates an API key, ideally scoped (`references/setup-and-auth.md`), and saves it to `~/.config/vastai/vast_api_key` with `0600`.
- [ ] Register an SSH public key (`vastai create ssh-key`) before renting; `vastai show user` works.
- [ ] Save `HF_TOKEN` and `VLLM_API_KEY` as account env vars through the console for gated models and vLLM auth.

### 2. Rent an instance and serve vLLM

- [ ] `vastai search offers '... verified=true direct_port_count>=1 rentable=true'`; compare `dph_total`, `inet_down`, `disk_space`, reliability and bandwidth price.
- [ ] After approval, `vastai create instance <OFFER_ID> --image vllm/vllm-openai:<ver> --disk N --ssh --direct --env '-p 8000:8000' --onstart-cmd '...'`; record `new_contract`.
- [ ] `vastai show instance <ID>` until `running`; find the external port (`VAST_TCP_PORT_8000`, `ports` in `--raw`).
- [ ] Test `GET /v1/models` with the vLLM key, preferably over an SSH tunnel.

### 3. Create a Serverless endpoint

- [ ] After approval, create the endpoint and workergroup with the vLLM (Serverless) template, low `max_workers`, and an inactivity timeout (`references/serverless.md`).
- [ ] Set `HF_TOKEN` for gated models; wait 3 to 5 minutes for the first worker.
- [ ] Test via `https://openai.vast.ai/<ENDPOINT_NAME>` with a scoped key.

### 4. Connect to LiteLLM and clients

- [ ] Add a `model_list` entry from `references/litellm-and-clients.md` (`hosted_vllm/<model>` for instances, `openai/<name>` for the proxy), with long `timeout` and a fallback.
- [ ] Keep the connection private (tunnel, Tailscale) for instances.

### 5. Scale

- [ ] Instances: rent more, or switch to Serverless. Serverless: tune min and max workers, target utilization and cold multiplier.
- [ ] Re-check bandwidth prices for large data movement.

### 6. Monitor cost

- [ ] `vastai show instances` (hourly rows), `vastai show user` (balance), the console billing page.
- [ ] `llm-observability` for request-level cost and latency; `llm-evals` before swapping models or hosts.

### 7. Update

- [ ] Instances are disposable: create a new one with the new pinned image, test, destroy the old one.
- [ ] Serverless: update the template or workergroup, check worker logs, then retire old workers.

### 8. Tear down

- [ ] Follow `references/teardown.md`: delete workergroups and endpoints, destroy instances, delete volumes, revoke keys.
- [ ] Verify `vastai show instances`, `show endpoints` and `show volumes` are empty or as intended.

### 9. Troubleshoot

- [ ] Instance status and logs first, then `references/troubleshooting.md`.

## Reference index

| File                                | Load when                                                                |
| ----------------------------------- | ------------------------------------------------------------------------ |
| `references/setup-and-auth.md`      | Account, CLI install, API key and scoped permissions, SSH keys, env vars |
| `references/instances.md`           | Searching offers, creating instances, ports, volumes, stop vs destroy    |
| `references/serverless.md`          | Endpoints, workergroups, worker states and billing, OpenAI proxy, SDK    |
| `references/litellm-and-clients.md` | LiteLLM entries, OpenAI SDK and curl, private access                     |
| `references/limits-and-costs.md`    | Billing rules, instance types, limits, security of marketplace hosts     |
| `references/teardown.md`            | Destroying every billable resource and verifying                         |
| `references/troubleshooting.md`     | Symptom to cause to fix                                                  |

## Companion skills

- `cloud-llms`: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms` (compare providers, hybrid setups)
- `llm-gateway`: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway` (one endpoint, keys, budgets)
- `choosing-llm-hosting`: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `llm-clients`: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`
- `llm-observability`: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`
- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `fine-tuning-llms`: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`
- `model-quantization`: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`
- `vllm`: `npx skills add ScaleDockHQ/llms-skills --skill vllm`
