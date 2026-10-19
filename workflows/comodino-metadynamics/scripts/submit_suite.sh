#!/bin/bash
# Submit one stage of a shared-walker suite as one job, one walker per node, every core of the node used.
# Run from CAMPAIGN/99_jobs:
# usage: submit_suite.sh SUITE STAGE [PARTITION] [extra sbatch options...]
# SUITE is CAMPAIGN/FAMILY/NN_system/rNN/NN_metadynamics, STAGE one of wall_ramp, wall_relax, metadynamics, or a
# comma-separated list run in order in the same allocation (e.g. wall_ramp,wall_relax,metadynamics): the job stops at
# the first stage whose walker reviews do not all pass, and the nodes are not given back between stages. PARTITION
# etna (default), etna_bigmem, etna_c40 or dirac1 (cores and account from lrc-cluster scripts/partitions.sh); each
# walker gets every core of its node. Stages may run on different partitions (comodino records the rank change). Excluded
# nodes come from lrc-cluster excluded_nodes.sh. The job name is
# <campaign NN><b|i>-<system>-<stage initials>, e.g. 01i-naau111-m or 01i-naau111-wwm; CODE is CAMPAIGN/99_jobs/comodino.
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
SUITE=$(readlink -f "${1:?usage: submit_suite.sh SUITE STAGE [PARTITION] [sbatch options]}")
STAGE=${2:?usage: submit_suite.sh SUITE STAGE [PARTITION] [sbatch options]}
PARTITION=${3:-etna}
shift $(( $# >= 3 ? 3 : 2 ))

initials=""
for stage in ${STAGE//,/ }; do
    case "$stage" in wall_ramp|wall_relax|metadynamics) initials+=${stage:0:1} ;; *) echo "unknown stage $stage" >&2; exit 2 ;; esac
done
here=$(dirname "$(readlink -f "$0")")
template=$here/suite_stage.sbatch
[[ -f $template ]] || template=$here/../assets/suite_stage.sbatch
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
[[ -f "$SUITE/suite.json" ]] || { echo "not a suite: $SUITE" >&2; exit 2; }
walkers=$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s.get("launch") == "lammps_partition", "suite predates partitioned launch; regenerate with protocol schema 2"; print(len(s["walkers"]))' "$SUITE/suite.json")

replica_dir=$(dirname "$SUITE")
system_dir=$(dirname "$replica_dir")
family_dir=$(dirname "$system_dir")
campaign_dir=$(dirname "$family_dir")
case $(basename "$family_dir") in
    02_bulk) family=b ;;
    03_interface) family=i ;;
    *) echo "unknown family $(basename "$family_dir")" >&2; exit 2 ;;
esac
campaign_nn=$(basename "$campaign_dir" | grep -oE '^[0-9]+' || true)
system=$(basename "$system_dir" | sed -E 's/^[0-9]+_//; s/pairs?$/p/; s/_//g')
name="${campaign_nn}${family}-${system}-${initials}"
[[ $(basename "$replica_dir") == r01 ]] || name+="$(basename "$replica_dir")"

exec sbatch --job-name="$name" --partition="$PARTITION" --account="$account" --nodes="$walkers" \
    --ntasks-per-node="$cores" ${exclude[@]+"${exclude[@]}"} \
    --comment="mdwatch:stall=30,watch=$SUITE" \
    --export="ALL,SUITE=$SUITE,STAGE=$STAGE,CODE=$campaign_dir/99_jobs/comodino" \
    "$@" "$template"
