#!/bin/bash
set -euo pipefail

# --- Config (env overrides supported) ---
INBOX="${INBOX:-/duplex-inbox}"
LOGFILE="${LOGFILE:-/logs/duplexer.log}"
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-300}"  # seconds, default 5 min
INOTIFY_TIMEOUT="${INOTIFY_TIMEOUT:-60}"         # wake up every 60s even if no events

# --- Setup ---
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

log() {
  # log to stdout and to file
  local ts msg
  ts="$(date '+%F %T')"
  msg="[$ts] $*"
  echo "$msg" | tee -a "$LOGFILE" >/dev/null
}

# Make sure inotifywait is available (healthcheck also checks this, but fail early here)
if ! command -v inotifywait >/dev/null 2>&1; then
  log "[watch] ERROR: inotifywait not found in container"
  exit 1
fi

# Basic sanity check for inbox
if [[ ! -d "$INBOX" ]]; then
  log "[watch] INFO: creating inbox directory: $INBOX"
  mkdir -p "$INBOX"
fi

log "[watch] duplexer watcher started, monitoring: $INBOX"
log "[watch] LOGFILE=$LOGFILE  HEARTBEAT_INTERVAL=${HEARTBEAT_INTERVAL}s  INOTIFY_TIMEOUT=${INOTIFY_TIMEOUT}s"

last_heartbeat=0

# --- Main loop ---
# Wait for new/finished files; also wake up periodically to emit heartbeat and retry merges
while true; do
  # Block for filesystem events, but time out so we can heartbeat
  # close_write: file fully written
  # move,create: new files arriving
  inotifywait -t "$INOTIFY_TIMEOUT" -e close_write,move,create "$INBOX" >/dev/null 2>&1 || true

  # Try a merge pass; never crash the watcher if merge script fails
  if /app/merge_once.sh; then
    :
  else
    rc=$?
    log "[watch] WARN: merge_once.sh exited with code $rc (continuing)"
  fi

  # Heartbeat every HEARTBEAT_INTERVAL seconds
  now=$(date +%s)
  if (( now - last_heartbeat >= HEARTBEAT_INTERVAL )); then
    log "[watch] still alive"
    last_heartbeat=$now
  fi
done
