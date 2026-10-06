#!/bin/bash
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0 total=0

check() {
    total=$((total + 1))
    if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; failures=$((failures + 1)); fi
}

skill() {
    local dir="$1/$2" name="${3:-$(basename "$2")}" desc="${4:-Use for tests.}"
    mkdir -p "$dir"
    printf -- '---\nname: %s\ndescription: %s\n---\n\n# Test\n' "$name" "$desc" > "$dir/SKILL.md"
}

# check.sh
root="$tmp/check"
skill "$root" skills/lrc-good
skill "$root" workflows/good-flow
"$repo/check.sh" "$root" >/dev/null; check "valid tree passes" "$?" "0"

skill "$root" skills/lrc-wrong lrc-other
"$repo/check.sh" "$root" | grep -q "skills/lrc-wrong: frontmatter name != directory"; check "name mismatch reported" "$?" "0"
rm -rf "$root/skills/lrc-wrong"

skill "$root" skills/Bad_Name Bad_Name
"$repo/check.sh" "$root" | grep -q "skills/Bad_Name: invalid name"; check "invalid name reported" "$?" "0"
rm -rf "$root/skills/Bad_Name"

skill "$root" skills/lrc-block lrc-block ">"
"$repo/check.sh" "$root" | grep -q "skills/lrc-block: description must be a single line"; check "block scalar rejected" "$?" "0"
rm -rf "$root/skills/lrc-block"

skill "$root" skills/lrc-long lrc-long "$(printf 'x%.0s' {1..1025})"
"$repo/check.sh" "$root" | grep -q "skills/lrc-long: description over 1024 characters"; check "long description rejected" "$?" "0"
rm -rf "$root/skills/lrc-long"

skill "$root" workflows/lrc-good
"$repo/check.sh" "$root" | grep -q "name also used by"; check "duplicate name rejected" "$?" "0"
rm -rf "$root/workflows/lrc-good"

echo 'see /global/home/users/someone/x and ~/mySoftwares/y' >> "$root/skills/lrc-good/SKILL.md"
out="$("$repo/check.sh" "$root")"
grep -q "personal path: .*/global/home/users/someone" <<< "$out"; check "user home path rejected" "$?" "0"
grep -q "personal path: .*~/mySoftwares" <<< "$out"; check "mySoftwares rejected" "$?" "0"
skill "$root" skills/lrc-good
echo 'scratch is /global/scratch/users/$USER and /global/home/users/$USER' >> "$root/skills/lrc-good/SKILL.md"
"$repo/check.sh" "$root" >/dev/null; check "\$USER paths allowed" "$?" "0"

echo 'read [ref](references/missing.md) and [web](https://example.org)' >> "$root/skills/lrc-good/SKILL.md"
out="$("$repo/check.sh" "$root")"
grep -q "broken link in SKILL.md: references/missing.md" <<< "$out"; check "broken link rejected" "$?" "0"
grep -q "example.org" <<< "$out"; check "web links ignored" "$?" "1"
mkdir -p "$root/skills/lrc-good/references" && touch "$root/skills/lrc-good/references/missing.md"
"$repo/check.sh" "$root" >/dev/null; check "existing link passes" "$?" "0"

mkdir -p "$root/skills/lrc-good/assets"
printf '#!/bin/bash\nif true; then\n' > "$root/skills/lrc-good/assets/broken.sbatch"
"$repo/check.sh" "$root" | grep -q "shell syntax error in assets/broken.sbatch"; check "broken asset script rejected" "$?" "0"
rm "$root/skills/lrc-good/assets/broken.sbatch"

