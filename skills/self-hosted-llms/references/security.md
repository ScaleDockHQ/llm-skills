# Security

> Verified against LiteLLM v1.105.0 proxy docs (virtual keys, master key rotation, config settings), Docker Engine post-install docs, curl manual, sparkDash v2.32.0 README, 2026-10-11

Rules for secrets, file modes, sudo, exposure and git. Applies to both nodes and to every command
this skill runs.

## Secrets never touch output

Keys live in files, are read into a variable inside a subshell, and never appear in terminal
output, logs, shell history, process lists, commits or `tee`.

```bash
# Read a key without printing it; the subshell keeps it out of your shell's environment
( KEY=$(< ~/.config/llm-stack/client.key)
  printf 'header = "Authorization: Bearer %s"\n' "$KEY" \
    | curl -sS -K - https://llm.example.com/v1/models | jq -r '.data[].id' )
```

- `curl -K -` reads options (here the header) from stdin, so the key is not in curl's argv and does
  not show in `ps`. `printf` is a shell builtin, so it has no argv either. Never pass
  `-H "Authorization: Bearer $KEY"`: the expanded key is visible in `ps` to every local user.
- Never `echo $KEY`, `set -x` around key handling, `cat` a key file, or paste a key on a command
  line (it lands in history).
- Check only that a key exists: `test -s /etc/llm-stack/litellm.env && echo present`.
- Show configs filtered:
  `grep -v -i 'key\|token\|secret\|password' /etc/llm-stack/litellm-config.yaml`.

### Commands that leak environment

- `systemctl cat <unit>` prints the unit file, including inline `Environment=` lines;
  `systemctl show <unit>` prints the `Environment` property. Use `EnvironmentFile=` for secrets and
  query specific properties: `systemctl show -p ActiveState -p SubState -p ExecMainStartTimestamp`.
- `docker inspect <container>` includes `.Config.Env` with every `-e` value. Always use
  `--format` with specific fields:
  `docker inspect -f '{{.State.Status}} {{.Config.Image}} {{.State.StartedAt}}' <id>`.
- `docker compose config`, `env`, `printenv` and `/proc/<pid>/environ` also show secrets.
- `journalctl` may contain keys if a process logged its config or argv; do not paste raw logs.

## File modes

| File | Owner | Mode |
| --- | --- | --- |
| `/etc/llm-stack/litellm.env` (`LITELLM_MASTER_KEY`, database URL) | root:root | 600 |
| Client key files under `~/.config/...` | user | 600 (directory 700) |
| sparkDash `.env` with `SPARKDASH_TOKEN` | service user | 600 |
| cloudflared credentials JSON | root | 600 |
| `/etc/llm-stack/*.yaml` without secrets | root:llm | 640 |

Create secret files empty with the mode set first, then edit:
`sudo install -m 600 -o root -g root /dev/null <file>` and `sudoedit <file>`.

## LiteLLM keys

- **Master key** (`general_settings.master_key`, falling back to `LITELLM_MASTER_KEY`): the proxy
  admin credential and Admin UI password. It must start with `sk-`. LiteLLM refuses to start when it
  is unset, empty or a known unsafe value. Do not set
  `dangerously_permit_weak_or_unset_master_key` outside local development. Generate it with a
  random source, e.g. `printf 'sk-%s\n' "$(openssl rand -hex 32)"` written straight into the env
  file via `sudoedit`, never echoed to the terminal.
- **Virtual keys**: one per client or person, created with `POST /key/generate` (requires
  `DATABASE_URL`). Give each key only the models it needs, and budgets/rate limits if useful. Clients
  never get the master key.
- **Rotation**: regenerate a virtual key with `POST /key/{key}/regenerate` or revoke and reissue it.
  The master key rotation flow depends on whether `LITELLM_SALT_KEY` is set and on stored
  credentials; follow LiteLLM's master key rotation doc for your case. Getting it wrong can leave
  stored credentials unreadable. Rotate immediately after any suspected exposure.

## sudo scope

- Grant only specific commands with NOPASSWD, in a drop-in edited through `visudo` (it syntax-checks
  before saving):

  ```bash
  sudo visudo -f /etc/sudoers.d/<name>
  # llm ALL=(root) NOPASSWD: /usr/local/bin/spark-shutdown
  ```

- Never `NOPASSWD: ALL` for the service user. Prefer root-owned helper scripts with fixed arguments
  over broad commands like `systemctl` or `docker`.
- Authenticate interactively with `sudo -v`, then run the commands.

### Lesson: a sudo password ended up in a system file

A password was written to disk by `echo <password> | sudo tee <file>` (intended for `sudo -S`), and
`sudo -S` with the password on the command line also left it in shell history. Never pipe a password
through `tee`, `echo` or `sudo -S`. Use `sudo -v` at the prompt. If it happened:

1. Remove the file (`sudo rm <file>`) and any copies or backups.
2. Change the password immediately (`passwd`) on every node where it is used.
3. Check and clean shell history (`history`, `~/.bash_history`, `~/.zsh_history`) and any logs or
   transcripts where the command was recorded.

## Least exposure

- **Loopback only.** Every listener in the port map binds `127.0.0.1`. Only cloudflared (outbound
  tunnel) and tailscale (tailnet) carry traffic in from outside. Check with
  `ss -tlnp | grep -v '127.0.0.1\|\[::1\]'` on every node.
- **No engine ports on `0.0.0.0`.** Pass `--host 127.0.0.1` explicitly in every `models.d/` script,
  and check each engine's default: llama.cpp `llama-server` defaults to `127.0.0.1`, but the
  ExLlamaV3 fork's `serve_openai.py` defaults to `0.0.0.0`, and Ollama listens where `OLLAMA_HOST`
  says. Containers on `--network host` inherit that bind; with port mapping, publish as
  `-p 127.0.0.1:<port>:<port>`.
- **Dashboards behind access.** sparkDash, the LiteLLM Admin UI and llama-swap's UI never go public
  without Cloudflare Access or the tailnet. Set `SPARKDASH_TOKEN` (`monitoring-sparkdash.md`).
- **Keys even on the tailnet** (`exposure-tailscale.md`).

## The docker group is root-equivalent

Docker documents that the `docker` group grants root-level privileges: any member can mount `/`
into a container. Add only the service user, never shared or guest accounts, and treat access to
that account like root access. Privileged containers (sparkDash) have the same effect.

## Git hygiene

- Keep real configs out of the repo; commit only templates with placeholders.
- `.gitignore` in any repo or directory that holds stack files:

  ```gitignore
  *.env
  .env
  .env.*
  !.env.example
  *.key
  ```

- Before committing: `git diff --cached | grep -i -E 'sk-|bearer|token|password'` should find
  nothing. If a secret was committed, rotate it first; rewriting history does not un-leak it.

## Official links

- LiteLLM virtual keys: https://docs.litellm.ai/docs/proxy/virtual_keys
- LiteLLM master key rotation: https://docs.litellm.ai/docs/proxy/master_key_rotations
- Docker post-install (docker group): https://docs.docker.com/engine/install/linux-postinstall/
- curl config files (`-K`): https://curl.se/docs/manpage.html#-K
