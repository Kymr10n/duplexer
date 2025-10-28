#!/bin/bash
set -euo pipefail
INBOX="/duplex-inbox"
OUTBOX="/paperless-consume"
LOGFILE="/logs/duplexer.log"
log() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"; echo "$msg" | tee -a "$LOGFILE"; }
mapfile -t FILES < <(ls -1 "$INBOX"/*.pdf 2>/dev/null | sort || true)
COUNT=${#FILES[@]}
if [ "$COUNT" -eq 0 ]; then exit 0; fi
if [ "$COUNT" -eq 1 ]; then log "only single file found. waiting for second file."; exit 0; fi
ODD="${FILES[0]}"; EVEN="${FILES[1]}"
TS=$(date +"%Y%m%d_%H%M%S")
TMP_EVEN_REV="/tmp/even_rev_$TS.pdf"; MERGED="/tmp/merged_$TS.pdf"; FINAL_OUT="$OUTBOX/duplex_$TS.pdf"
log "processing pair:"; log "  odd-pages file:   $ODD"; log "  even-pages file:  $EVEN"; log "  target output:    $FINAL_OUT"
pdftk "$EVEN" cat end-1 output "$TMP_EVEN_REV"
pdftk A="$ODD" B="$TMP_EVEN_REV" shuffle A B output "$MERGED"
mv "$MERGED" "$FINAL_OUT"
log "merged file delivered to paperless consume: $FINAL_OUT"
rm -f "$ODD" "$EVEN" "$TMP_EVEN_REV"
log "source pdfs removed, pair complete ($TS)"
exit 0