# submit_chain.sh
sub="$repo/workflows/comodino-campaigns/assets/submit_chain.sh"
fake="$tmp/fakebin" camp="$tmp/scratch/06_kbr_pt111_f"
mkdir -p "$fake" "$camp/03_interface/03_br_pt111/r01/01_prepare" "$camp/03_interface/03_br_pt111/r02/03_walker_starts/w07" \
    "$camp/02_bulk/09_kbr_40pairs/r01/02_observe" "$camp/03_interface/03_br_pt111/r01/01_prepare/w01"
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$fake/sbatch"; chmod +x "$fake/sbatch"
submit() { PATH="$fake:$PATH" bash "$sub" "$@"; }
out="$(submit "$camp/03_interface/03_br_pt111/r01/01_prepare")"
grep -qx -- "--job-name=06i-brpt111-p01" <<< "$out"; check "bundle job name" "$?" "0"
grep -q "RECORDS=$camp/03_interface/03_br_pt111/r01/records/01_prepare," <<< "$out"; check "bundle records" "$?" "0"
out="$(submit "$camp/02_bulk/09_kbr_40pairs/r01/02_observe" nvt_sample)"
grep -qx -- "--job-name=06b-kbr40p-o02" <<< "$out"; check "bulk observe job name" "$?" "0"
out="$(submit "$camp/03_interface/03_br_pt111/r02/03_walker_starts/w07" nvt_sample)"
grep -qx -- "--job-name=06i-brpt111-w07r02" <<< "$out"; check "branch job name" "$?" "0"
grep -q "RECORDS=$camp/03_interface/03_br_pt111/r02/records/03_walker_starts/w07," <<< "$out"; check "branch records" "$?" "0"
grep -q "START_STAGE=nvt_sample,CODE=$camp/99_jobs/comodino" <<< "$out"; check "branch code pin" "$?" "0"
grep -q -- "--comment=mdwatch:stall=30,watch=$camp/03_interface/03_br_pt111/r02/03_walker_starts/w07" <<< "$out"; check "branch watch" "$?" "0"
submit "$camp/03_interface/03_br_pt111/r01/01_prepare/w01" >/dev/null 2>&1; check "branch of a non-walker bundle rejected" "$?" "2"

# submit_suite.sh
suite_sub="$repo/workflows/comodino-campaigns/assets/submit_suite.sh"
suite="$camp/03_interface/03_br_pt111/r01/04_metadynamics"
mkdir -p "$suite"
printf '{"schema_version": 2, "walkers": ["w01", "w02", "w03"], "launch": "lammps_partition"}' > "$suite/suite.json"
ssubmit() { PATH="$fake:$PATH" bash "$suite_sub" "$@"; }
out="$(ssubmit "$suite" metadynamics)"
grep -qx -- "--job-name=06i-brpt111-m" <<< "$out"; check "suite job name" "$?" "0"
grep -qx -- "--nodes=3" <<< "$out"; check "suite one node per walker" "$?" "0"
grep -qx -- "--account=nano" <<< "$out"; check "suite etna account" "$?" "0"
grep -q "SUITE=$suite,STAGE=metadynamics,CODE=$camp/99_jobs/comodino" <<< "$out"; check "suite exports" "$?" "0"
grep -qx -- "--ntasks-per-node=24" <<< "$out"; check "suite etna 24 cores" "$?" "0"
out="$(ssubmit "$suite" wall_ramp dirac1)"
grep -qx -- "--account=dirac1" <<< "$out"; check "suite dirac1 account" "$?" "0"
out="$(ssubmit "$suite" wall_ramp etna_bigmem)"
grep -qx -- "--ntasks-per-node=32" <<< "$out"; check "suite bigmem 32 cores" "$?" "0"
out="$(ssubmit "$suite" wall_ramp etna_c40)"
grep -qx -- "--ntasks-per-node=40" <<< "$out"; check "suite c40 40 cores" "$?" "0"
grep -q -- "--exclude" <<< "$out"; check "no exclude without a file" "$?" "1"
printf 'n0001.etna0,n0068.etna0\nn0214.etna0\n' > "$tmp/excluded.dat"
out="$(EXCLUDE_NODES_FILE="$tmp/excluded.dat" ssubmit "$suite" metadynamics)"
grep -qx -- "--exclude=n0001.etna0,n0068.etna0,n0214.etna0" <<< "$out"; check "multi-line exclude list flattened" "$?" "0"
ssubmit "$suite" production >/dev/null 2>&1; check "unknown suite stage rejected" "$?" "2"
ssubmit "$suite" metadynamics lr6 >/dev/null 2>&1; check "unsupported partition rejected" "$?" "2"
printf '{"schema_version": 1, "walkers": ["w01"]}' > "$suite/suite.json"
ssubmit "$suite" metadynamics >/dev/null 2>&1; check "schema 1 suite rejected" "$?" "1"

# node_window.sh
window="$repo/skills/lrc-cluster/assets/node_window.sh"
cat > "$fake/sinfo" <<'SH'
#!/bin/bash
for a in "$@"; do [[ $prev == -p ]] && part=$a; prev=$a; done
case $part in
    etna) printf 'n1.etna0 idle\nn2.etna0 idle\nn3.etna0 idle*\nn4.etna0 alloc\nn5.etna0 idle\n' ;;
    big) printf 'b1 idle\nb2 idle\n' ;;
