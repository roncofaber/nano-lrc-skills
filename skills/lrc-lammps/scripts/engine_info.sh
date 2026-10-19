#!/bin/bash
# Provenance of a LAMMPS module: loads it and prints the resolved executable and its sha256, for run records and
# CoMoDInO authorizations. Refuses the broken pre-update3 and lammps/old builds.
# usage: engine_info.sh [MODULE]   (default lammps/20250722u6-gcc)
# Output: module=MODULE executable=PATH sha256=HASH
set -euo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
module=${1:-lammps/20250722u6-gcc}
case $module in
    lammps/20250722-gcc|lammps/20250722-gpu|lammps/20250722-intel|lammps/old/*)
        echo "engine_info: refusing $module (crashes in minimize with fix shake output_every=0)" >&2; exit 2 ;;
esac
type -t module >/dev/null || source /etc/profile.d/modules.sh
module load "$module"
exe=$(readlink -f "${LMP_EXEC:?$module did not set LMP_EXEC}")
echo "module=$module executable=$exe sha256=$(sha256sum "$exe" | cut -d' ' -f1)"
