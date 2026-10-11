#!/usr/bin/env bash
# start-model.sh - foreground wrapper that llama-swap runs for container engines.
#
# llama-swap entry:
#   cmd:     /opt/llm-stack/start-model.sh run <model-id> ${PORT}
#   cmdStop: /opt/llm-stack/start-model.sh stop <model-id>
#
# Each model has a definition file  $LLM_STACK_DIR/models.d/<model-id>.sh  that
# defines model_run (start the head container, detached, bound to 127.0.0.1:$PORT)
# and optionally:
#   worker_run <host>   start "$MODEL_ID-worker" on each host in LLM_WORKER_HOSTS
#                       (dual node; skipped when LLM_WORKER_HOSTS is empty)
#   MODEL_IMAGE=...     image reference whose ID must match on every node
#   MODEL_EXCLUSIVE=1   also stop every other labelled engine container first.
#                       Default 0: llama-swap groups decide what runs together;
#                       use 1 only on hosts without co-resident models (it
#                       clears leftovers that llama-swap does not know about).
# The wrapper exports MODEL_ID and PORT before calling them.
#
# Usage: start-model.sh run <model-id> <port> | stop <model-id> | status <model-id>

set -u
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

cmd="${1:-}"; MODEL_ID="${2:-}"; PORT="${3:-}"
export MODEL_ID PORT

case "$MODEL_ID" in
  ''|*[!A-Za-z0-9._-]*) die "usage: $0 run <model-id> <port> | stop <model-id> | status <model-id>" ;;
esac

DEF="$LLM_STACK_DIR/models.d/$MODEL_ID.sh"
[ -r "$DEF" ] || die "no model definition at $DEF"
MODEL_IMAGE=""; MODEL_EXCLUSIVE=0
. "$DEF"

has_fn() { type "$1" 2>/dev/null | head -n 1 | grep -q 'function'; }

stop_all() {
  stop_container local "$MODEL_ID"
  if has_fn worker_run; then
    for host in $LLM_WORKER_HOSTS; do stop_container "$host" "$MODEL_ID-worker"; done
  fi
}

case "$cmd" in
  run)
    case "$PORT" in ''|*[!0-9]*) die "run needs a numeric port (pass \${PORT} from llama-swap)" ;; esac
    has_fn model_run || die "$DEF does not define model_run"
    [ "$MODEL_EXCLUSIVE" = 1 ] && stop_others "$MODEL_ID"
    stop_all
    [ -n "$MODEL_IMAGE" ] && check_image_ids "$MODEL_IMAGE"
    if has_fn worker_run && [ -n "$LLM_WORKER_HOSTS" ]; then
      for host in $LLM_WORKER_HOSTS; do
        log "starting worker on $host"
        worker_run "$host" || { stop_all; die "worker start failed on $host"; }
        wait_running "$host" "$MODEL_ID-worker" || { stop_all; die "worker on $host not running"; }
      done
    fi
    log "starting head on 127.0.0.1:$PORT"
    model_run || { stop_all; die "model_run failed"; }
    wait_running local "$MODEL_ID" || { stop_all; die "container $MODEL_ID not running"; }
    trap 'log "signal received, stopping"; [ -n "${LOGS_PID:-}" ] && kill "$LOGS_PID" 2>/dev/null; stop_all; exit 0' TERM INT
    follow_logs "$MODEL_ID"
    rc=$?
    stop_all
    exit "$rc"
    ;;
  stop)
    stop_all
    ;;
  status)
    echo "$MODEL_ID: $(container_state local "$MODEL_ID")"
    if has_fn worker_run; then
      for host in $LLM_WORKER_HOSTS; do echo "$MODEL_ID-worker@$host: $(container_state "$host" "$MODEL_ID-worker")"; done
    fi
    ;;
  *)
    die "usage: $0 run <model-id> <port> | stop <model-id> | status <model-id>"
    ;;
esac
