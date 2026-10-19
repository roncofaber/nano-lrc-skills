#!/bin/bash
# Turn-start check for long-lived waits: lists your running mdwatch waits and node-window watchers, the last job
# events, and the tail of each watcher log given.
# usage: watchers.sh [WATCHER_LOG...]
# A wait you expected but that is not listed has died: re-attach it.
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
echo "== running watchers"
ps -u "$USER" -o pid=,etime=,args= | grep -E 'mdwatch wait|node_window' | grep -v grep || echo "(none)"
echo "== last job events"
if command -v mdwatch >/dev/null; then mdwatch events 20; else echo "(mdwatch not on PATH)"; fi
for log in "$@"; do
    echo "== $log"
    tail -n 5 "$log" 2>/dev/null || echo "(missing)"
done
