# Access control, tags and key expiry

> Verified against Tailscale v1.104.1 (docs: Grants validated 2026-07-24, tailnet policy file syntax, ACLs, Group devices with tags, Key expiry validated 2026-01-05, Auth keys validated 2026-06-30, Funnel), 2026-10-11

Reaching `https://node-a.<tailnet>.ts.net` requires that the policy file allows your device to reach node-a on that port, and that Serve is configured. The policy file is deny-by-default for grants; a fresh tailnet ships a permissive default rule, which is fine for a one-person tailnet only.

## Policy building blocks

- **Grants** (recommended): `src`, `dst`, and permissions: network (`ip`, such as `tcp:443`) and/or application (`app`). Grants can do everything ACLs do, plus application capabilities and routing awareness (`via`). Grants and legacy ACLs may coexist; Tailscale recommends grants for most cases.
- **Tags** (`tag:llm-server`): identify non-human devices. Define in `tagOwners` before use. A node gets a tag by authenticating as it (`tailscale up --advertise-tags=tag:llm-server`, or an auth key with the tag). Tagged devices have **key expiry disabled by default** and no user identity headers in Serve.
- **Groups** (`group:llm-users`): sets of users defined in the policy file or synced from your identity provider.
- **`nodeAttrs`**: per-device attributes, such as `funnel`.
- **`tests`**: assertions checked on every save: if a test fails the policy change is rejected. Write them before narrowing access.

## Starter policy

`assets/policy-llm.hujson` holds a commented example: users in `group:llm-users` may reach `tag:llm-server` on `tcp:443` only (the Serve port), admins own the tag, Funnel is not granted, tests assert allowed and denied ports. Edit group names and emails, then paste it into the admin console Access controls page. It is a template: merge, do not replace, an existing policy; ask the user before changing it. Keep an out-of-band way back (the previous policy text) because a wrong policy can lock devices out.

Minimal grant syntax:

```jsonc
{
  "grants": [
    {
      "src": ["group:llm-users"],
      "dst": ["tag:llm-server"],
      "ip": ["tcp:443"],
    },
  ],
  "tagOwners": { "tag:llm-server": ["autogroup:admin"] },
}
```

Grant selectors for `src` and `dst` include emails, groups, tags, `autogroup:admin`, `autogroup:member`, `autogroup:tagged`, and for destinations `autogroup:internet` and `svc:<name>`.

## Per-model or per-key control still lives in the gateway

The tailnet decides which machines can open a TCP connection. Which model a caller may use, budgets and revocation are gateway functions (`litellm` skill). Use both layers.

## Key expiry

- Node keys expire every **180 days by default**, set per tailnet between **1 and 180 days** (Device management page). A change applies to devices at their next login.
- An expired device drops off: connections to and from it stop.
- **Servers should not expire:** Machines page > node menu > **Disable key expiry**, or authenticate them as a tagged device (disabled by default).
- Renew an expired node with `sudo tailscale up --force-reauth`, but not over an SSH session that rides the tailnet (it can drop). Admins can **temporarily extend** an expired key for 30 minutes from the Machines page.
- Auth keys have their own expiry (1 to 90 days); an expired auth key does not de-authorize nodes already registered with it.

## Sharing the node with people outside your tailnet

A shared device is reachable by the invited user, and Serve then sends identity headers for that user. Treat shares as full network reachability for the shared port, so keep gateway keys on.

## Tailnet Lock, SSH, posture checks

Out of scope for this skill. `tailscale up --ssh` enables Tailscale SSH per the policy file; device posture conditions apply to the source of a grant only.

## Official links

- [Grants](https://tailscale.com/kb/1324)
- [Tailnet policy file syntax](https://tailscale.com/kb/1337)
- [ACLs](https://tailscale.com/kb/1018)
- [Tags](https://tailscale.com/kb/1068)
- [Key expiry](https://tailscale.com/kb/1028)
- [Auth keys](https://tailscale.com/kb/1085)
