# Weave: privacy, redaction and content control

> Verified against weave 0.53.12 source and Weave docs "Redact PII from traces" and "Disable tracing", 2026-10-11

Weave stores what is traced: inputs, outputs, source code of ops, and (by default) client and system info. In Weave Cloud that is third-party storage. Decide first, in writing: content on, redacted or off; where stored; who can read; how long (retention controls are the platform's and were not verified here).

## Controls, in order of strength

1. **Do not send content.** Strip at a Collector (`assets/otel-collector.yaml` deletes message attributes) or do not instrument that path; `WEAVE_DISABLED=true` for an environment.
2. **PII redaction** (Python only): `pip install presidio-analyzer presidio-anonymizer`, then `weave.init("p", settings={"redact_pii": True})` redacts these entities by default before sending: credit card, crypto, email, ES_NIF, FI personal identity code, IBAN, Aadhaar, PAN, IP address, location, person, phone number, UK NHS, UK NINO, US bank number, US driver license, US passport, US SSN. Tune with `redact_pii_fields` and `redact_pii_exclude_fields`. It adds processing time.
3. **Key redaction:** `api_key`, `auth_headers` and `authorization` are redacted by default; add more with `weave.utils.sanitize.add_redact_key("token")`.
4. **Your own filter:** `postprocess_inputs` and `postprocess_output` on `weave.init` (client level, after per-op processing) or on `@weave.op` to drop or hash fields.
5. **Client and code capture:** `capture_code=False` (do not upload source), `capture_client_info=False`, `capture_system_info=False` in settings or `WEAVE_CAPTURE_*` variables.

Redaction is pattern-based and not a guarantee; a name in free text can slip through. Test with a canary.

## Canary test

Send a request containing a fake marker (`PRIVACY-CANARY-<date>`), a fake email and a fake card number; open the trace; confirm they are absent or masked. Repeat after SDK upgrades and when adding integrations.

## Other leak paths

- Op source code and docstrings are uploaded unless `capture_code` is off.
- Exceptions and stack traces can contain content.
- Attributes you add (`user_id`, `host`) are metadata; keep them pseudonymous.
- The `wandb-api-key` is a credential: keep it in `0600` files; rotate on exposure.

## Official links

- Redact PII: https://docs.coreweave.com/products/wandb/weave/guides/tracking/redact-pii
- Disable tracing: https://docs.coreweave.com/products/wandb/weave/guides/tracking/trace-disable
