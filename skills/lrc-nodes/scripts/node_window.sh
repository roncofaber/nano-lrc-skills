#!/bin/bash
# Wait until N usable idle nodes are free in one partition, then print the partition and node list.
# usage: node_window.sh -n N [-p PART[,PART...]] [-x EXCLUDE_FILE] [-q QUEUE_FILE] [-i SECONDS] [-t SECONDS] [-l LOGFILE]
# Defaults: -p etna,etna_bigmem,etna_c40 -i 300 -t 172800, readings to stderr (or -l LOGFILE). Counts only nodes in the exact "idle"
# state ("idle*", "idle~" and the like are not usable), expands node lists before removing excluded nodes, and
# writes one timestamped line per reading so a stopped watcher is visible in its log. When a window opens it prints
# only "WINDOW PART n1,n2,..." on stdout (and logs it) and exits 0; it exits 124 on timeout.
# With -q, each window instead runs the first line of QUEUE_FILE with bash (WINDOW_PARTITION and WINDOW_NODES set),
# removes it, logs "RUN cmd", its output and "EXIT rc cmd", and keeps watching until the queue is empty (exit 0).
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
need="" parts=etna,etna_bigmem,etna_c40 exclude_file="" queue="" interval=300 timeout=172800 log=/dev/stderr
while getopts "n:p:x:q:i:t:l:" opt; do
    case $opt in
        n) need=$OPTARG ;; p) parts=$OPTARG ;; x) exclude_file=$OPTARG ;; q) queue=$OPTARG ;;
        i) interval=$OPTARG ;; t) timeout=$OPTARG ;; l) log=$OPTARG ;;
        *) sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
    esac
done
[[ $need =~ ^[1-9][0-9]*$ ]] || { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0" >&2; exit 2; }

lrc_cluster_script() {
    local dir c
    dir=$(dirname "$(readlink -f "$0")")
    for c in "$dir/$1" "$dir/../../lrc-cluster/scripts/$1" "$dir/../../../skills/lrc-cluster/scripts/$1" \
            "$HOME/.agents/skills/lrc-cluster/scripts/$1" "$HOME/.claude/skills/lrc-cluster/scripts/$1"; do
        [[ -f $c ]] && { echo "$c"; return 0; }
    done
    echo "$1 (lrc-cluster skill) not found; install the shared skills" >&2
    return 2
}
helper=$(lrc_cluster_script excluded_nodes.sh) || exit 2
[[ -n $exclude_file ]] && export EXCLUDE_NODES_FILE=$exclude_file
declare -A excluded=()
for node in $(bash "$helper" | tr ',' ' '); do excluded[$node]=1; done

log_line() { echo "$(date +%FT%T) $1" >> "$log"; }

start=$SECONDS
while :; do
    if [[ -n $queue && ! -s $queue ]]; then
        log_line "queue empty"
        exit 0
    fi
    readings=() opened=""
    for part in ${parts//,/ }; do
        usable=()
        while read -r node; do
            [[ -z ${excluded[$node]:-} ]] && usable+=("$node")
        done < <(sinfo -h -N -p "$part" -o '%N %t' | awk '$2 == "idle" {print $1}' | sort -u)
        readings+=("$part=${#usable[@]}")
        if (( ${#usable[@]} >= need )); then
            nodes=$(IFS=,; echo "${usable[*]:0:$need}")
            [[ $log == /dev/stderr ]] || log_line "WINDOW $part $nodes"
            echo "WINDOW $part $nodes"
            [[ -n $queue ]] || exit 0
            command=$(head -n 1 "$queue")
            sed -i '1d' "$queue"
            log_line "RUN $command"
            rc=0
            if [[ $log == /dev/stderr ]]; then
                WINDOW_PARTITION=$part WINDOW_NODES=$nodes bash -c "$command" >&2 || rc=$?
            else
                WINDOW_PARTITION=$part WINDOW_NODES=$nodes bash -c "$command" >> "$log" 2>&1 || rc=$?
            fi
            log_line "EXIT $rc $command"
            opened=1
            break
        fi
    done
    [[ -n $opened ]] || log_line "need $need idle: ${readings[*]}"
    if (( SECONDS - start >= timeout )); then
        log_line "timeout after ${timeout}s"
        exit 124
    fi
    sleep "$interval"
done
