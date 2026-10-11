# Teardown

> Verified against Modal docs (CLI reference for `modal app`, `modal endpoint`, `modal volume`, `modal secret`, `modal workspace proxy-tokens`, Apps guide), modal 1.6.1, 2026-10-11

Billable or exposed resources on Modal, in the order to remove them. Ask before deleting anything the user did not create in this session. Deleted Volumes and stopped Endpoints cannot be recovered.

## 1. Find what exists

```bash
modal token info
modal app list
modal endpoint list
modal volume list
modal secret list
modal workspace proxy-tokens list
```

Repeat for each Environment that was used: `-e <env>` on every command.

## 2. Stop compute

| Resource                                         | Command                            | Notes                                                       |
| ------------------------------------------------ | ---------------------------------- | ----------------------------------------------------------- |
| Ephemeral App from `modal run` or `modal serve`  | Ctrl-C the command                 | Stops when the client exits. Verify in `modal app list`.    |
| Deployed App (Servers, Functions, Web Functions) | `modal app stop <app> --yes`       | Permanent. Terminates running containers.                   |
| Dedicated Endpoint                               | `modal endpoint stop <name> --yes` | Permanent.                                                  |
| Scheduled Functions (`modal.Cron`)               | Stopped with the App               | A deployed App with a schedule keeps running until stopped. |

## 3. Delete storage

```bash
modal volume delete <name> --yes       # HF cache, vLLM cache, custom weights: storage is billed
```

Keep a Volume only if the user wants warm weights next time, and say that it still bills.

## 4. Delete credentials and config

```bash
modal secret delete <name> --yes
modal workspace proxy-tokens delete wk-<id> --yes
```

Also remove the LiteLLM `model_list` entries and any 0600 token files you created, and revoke service-user tokens in the dashboard if they were made for this task.

## 5. Verify nothing accrues

```bash
modal app list                 # only stopped or unrelated Apps remain
modal endpoint list            # empty or unrelated
modal volume list              # nothing you created
modal workspace proxy-tokens list
modal billing report --for today -r h
```

Billing data lags, so check `modal billing report --for yesterday` the next day, and confirm in the dashboard that no containers are running.

## Summary template

State: Apps and Endpoints stopped, Volumes deleted (or kept and why), Secrets and tokens removed, gateway entries removed, and the date to re-check billing.
