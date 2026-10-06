#!/bin/bash
# Free CPU partitions for nano members: prints "PARTITION ACCOUNT CORES_PER_NODE" for one partition, or all of them
# with no argument. The single source for submit scripts; recheck with: sinfo -h -o '%P %c' -p PARTITION
#   partitions.sh [PARTITION]
set -euo pipefail
table="etna nano 24
etna_bigmem nano 32
etna_c40 nano 40
dirac1 dirac1 24"
if [[ $# -eq 0 ]]; then
    echo "$table"
    exit 0
fi
line=$(awk -v p="$1" '$1 == p' <<< "$table")
[[ -n $line ]] || { echo "not a free CPU partition for nano: $1 (one of: $(cut -d' ' -f1 <<< "$table" | tr '\n' ' '))" >&2; exit 2; }
echo "$line"
