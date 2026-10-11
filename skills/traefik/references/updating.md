# Traefik: updating

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: docs "Releases" (deprecation/releases), "Migrate v2 to v3", "v3 migration notes", GitHub releases.

- Support table in the docs: 3.7 (released 2026-05-05) has active and security support; 3.6 active support ended 2026-05-07 and security 2026-08-16; 2.11 security support is listed as ending 2026-09-07. Dates may change; re-read the page.
- Tags: `v3.7.x` patches ship frequently (latest v3.7.14, 2026-10-06). Pin `traefik:v3.7.14` (or `v3.7` for patches only) and read `migrate/v3` notes per version before moving minors. Example from the notes: from v3.7.14 the Ingress-NGINX provider keeps dots in resource names instead of replacing them with dashes.
- **v2 to v3:** three steps in the guide: prepare configs and test v3, migrate production, then adopt v3 syntax. Routing configuration stays backward compatible with v2 syntax; install configuration has a few breaking changes listed in `v2-to-v3-details`. Test with a second instance first.
- **Procedure:** record image and digest, copy `acme.json` and dynamic config, bump the tag, `docker compose pull traefik && docker compose up -d traefik`, check `/api/http/routers` and logs, run the stream test. Roll back by restoring the recorded tag; `acme.json` stays compatible.
- Set `transport.lifeCycle.graceTimeOut` high enough for in-flight generations before restarts.
