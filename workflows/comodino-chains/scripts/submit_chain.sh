#!/bin/bash
# Submit one comodino chain job with a short job name derived from the bundle path.
# Run from CAMPAIGN/99_jobs:
# usage: submit_chain.sh BUNDLE [START_STAGE [PARTITION]] [extra sbatch options...]
# PARTITION is etna (default), etna_bigmem, etna_c40 or dirac1; the job takes every core of its node (partition
# table: lrc-cluster scripts/partitions.sh). Excluded nodes come from lrc-cluster excluded_nodes.sh.
# BUNDLE is CAMPAIGN/FAMILY/NN_system/rNN/NN_bundle, or a walker-start branch
# CAMPAIGN/FAMILY/NN_system/rNN/NN_walker_starts/wNN. The job name is
#   <campaign NN><family b|i>-<system>-<bundle initial><bundle NN | wNN>[r<replica>]
# with underscores dropped and "pair(s)" shortened to "p", e.g. 06i-brpt111-p01 for
# 06_kbr_pt111_f/03_interface/03_br_pt111/r01/01_prepare, 05b-nacl40p-o02 for a 40-pair observation or 06i-brpt111-w07
# for branch w07, with the replica suffix only when it is not r01. RECORDS, CODE (99_jobs/comodino) and the mdwatch
# comment follow from BUNDLE. Each branch is its own single-node job.
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
BUNDLE=$(readlink -f "${1:?usage: submit_chain.sh BUNDLE [START_STAGE] [sbatch options]}")
START_STAGE=${2:-minimize}
PARTITION=${3:-etna}
shift $(( $# >= 3 ? 3 : $# ))
here=$(dirname "$(readlink -f "$0")")
template=$here/comodino_chain.sbatch
[[ -f $template ]] || template=$here/../assets/comodino_chain.sbatch
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
partitions=$(lrc_cluster_script partitions.sh) || exit 2
read -r _ account cores < <(bash "$partitions" "$PARTITION") || exit 2
nodes=$(bash "$(lrc_cluster_script excluded_nodes.sh)") || exit 2
exclude=()
[[ -n "$nodes" ]] && exclude=(--exclude="$nodes")

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
    "$@" "$template"
