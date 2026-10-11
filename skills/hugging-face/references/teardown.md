# Hugging Face teardown

> Verified against huggingface_hub Inference Endpoints guide and CLI guide (hf endpoints, hf jobs, hf spaces, hf cache, hf sandbox), Hub security tokens page, 2026-10-11

Inference Providers calls cost nothing while idle. Endpoints, Spaces hardware, Jobs and sandboxes bill while running. Ask before each deletion.

## Checklist

- [ ] **List**: `hf endpoints ls --namespace '*'`, `hf jobs ls`, `hf spaces ls --search <you>` (or the Spaces dashboard for upgraded hardware).
- [ ] **Endpoints**: `hf endpoints pause <name>` to keep the config (billing stops, URL kept, replicas at zero), or `hf endpoints delete <name> --yes` to remove permanently (configuration, logs and usage metrics are lost). Scale-to-zero alone does not free quota.
- [ ] **Jobs and sandboxes**: `hf jobs cancel <id>`, `hf sandbox kill <id>`.
- [ ] **Spaces**: `hf spaces pause <owner/space>`; delete the repo only with approval (`hf repos delete <owner/space> --repo-type space`).
- [ ] **Tokens**: delete or refresh tokens you created for the task (Settings, Access Tokens, Manage). Remove `~/.config/hf.token`, unset `HF_TOKEN`, remove it from CI secrets and gateway configs. `hf auth logout` does nothing while `HF_TOKEN` is set.
- [ ] **Provider keys** you added in Hub settings: remove them if the work is finished.
- [ ] **Cache and local weights**:

```bash
hf cache ls
hf cache rm model/<org>/<name> --dry-run && hf cache rm model/<org>/<name> --yes
hf cache prune
rm -rf ./weights                     # --local-dir copies
```

- [ ] **Repos you created for testing**: delete only with approval (`hf repos delete <repo>`); public repos may already be cached by others.

## Verify

```bash
hf endpoints ls --namespace '*'     # empty or paused only
hf jobs ls                          # empty
hf cache ls                         # size back to expectations
curl -s -o /dev/null -w '%{http_code}\n' https://huggingface.co/api/whoami-v2 -H "Authorization: Bearer $OLD_TOKEN"   # expect 401 for a deleted token
```

Then check the billing page for the next day's usage.
