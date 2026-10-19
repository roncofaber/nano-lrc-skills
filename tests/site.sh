#!/bin/bash
# Checks the cluster facts the skills state against live Lawrencium: partition cores and accounts
# (lrc-cluster scripts/partitions.sh), GPU nodes, every lammps module the skills name, the Lmod default, group paths
# and the age of measured reference rates. Run on an LRC login node as a nano member, e.g. monthly from a timer.
# usage: tests/site.sh
# Prints "ok", "DRIFT" (a skill states something false: fix the skill) or "STALE" (re-measure) lines; exits 1 on DRIFT.
set -uo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
drift=0
ok() { echo "ok    $1"; }
bad() { echo "DRIFT $1"; drift=1; }
expect() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1: skills say [$3], cluster says [$2]"; fi; }

expect "SLURM version" "$(sinfo --version | grep -oE '[0-9]+\.[0-9]+' | head -1)" "$(grep -oE 'SLURM [0-9]+\.[0-9]+' "$repo/skills/lrc-cluster/SKILL.md" | cut -d' ' -f2)"

assoc=$(sacctmgr -nP show assoc user="$USER" format=account,partition)
while read -r part account cores; do
    expect "$part cores per node" "$(sinfo -h -p "$part" -o %c | sort -u | tr '\n' ' ' | sed 's/ $//')" "$cores"
    grep -qx "$account|$part" <<< "$assoc" && ok "$part accepts account $account" || bad "$part: no $account association for $USER"
done < <(bash "$repo/skills/lrc-cluster/scripts/partitions.sh")

expect "etna_gpu V100 nodes have 2 GPUs" "$(sinfo -h -N -p etna_gpu -o %G | grep V100 | sort -u)" "gpu:V100:2"
usable_k80=$(sinfo -h -N -p etna_gpu -t idle,mix,alloc -o %G | grep -c K80)
expect "etna_gpu K80 nodes unusable" "$usable_k80" "0"

type -t module >/dev/null || source /etc/profile.d/modules.sh
available=$(module -t avail lammps 2>&1)
for mod in $(grep -rhoE 'lammps/(old/)?[0-9]{8}[a-z0-9]*-[a-z0-9]+' "$repo"/skills "$repo"/workflows --include='*.md' | sort -u); do
    grep -qx "$mod" <<< "$available" && ok "module $mod exists" || bad "module $mod no longer exists"
done
module show lammps >/dev/null 2>&1 && bad "a bare 'module load lammps' now resolves; lrc-lammps says it has no default" || ok "bare lammps module has no default"

for path in /global/home/groups-sw/nano/modulefiles/rocky-8.x86_64 /global/home/groups-sw/nano/software/rocky-8.x86_64 \
        /global/home/groups/nano/share/agent-skills/install.sh /global/home/groups/nano/share/excluded_nodes \
        /global/home/groups/nano/share/mdwatch/bin/mdwatch \
        /global/home/groups/nano/share/mdwatch/examples/opencode-agent.sh; do
    [[ -e $path ]] && ok "exists $path" || bad "missing $path"
done

measured=$(grep -oE 'Reference rates \([0-9]{4}-[0-9]{2}' "$repo/skills/lrc-nodes/assets/node_bench.sbatch" | grep -oE '[0-9]{4}-[0-9]{2}')
age_days=$(( ($(date +%s) - $(date -d "$measured-01" +%s)) / 86400 ))
if (( age_days > 180 )); then echo "STALE node_bench reference rates measured $measured"; else ok "node_bench reference rates from $measured"; fi

exit $drift
