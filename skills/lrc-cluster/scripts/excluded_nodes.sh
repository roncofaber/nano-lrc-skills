#!/bin/bash
# Prints the excluded nodes as one comma-separated list (empty if none), for sbatch --exclude and the node scripts.
# usage: excluded_nodes.sh
# The list is $EXCLUDE_NODES_FILE if set (set it empty to exclude nothing), else the nano group list
# /global/home/groups/nano/share/excluded_nodes. Nodes are comma-, space- or newline-separated; "#" starts a comment.
# Exits 2 if EXCLUDE_NODES_FILE names a file that cannot be read.
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
group_list=/global/home/groups/nano/share/excluded_nodes
if [[ -n ${EXCLUDE_NODES_FILE+set} ]]; then
    file=$EXCLUDE_NODES_FILE
    [[ -z $file || -r $file ]] || { echo "excluded_nodes: cannot read EXCLUDE_NODES_FILE=$file" >&2; exit 2; }
else
    file=$group_list
    [[ -r $file ]] || file=""
fi
[[ -n $file ]] || exit 0
nodes=$(sed 's/#.*//' "$file" | tr -s ',\n\t ' ',' | sed 's/^,*//; s/,*$//')
[[ -z $nodes ]] || echo "$nodes"