esac
SH
chmod +x "$fake/sinfo"
nwin() { PATH="$fake:$PATH" bash "$window" "$@"; }
out="$(nwin -n 3 -p big,etna -i 1 -t 0)"; rc=$?
check "window opens" "$rc" "0"
check "exact idle only" "$(tail -n1 <<< "$out")" "WINDOW etna n1.etna0,n2.etna0,n5.etna0"
printf 'n2.etna0\n' > "$tmp/excl"
nwin -n 3 -p etna -x "$tmp/excl" -i 1 -t 0 >/dev/null; check "excluded nodes not counted" "$?" "124"
nwin -n 2 -p big -l "$tmp/window.log" -i 1 -t 0 >/dev/null
grep -q "WINDOW big b1,b2" "$tmp/window.log"; check "window logged" "$?" "0"
nwin -p etna >/dev/null 2>&1; check "count required" "$?" "2"

# partitions.sh
part="$repo/skills/lrc-cluster/assets/partitions.sh"
check "etna cores" "$(bash "$part" etna)" "etna nano 24"
check "bigmem cores" "$(bash "$part" etna_bigmem)" "etna_bigmem nano 32"
check "c40 cores" "$(bash "$part" etna_c40)" "etna_c40 nano 40"
check "dirac1 account" "$(bash "$part" dirac1)" "dirac1 dirac1 24"
bash "$part" lr6 >/dev/null 2>&1; check "unknown partition rejected" "$?" "2"

# templates take ranks from the allocation
for f in skills/lrc-cluster/assets/etna_cpu.sbatch workflows/comodino-campaigns/assets/comodino_chain.sbatch; do
    grep -qE '^#SBATCH --ntasks=' "$repo/$f"; check "$f has no fixed --ntasks" "$?" "1"
    grep -q 'SLURM_CPUS_ON_NODE' "$repo/$f"; check "$f derives ranks from the allocation" "$?" "0"
done

# submit_chain.sh partition argument
out="$(submit "$camp/03_interface/03_br_pt111/r01/01_prepare" minimize etna_c40)"
grep -qx -- "--partition=etna_c40" <<< "$out"; check "chain partition" "$?" "0"
grep -qx -- "--ntasks-per-node=40" <<< "$out"; check "chain c40 whole node" "$?" "0"
out="$(submit "$camp/03_interface/03_br_pt111/r01/01_prepare")"
grep -qx -- "--ntasks-per-node=24" <<< "$out"; check "chain etna default whole node" "$?" "0"
out="$(EXCLUDE_NODES_FILE="$tmp/excluded.dat" submit "$camp/03_interface/03_br_pt111/r01/01_prepare" minimize etna)"
grep -qx -- "--exclude=n0001.etna0,n0068.etna0,n0214.etna0" <<< "$out"; check "chain exclude list" "$?" "0"

# install.sh
src="$tmp/share" home="$tmp/home"
mkdir -p "$src" "$home"
cp "$repo/install.sh" "$src/"
skill "$src" skills/lrc-one
skill "$src" workflows/flow-two
chmod -R a-w "$src"
HOME="$home" "$src/install.sh" >/dev/null; check "install succeeds from read-only checkout" "$?" "0"
chmod -R u+w "$src"
for t in .claude/skills .agents/skills; do
    check "links lrc-one into $t" "$(readlink "$home/$t/lrc-one")" "$src/skills/lrc-one"
    check "links flow-two into $t" "$(readlink "$home/$t/flow-two")" "$src/workflows/flow-two"
done

HOME="$home" "$src/install.sh" --check >/dev/null; check "check clean after install" "$?" "0"
check "second run is silent" "$(HOME="$home" "$src/install.sh")" ""

mkdir -p "$home/.claude/skills/lrc-mine"
ln -s /elsewhere "$home/.agents/skills/lrc-mine"
skill "$src" skills/lrc-mine
out="$(HOME="$home" "$src/install.sh")"
grep -q "skip $home/.claude/skills/lrc-mine" <<< "$out"; check "own directory skipped" "$?" "0"
check "own directory untouched" "$(test -L "$home/.claude/skills/lrc-mine"; echo $?)" "1"
check "foreign link untouched" "$(readlink "$home/.agents/skills/lrc-mine")" "/elsewhere"
rm -rf "$src/skills/lrc-mine"

mv "$src/skills/lrc-one" "$src/workflows/lrc-one"
HOME="$home" "$src/install.sh" --check >/dev/null; check "check reports moved skill" "$?" "1"
HOME="$home" "$src/install.sh" >/dev/null
check "moved skill relinked" "$(readlink "$home/.claude/skills/lrc-one")" "$src/workflows/lrc-one"
rm -rf "$src/workflows/flow-two"
HOME="$home" "$src/install.sh" >/dev/null
check "deleted skill link removed" "$(test -L "$home/.agents/skills/flow-two"; echo $?)" "1"

echo "$((total - failures))/$total passed"
exit $((failures > 0))
