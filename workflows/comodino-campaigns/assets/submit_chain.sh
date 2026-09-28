#!/bin/bash
# Submit one comodino chain job with a short job name derived from the bundle path.
# Run from CAMPAIGN/99_jobs:
#   submit_chain.sh BUNDLE [START_STAGE] [extra sbatch options...]
# BUNDLE is CAMPAIGN/FAMILY/NN_system/rNN/NN_bundle. The job name is
#   <campaign NN><family b|i>-<system>-<bundle initial><bundle NN>[r<replica>]
# with underscores dropped and "pair(s)" shortened to "p", e.g. 06i-brpt111-p01 for
# 06_kbr_pt111_f/03_interface/03_br_pt111/r01/01_prepare or 05b-nacl40p-o02 for a 40-pair observation, with the replica
# suffix only when it is not r01. RECORDS, CODE (99_jobs/comodino) and the mdwatch comment follow from BUNDLE.
set -euo pipefail
BUNDLE=$(readlink -f "${1:?usage: submit_chain.sh BUNDLE [START_STAGE] [sbatch options]}")
START_STAGE=${2:-minimize}
shift $(( $# >= 2 ? 2 : 1 ))

bundle_name=$(basename "$BUNDLE")
replica_dir=$(dirname "$BUNDLE")
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
bundle=$(sed -E 's/^([0-9]+)_(.).*/\2\1/' <<< "$bundle_name")
replica=$(basename "$replica_dir")
name="${campaign_nn}${family}-${system}-${bundle}"
[[ $replica == r01 ]] || name+="${replica}"

RECORDS="$replica_dir/records/$bundle_name"
CODE="$campaign_dir/99_jobs/comodino"
exec sbatch --job-name="$name" --comment="mdwatch:stall=30,watch=$BUNDLE" \
    --export="ALL,BUNDLE=$BUNDLE,RECORDS=$RECORDS,START_STAGE=$START_STAGE,CODE=$CODE" \
    "$@" "$(dirname "$(readlink -f "$0")")/comodino_chain.sbatch"
