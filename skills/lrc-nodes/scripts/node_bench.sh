#!/bin/bash
# A/B compute benchmark of a suspect node against a known-good node of the same partition (assets/node_bench.sbatch,
# about a minute each), and a report that flags degraded nodes.
# usage: node_bench.sh submit PARTITION SUSPECT GOOD [DIR]   submit both jobs, outputs in DIR (default ./nodebench)
#        node_bench.sh report [DIR]                          one line per benchmarked node, slowest first
# Report lines: NODE PARTITION RANKS TIMESTEPS_PER_S PERCENT_OF_BEST [DEGRADED]. DEGRADED means more than 25% below
# the best node of the same partition in DIR: add it to your excluded-nodes list.
set -euo pipefail
usage() { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; }
[[ ${1:-} == -h || ${1:-} == --help ]] && { usage; exit 0; }
here=$(dirname "$(readlink -f "$0")")
case ${1:-} in
    submit)
        (( $# >= 4 )) || { usage >&2; exit 2; }
        part=$2 dir=${5:-nodebench}
        mkdir -p "$dir"
        for node in "$3" "$4"; do
            sbatch --parsable -p "$part" -w "$node" --chdir="$dir" --output="nodebench-%N-%j.out" "$here/../assets/node_bench.sbatch"
        done ;;
    report)
        dir=${2:-nodebench}
        cat "$dir"/nodebench-*.out 2>/dev/null | awk '$1 == "NODEBENCH" && $5 != "" {
                node[NR] = $2; part[NR] = $3; ranks[NR] = $4; rate[NR] = $5
                if ($5 > best[$3]) best[$3] = $5
            }
            END {
                for (i in node) {
                    pct = 100 * rate[i] / best[part[i]]
                    printf "%s %s %s %s %.0f%s\n", node[i], part[i], ranks[i], rate[i], pct, (pct < 75 ? " DEGRADED" : "")
                }
            }' | sort -k5,5n ;;
    *) usage >&2; exit 2 ;;
esac
