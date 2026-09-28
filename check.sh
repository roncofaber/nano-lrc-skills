#!/bin/bash
set -u
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
status=0
declare -A seen=()

fail() { echo "FAIL $1: $2"; status=1; }
field() { awk -v key="$2" '/^---$/{n++; next} n==1 && $0 ~ "^" key ":" {sub("^" key ": *", ""); print; exit}' "$1"; }

for dir in "$root"/skills/*/ "$root"/workflows/*/; do
    [[ -d "$dir" ]] || continue
    dir="${dir%/}" name="$(basename "${dir%/}")"
    rel="${dir#"$root"/}" file="$dir/SKILL.md"
    [[ -f "$file" ]] || { fail "$rel" "no SKILL.md"; continue; }
    [[ "$(head -n1 "$file")" == "---" ]] || { fail "$rel" "no frontmatter"; continue; }
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && ${#name} -le 64 ]] || fail "$rel" "invalid name"
    [[ "$(field "$file" name)" == "$name" ]] || fail "$rel" "frontmatter name != directory"
    desc="$(field "$file" description)"
    if [[ -z "$desc" ]]; then
        fail "$rel" "no description"
    elif [[ "$desc" == ">"* || "$desc" == "|"* ]]; then
        fail "$rel" "description must be a single line"
    elif (( ${#desc} > 1024 )); then
        fail "$rel" "description over 1024 characters"
    fi
    [[ -n "${seen[$name]:-}" ]] && fail "$rel" "name also used by ${seen[$name]}"
    seen[$name]="$rel"
    while IFS= read -r hit; do
        fail "$rel" "personal path: ${hit#"$dir"/}"
    done < <(grep -rnoE '/global/home/users/[a-z0-9_]+|~/mySoftwares' "$dir")
    while IFS= read -r md; do
        while IFS= read -r target; do
            target="${target%%#*}"
            [[ -z "$target" || "$target" =~ ^[a-z]+: ]] && continue
            [[ -e "$(dirname "$md")/$target" ]] || fail "$rel" "broken link in ${md#"$dir"/}: $target"
        done < <(grep -oE '\]\([^) ]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//')
    done < <(find "$dir" -name '*.md')
done

(( status == 0 )) && echo "OK: all skills valid"
exit $status
