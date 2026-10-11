#!/usr/bin/env bash
# Read-only MLflow tracking server check: version, health, experiments, OTLP trace route. Never prints secrets.
# Usage: MLFLOW_TRACKING_URI=http://localhost:5000 [MLFLOW_CREDENTIALS_FILE=~/.mlflow.cred] scripts/check.sh
# The credentials file holds one line, user:password, mode 0600. Needs bash 3.2+, curl and jq.
set -u

base="${MLFLOW_TRACKING_URI:-http://localhost:5000}"
base="${base%/}"
cred_file="${MLFLOW_CREDENTIALS_FILE:-}"
fail=0

ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
note() { printf 'note  %s\n' "$1"; }

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

auth_args=()
if [ -n "$cred_file" ] && [ -r "$cred_file" ]; then
  auth_args=(-u "$(tr -d '\n' < "$cred_file")")
  ok "using credentials from file (value not shown)"
elif [ -n "${MLFLOW_TRACKING_USERNAME:-}" ] && [ -n "${MLFLOW_TRACKING_PASSWORD:-}" ]; then
  note "MLFLOW_TRACKING_USERNAME/PASSWORD are set; use MLFLOW_CREDENTIALS_FILE to send them from this script"
fi

health="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$base/health" 2>/dev/null || true)"
case "$health" in
  200) ok "health $base/health" ;;
  403) bad "health returned 403: the Host header is rejected, add it to --allowed-hosts" ;;
  000|"") bad "$base unreachable" ; exit 1 ;;
  *) bad "health returned HTTP $health" ;;
esac

code="$(curl -sS -m 5 -o /tmp/mlflow-version.$$ -w '%{http_code}' ${auth_args[@]+"${auth_args[@]}"} "$base/version" 2>/dev/null || true)"
case "$code" in
  200) ok "server version $(tr -d '\n' < /tmp/mlflow-version.$$)" ;;
  401) note "version needs credentials: authentication is on"; if [ "${#auth_args[@]}" -eq 0 ]; then note "set MLFLOW_CREDENTIALS_FILE to continue"; fi ;;
  *) note "version endpoint returned HTTP $code" ;;
esac
rm -f /tmp/mlflow-version.$$

if [ "$code" = "200" ]; then
  exp="$(curl -sS -m 8 ${auth_args[@]+"${auth_args[@]}"} -X POST "$base/api/2.0/mlflow/experiments/search" -H 'Content-Type: application/json' -d '{"max_results":50}' 2>/dev/null || true)"
  if printf '%s' "$exp" | jq -e '.experiments' >/dev/null 2>&1; then
    ok "experiments (id name): $(printf '%s' "$exp" | jq -r '[.experiments[]? | "\(.experiment_id) \(.name)"] | join("; ")')"
  else
    note "could not list experiments"
  fi
fi

otlp="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' ${auth_args[@]+"${auth_args[@]}"} -X POST "$base/v1/traces" -H 'Content-Type: application/x-protobuf' -H 'x-mlflow-experiment-id: 0' --data-binary '' 2>/dev/null || true)"
case "$otlp" in
  400|422) ok "OTLP route /v1/traces reachable (HTTP $otlp for an empty body)" ;;
  401) note "OTLP route needs credentials (authentication on)" ;;
  403) bad "OTLP route returned 403: check --allowed-hosts" ;;
  404) bad "OTLP route returned 404: MLflow older than 3.6.0 or a proxy path problem" ;;
  *) note "OTLP route returned HTTP $otlp" ;;
esac

if [ -n "${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-}" ]; then
  case "${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT}" in
    */v1/traces) ok "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT ends with /v1/traces" ;;
    *) note "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT should be the full URL ending in /v1/traces" ;;
  esac
fi
case "${OTEL_EXPORTER_OTLP_TRACES_HEADERS:-}" in
  *x-mlflow-experiment-id=*) ok "experiment header is set (value not shown)" ;;
  "") : ;;
  *) note "OTEL_EXPORTER_OTLP_TRACES_HEADERS is set without x-mlflow-experiment-id" ;;
esac
exit "$fail"
