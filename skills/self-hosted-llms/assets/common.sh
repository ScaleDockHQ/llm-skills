#!/usr/bin/env bash
# common.sh - helpers for engine wrappers started by llama-swap.
# Sourced by start-model.sh. Everything is configurable through env vars.
#
#   LLM_STACK_DIR     stack directory (default: directory of this file)
#   LLM_ENGINE_LABEL  docker label marking engine containers (default llm-stack.role=engine)
#   LLM_WORKER_HOSTS  space-separated SSH targets for worker nodes, e.g. "node-b"
#   LLM_STOP_TIMEOUT  seconds docker gives a container to exit (default 60)
#   LLM_WAIT_TIMEOUT  seconds to wait for a container to appear or disappear (default 120)

LLM_STACK_DIR="${LLM_STACK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LLM_ENGINE_LABEL="${LLM_ENGINE_LABEL:-llm-stack.role=engine}"
LLM_WORKER_HOSTS="${LLM_WORKER_HOSTS:-}"
LLM_STOP_TIMEOUT="${LLM_STOP_TIMEOUT:-60}"
LLM_WAIT_TIMEOUT="${LLM_WAIT_TIMEOUT:-120}"

log() { printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "${MODEL_ID:-wrapper}" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Run a command locally, or on a worker over SSH when $1 is a host.
# Usage: on_host <host|local> <command...>
on_host() {
  host="$1"; shift
  if [ "$host" = local ]; then
    "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" "$(printf '%q ' "$@")"
  fi
}

# Prints "running", "exited", "created", ... or "absent". Never uses pgrep:
# a `pgrep -f name` loop matches its own command line and never ends.
container_state() {
  host="$1"; name="$2"
  state=$(on_host "$host" docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null) || state=absent
  printf '%s\n' "${state:-absent}"
}

# Wait until a container is gone (absent) or stopped. Usage: wait_gone <host> <name>
wait_gone() {
  host="$1"; name="$2"; waited=0
  while :; do
    case "$(container_state "$host" "$name")" in
      absent|exited|dead|created) return 0 ;;
    esac
    [ "$waited" -ge "$LLM_WAIT_TIMEOUT" ] && return 1
    sleep 2; waited=$((waited + 2))
  done
}

# Wait until a container is running. Usage: wait_running <host> <name>
wait_running() {
  host="$1"; name="$2"; waited=0
  while [ "$(container_state "$host" "$name")" != running ]; do
    [ "$waited" -ge "$LLM_WAIT_TIMEOUT" ] && return 1
    sleep 2; waited=$((waited + 2))
  done
}

# Stop and remove one container. Usage: stop_container <host> <name>
stop_container() {
  host="$1"; name="$2"
  [ "$(container_state "$host" "$name")" = absent ] && return 0
  log "stopping $name on $host"
  on_host "$host" docker stop -t "$LLM_STOP_TIMEOUT" "$name" >/dev/null 2>&1 || true
  wait_gone "$host" "$name" || log "warning: $name on $host did not stop in time"
  on_host "$host" docker rm -f "$name" >/dev/null 2>&1 || true
}

# Stop every engine container except $1, locally and on all workers. Guards
# against strays from manual runs; llama-swap itself already swaps its models.
stop_others() {
  keep="$1"
  for host in local $LLM_WORKER_HOSTS; do
    for name in $(on_host "$host" docker ps -a --filter "label=$LLM_ENGINE_LABEL" --format '{{.Names}}' 2>/dev/null); do
      case "$name" in "$keep"|"$keep"-worker) continue ;; esac
      stop_container "$host" "$name"
    done
  done
}

# Follow a container's logs in the foreground until it exits. llama-swap
# tracks this process; when the container dies, the wrapper exits too.
follow_logs() {
  name="$1"
  docker logs -f "$name" 2>&1 &
  LOGS_PID=$!
  wait "$LOGS_PID"
  rc=$?
  log "log stream ended (rc=$rc), container state: $(container_state local "$name")"
  return "$rc"
}

# Compare image IDs (not tags) between this node and all workers.
# Usage: check_image_ids <image-ref>
check_image_ids() {
  ref="$1"
  local_id=$(docker image inspect -f '{{.Id}}' "$ref" 2>/dev/null) || die "image $ref missing locally"
  for host in $LLM_WORKER_HOSTS; do
    remote_id=$(on_host "$host" docker image inspect -f '{{.Id}}' "$ref" 2>/dev/null) || die "image $ref missing on $host"
    [ "$remote_id" = "$local_id" ] || die "image $ref differs on $host (local ${local_id#sha256:} vs ${remote_id#sha256:}); sync it before starting"
  done
}
