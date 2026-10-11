# Sharing a local model on your network

> Verified against Ollama v0.40.3, llama.cpp b11555, LM Studio 0.4.26, mlx-lm 0.32.0, Tailscale Serve docs, 2026-10-11

Every runtime here binds to `127.0.0.1` by default, and that's the right default. Share a model only when the user actually wants another device (a second laptop, a phone, a home-lab box) to use it. **Never expose an inference server to the network without authentication.** An open endpoint can be used by anyone on the network, can read files through a prompt-injected agent, and can pull models until your disk fills up.

## Options, safest first

1. **Don't share. Use an SSH tunnel** from the other machine: `ssh -N -L 9931:127.0.0.1:9931 user@192.168.1.10`. The server stays on localhost, and SSH provides the auth.
2. **Tailscale (tailnet only).** The server stays on localhost and Tailscale proxies it with HTTPS to devices in your tailnet:
   ```bash
   tailscale serve --bg 9931          # https://<machine>.<tailnet>.ts.net -> 127.0.0.1:9931
   tailscale serve status
   tailscale serve reset              # stop serving
   ```
   Add the runtime's API key anyway: anyone in your tailnet, including shared users and devices, can reach it. **Do not use `tailscale funnel`**, which publishes to the public internet.
3. **LAN bind with an API key and a firewall rule limited to your subnet.** Use this only with a runtime that checks keys itself.

## Per-runtime

| Runtime       | Built-in auth                                                         | LAN bind                                                       |
| ------------- | --------------------------------------------------------------------- | -------------------------------------------------------------- |
| llama.cpp     | `--api-key-file PATH`                                                 | `--host 0.0.0.0` (or a specific LAN IP such as `192.168.1.10`) |
| LM Studio     | Developer → Server Settings → **Require Authentication**, plus tokens | `lms server start --bind 0.0.0.0`, or "Serve on Local Network" |
| Ollama        | **None**                                                              | `OLLAMA_HOST=0.0.0.0:11434`                                    |
| mlx_lm.server | **None**                                                              | `--host 0.0.0.0`                                               |

For Ollama and mlx_lm.server, don't bind to the LAN. Keep them on localhost and either use options 1–2 or put an authenticating reverse proxy in front. A proxy with key checks, a gateway (see the **llm-gateway** skill), or `llama-server` itself are all options. When a proxy forwards to a loopback-bound Ollama, set the upstream Host header to `localhost:11434`, or Ollama returns 403. _(Whether `tailscale serve` rewrites the Host header wasn't verified. If Ollama returns 403 through Serve, put a small proxy that sets the Host header in between.)_

## Creating and storing a key

```bash
umask 077
mkdir -p ~/.config/llama-server
openssl rand -hex 32 > ~/.config/llama-server/keys     # one key per line
llama-server -m ~/models/<model>.gguf --host 0.0.0.0 --port 9931 --api-key-file ~/.config/llama-server/keys
```

- Never print the key, paste it into chat, commit it, or put it on a command line. Point clients at the file or an environment variable (`LLM_API_KEY`, `OPENAI_API_KEY`).
- Test the key without echoing it: `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $(cat ~/.config/llama-server/keys)" http://192.168.1.10:9931/v1/models`. This should print `200`, and the same request without the header should print `401`. `/health` is public, so it proves nothing about auth.

## Firewall

Allow only your subnet, only the one port, and remove the rule when you're done.

- **macOS:** the Application Firewall asks once per binary. Check its state with `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`. It can't restrict by subnet, so rely on the API key and on trusted networks.
- **Windows (admin PowerShell):** `New-NetFirewallRule -DisplayName "llama-server LAN" -Direction Inbound -Protocol TCP -LocalPort 9931 -RemoteAddress LocalSubnet -Profile Private -Action Allow`. Make sure the network profile is _Private_, not Public.
- **Linux (ufw):** `sudo ufw allow from 192.168.1.0/24 to any port 9931 proto tcp`; remove it with `sudo ufw delete allow from 192.168.1.0/24 to any port 9931 proto tcp`. With firewalld, use a rich rule scoped to the source subnet.

All of these change system state. Ask the user first, and tell them how to undo it.

## Checklist

- [ ] The user explicitly wants other devices to reach this machine.
- [ ] Prefer an SSH tunnel or Tailscale Serve over a LAN bind.
- [ ] The runtime enforces an API key (llama-server, LM Studio), or a proxy does.
- [ ] The key was generated into a `0600` file and never printed.
- [ ] Bind to a specific LAN IP rather than `0.0.0.0` when possible.
- [ ] Firewall scoped to the subnet and port; rule removal documented.
- [ ] Verified: request without a key → 401, with the key → 200, from a second device.
- [ ] Not on public/guest Wi-Fi. Laptops move between networks, so turn sharing off before leaving.
- [ ] Never expose the server through port forwarding on the router or through `tailscale funnel`.

## Official links

- llama-server auth flags: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- LM Studio serve on network: https://lmstudio.ai/docs/developer/core/server/serve-on-network
- LM Studio authentication: https://lmstudio.ai/docs/developer/core/authentication
- Ollama network exposure FAQ: https://docs.ollama.com/faq
- Tailscale Serve: https://tailscale.com/kb/1312/serve
- Tailscale Serve CLI: https://tailscale.com/kb/1242/tailscale-serve
