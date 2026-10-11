# LM Studio with LM Link (remote models, local API)

> Verified against LM Studio 0.4.26 and lmstudio.ai/docs/lmlink (overview, add-device, faq, developer/core/lmlink, cli/link), 2026-10-11

LM Link is documented as new; behaviour may change.

LM Link connects your own devices into a private, end-to-end encrypted network (built on Tailscale). A model loaded on a strong machine then appears on the laptop and is served through the laptop's normal `localhost:1234` API. It needs an LM Studio account.

## Add a device

- **With a GUI:** install LM Studio, click **LM Link** in the sidebar, follow the steps.
- **Headless (llmster):**

```bash
curl -fsSL https://lmstudio.ai/install.sh | bash   # ask the user first: remote script
lms login                                          # follow the printed instructions
lms link enable
lms link status [--json]                           # name, state, peers and their loaded models
```

Disable: app Settings > LM Link > Enable LM Link off, or `lms link disable`. Other commands: `lms link set-device-name`, `lms link set-preferred-device` (see `lms link --help`).

## Use it

```bash
lms server start --port 1234          # on the laptop
lms ps --host <host>                  # optional: inspect a remote instance
```

Point Claude Code, Codex, curl or the SDKs at `localhost:1234` as usual (`combos/claude-code.md`, `combos/codex.md`). The model key can be one that exists only on the remote device. When the same model exists on several devices, set a **preferred device** (in-app LM Link page, or `lms link set-preferred-device`); the setting is per machine.

## Security notes (from the FAQ)

- Devices talk over Tailscale's end-to-end encrypted connections; none is exposed to the public internet. The LM Studio Hub is used only for discovery.
- Linked devices can only use LM Studio model and API access, not your OS, files or other services.
- LM Link creates its own dedicated Tailscale network and takes control of its ACL. It does **not** work with an existing Tailscale network and does not interfere with an existing Tailscale VPN on the machine.
- Account login, enabling LM Link and installing llmster on another machine all change that machine: get explicit approval first and tell the user how to disable it.

## Pitfalls

- A device shows "disconnected" when it crashed without reporting, or LM Studio/llmster is not running there.
- If you would rather run your own network with Tailscale, expose the server with a bind address plus authentication instead; that is plain Tailscale, not LM Link (`tailscale` skill: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`).

## Official links

- https://lmstudio.ai/docs/lmlink
- https://lmstudio.ai/docs/lmlink/basics/add-device
- https://lmstudio.ai/docs/lmlink/basics/faq
- https://lmstudio.ai/docs/developer/core/lmlink
- https://lmstudio.ai/docs/cli/link/link-enable
