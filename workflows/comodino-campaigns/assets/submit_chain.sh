#!/bin/bash
# Submit one comodino chain job with a short job name derived from the bundle path.
# Run from CAMPAIGN/99_jobs:
#   submit_chain.sh BUNDLE [START_STAGE [PARTITION]] [extra sbatch options...]
# PARTITION is etna (default), etna_bigmem, etna_c40 or dirac1; the job takes every core of its node (partition
# table: lrc-cluster assets/partitions.sh). Nodes in $EXCLUDE_NODES_FILE are excluded.
# BUNDLE is CAMPAIGN/FAMILY/NN_system/rNN/NN_bundle, or a walker-start branch
# CAMPAIGN/FAMILY/NN_system/rNN/NN_walker_starts/wNN. The job name is
#   <campaign NN><family b|i>-<system>-<bundle initial><bundle NN | wNN>[r<replica>]
# with underscores dropped and "pair(s)" shortened to "p", e.g. 06i-brpt111-p01 for
# 06_kbr_pt111_f/03_interface/03_br_pt111/r01/01_prepare, 05b-nacl40p-o02 for a 40-pair observation or 06i-brpt111-w07
# for branch w07, with the replica suffix only when it is not r01. RECORDS, CODE (99_jobs/comodino) and the mdwatch
# comment follow from BUNDLE. Each branch is its own single-node job.
set -euo pipefail
BUNDLE=$(readlink -f "${1:?usage: submit_chain.sh BUNDLE [START_STAGE] [sbatch options]}")
START_STAGE=${2:-minimize}
PARTITION=${3:-etna}
shift $(( $# >= 3 ? 3 : $# ))
here=$(dirname "$(readlink -f "$0")")
partitions=""
for candidate in "$here/../../../skills/lrc-cluster/assets/partitions.sh" "$here/partitions.sh" \
        "$HOME/.agents/skills/lrc-cluster/assets/partitions.sh" "$HOME/.claude/skills/lrc-cluster/assets/partitions.sh"; do
    [[ -f $candidate ]] && { partitions=$candidate; break; }
done
[[ -n $partitions ]] || { echo "partitions.sh (lrc-cluster skill) not found; install the shared skills" >&2; exit 2; }
read -r _ account cores < <(bash "$partitions" "$PARTITION") || exit 2
exclude=()
if [[ -n "${EXCLUDE_NODES_FILE:-}" ]]; then
    nodes=$(tr -s ',\n ' ',' < "$EXCLUDE_NODES_FILE" | sed 's/^,*//; s/,*$//')
    [[ -n "$nodes" ]] && exclude=(--exclude="$nodes")
fi

branch=""
if [[ $(basename "$BUNDLE") =~ ^w[0-9]{2}$ && $(basename "$(dirname "$BUNDLE")") == *_walker_starts ]]; then
    branch=$(basename "$BUNDLE")
    BUNDLE_ROOT=$(dirname "$BUNDLE")
else
    BUNDLE_ROOT=$BUNDLE
fi
bundle_name=$(basename "$BUNDLE_ROOT")
replica_dir=$(dirname "$BUNDLE_ROOT")
system_dir=$(dirname "$replica_dir")
family_dir=$(dirname "$system_dir")
campaign_dir=$(dirname "$family_dir")
[[ $(basename "$replica_dir") =~ ^r[0-9]{2}$ ]] || { echo "not a CAMPAIGN/FAMILY/NN_system/rNN/NN_bundle path: $BUNDLE" >&2; exit 2; }

case $(basename "$family_dir") in
    02_bulk) family=b ;;
    03_interface) family=i ;;
    *) echo "unknown family $(basename "$family_dir")" >&2; exit 2 ;;
esac
campaign_nn=$(basename "$campaign_dir" | grep -oE '^[0-9]+' || true)
system=$(basename "$system_dir" | sed -E 's/^[0-9]+_//; s/pairs?$/p/; s/_//g')
bundle=${branch:-$(sed -E 's/^([0-9]+)_(.).*/\2\1/' <<< "$bundle_name")}
replica=$(basename "$replica_dir")
name="${campaign_nn}${family}-${system}-${bundle}"
[[ $replica == r01 ]] || name+="${replica}"

RECORDS="$replica_dir/records/$bundle_name${branch:+/$branch}"
CODE="$campaign_dir/99_jobs/comodino"
exec sbatch --job-name="$name" --partition="$PARTITION" --account="$account" --ntasks-per-node="$cores" \
    ${exclude[@]+"${exclude[@]}"} --comment="mdwatch:stall=30,watch=$BUNDLE" \
    --export="ALL,BUNDLE=$BUNDLE,RECORDS=$RECORDS,START_STAGE=$START_STAGE,CODE=$CODE" \
    "$@" "$here/comodino_chain.sbatch"
