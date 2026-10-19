#!/bin/bash
# Where a job can start now: one line per partition with usable idle nodes (exact "idle" state, minus the excluded
# nodes of lrc-cluster excluded_nodes.sh), the other node states, pending jobs and, on GPU partitions, GPUs free on idle or mixed nodes.
# usage: free_nodes.sh [PART[,PART...]]
# Default: etna,etna_bigmem,etna_c40,dirac1,etna_gpu. Output, one line per partition:
#   PARTITION idle=N alloc=N mixed=N unavailable=N total=N pending_jobs=N [free_gpus=TYPE:N,...]
# "unavailable" counts drained, down, reserved, idle* and excluded nodes. Reasons: sinfo -R -p PARTITION
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
parts=${1:-etna,etna_bigmem,etna_c40,dirac1,etna_gpu}
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
excluded=$(bash "$helper" | tr ',' ' ') || exit 2
for part in ${parts//,/ }; do
    pending=$(squeue -h -t PD -p "$part" -o %i | wc -l)
    sinfo -h -N -p "$part" -O 'NodeList:60,StateCompact:20,Gres:60,GresUsed:80' | sort -u |
        awk -v part="$part" -v pending="$pending" -v excluded="$excluded" '
            BEGIN { n = split(excluded, list, " "); for (i = 1; i <= n; i++) skip[list[i]] = 1 }
            {
                total++
                state = $2
                if (state == "idle" && !($1 in skip)) idle++
                else if (state ~ /^alloc/) alloc++
                else if (state ~ /^mix/) mixed++
                else unavailable++
                if ((state == "idle" || state ~ /^mix$/) && !($1 in skip) && $3 ~ /^gpu:/) {
                    split($3, have, ":"); split($4, used, /[:(]/)
                    free[have[2]] += have[3] - used[3]
                }
            }
            END {
                line = sprintf("%s idle=%d alloc=%d mixed=%d unavailable=%d total=%d pending_jobs=%d", part, idle, alloc, mixed, unavailable, total, pending)
                gpus = ""
                for (t in free) gpus = gpus (gpus == "" ? "" : ",") t ":" free[t]
                if (gpus != "") line = line " free_gpus=" gpus
                print line
            }'
done
