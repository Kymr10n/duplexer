#!/bin/bash
set -euo pipefail
INBOX="/duplex-inbox"
LOGFILE="/logs/duplexer.log"
log() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"; echo "$msg" | tee -a "$LOGFILE"; }
log "[watch] duplexer watcher started, monitoring $INBOX"
while true; do
  inotifywait -e close_write,move,create "$INBOX" >/dev/null 2>&1 || true
  /app/merge_once.sh || true
done
