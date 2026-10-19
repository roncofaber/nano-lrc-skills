#!/bin/bash
# Throughput from LAMMPS logs, for benchmarks and --time sizing: the last run of each log.
# usage: lammps_perf.sh LOG...
# Output, one line per log: LOG PROCS STEPS LOOP_SECONDS STEPS_PER_S NS_PER_DAY (ns/day is blank for lj units).
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
(( $# )) || { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0" >&2; exit 2; }
status=0
for log in "$@"; do
    line=$(awk '
        /^Loop time of/ { loop = $4; procs = $6; steps = $9 }
        /^Performance:/ {
            nsday = ""; rate = ""
            for (i = 2; i <= NF; i++) {
                if ($(i) == "ns/day,") nsday = $(i - 1)
                if ($(i) == "timesteps/s,") rate = $(i - 1)
            }
        }
        END { if (loop != "") print procs, steps, loop, rate, nsday }' "$log")
    if [[ -z $line ]]; then
        echo "lammps_perf: no completed run in $log" >&2
        status=1
    else
        echo "$log $line"
    fi
done
exit $status
