#!/bin/bash
# sbatch that keeps jobs off the excluded nodes (excluded_nodes.sh: $EXCLUDE_NODES_FILE, else the nano group list).
# usage: xbatch.sh [sbatch options] SCRIPT [args]
# With no excluded nodes it is plain sbatch. Prints sbatch's output; exits with its code.
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
(( $# )) || { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0" >&2; exit 2; }
nodes=$(bash "$(dirname "$(readlink -f "$0")")/excluded_nodes.sh") || exit 2
exclude=()
[[ -n $nodes ]] && exclude=(--exclude="$nodes")
exec sbatch ${exclude[@]+"${exclude[@]}"} "$@"
