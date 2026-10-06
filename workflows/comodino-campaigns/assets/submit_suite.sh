#!/bin/bash
# Submit one stage of a shared-walker suite as one job, one walker per node, every core of the node used.
# Run from CAMPAIGN/99_jobs:
#   submit_suite.sh SUITE STAGE [PARTITION] [extra sbatch options...]
# SUITE is CAMPAIGN/FAMILY/NN_system/rNN/NN_metadynamics, STAGE one of wall_ramp, wall_relax, metadynamics, PARTITION
# etna (default, 24 cores), dirac1 (24, account dirac1), etna_bigmem (32) or etna_c40 (40). All stages of a suite
# should use the same partition: a stage started on another rank count logs the restart rank-count warning. Nodes
# listed in $EXCLUDE_NODES_FILE (one or more comma- or newline-separated names) are excluded. The job name is
# <campaign NN><b|i>-<system>-<stage initial>, e.g. 01i-naau111-m; CODE is CAMPAIGN/99_jobs/comodino.
set -euo pipefail
SUITE=$(readlink -f "${1:?usage: submit_suite.sh SUITE STAGE [PARTITION] [sbatch options]}")
STAGE=${2:?usage: submit_suite.sh SUITE STAGE [PARTITION] [sbatch options]}
PARTITION=${3:-etna}
shift $(( $# >= 3 ? 3 : 2 ))

case "$STAGE" in wall_ramp|wall_relax|metadynamics) ;; *) echo "unknown stage $STAGE" >&2; exit 2 ;; esac
case "$PARTITION" in
    etna) account=nano cores=24 ;;
    etna_bigmem) account=nano cores=32 ;;
    etna_c40) account=nano cores=40 ;;
    dirac1) account=dirac1 cores=24 ;;
    *) echo "suites run on etna, etna_bigmem, etna_c40 or dirac1, not $PARTITION" >&2; exit 2 ;;
esac
exclude=()
if [[ -n "${EXCLUDE_NODES_FILE:-}" ]]; then
    nodes=$(tr -s ',\n ' ',' < "$EXCLUDE_NODES_FILE" | sed 's/^,*//; s/,*$//')
    [[ -n "$nodes" ]] && exclude=(--exclude="$nodes")
fi
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
name="${campaign_nn}${family}-${system}-${STAGE:0:1}"
[[ $(basename "$replica_dir") == r01 ]] || name+="$(basename "$replica_dir")"

exec sbatch --job-name="$name" --partition="$PARTITION" --account="$account" --nodes="$walkers" \
    --ntasks-per-node="$cores" ${exclude[@]+"${exclude[@]}"} \
    --comment="mdwatch:stall=30,watch=$SUITE" \
    --export="ALL,SUITE=$SUITE,STAGE=$STAGE,CODE=$campaign_dir/99_jobs/comodino" \
    "$@" "$(dirname "$(readlink -f "$0")")/suite_stage.sbatch"
