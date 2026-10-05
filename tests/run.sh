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
