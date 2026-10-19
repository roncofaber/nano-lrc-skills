#!/bin/bash
set -u
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
status=0 max_words=700
declare -A seen=()
validator="$(command -v agentskills || true)"

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
    elif [[ "$desc" != "Use when "* ]]; then
        fail "$rel" "description must start with \"Use when\""
    fi
    words=$(awk '/^---$/{n++; next} n >= 2' "$file" | wc -w)
    (( words <= max_words )) || fail "$rel" "SKILL.md body has $words words (max $max_words; move detail to references/)"
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
    while IFS= read -r sh; do
        bash -n "$sh" 2>/dev/null || fail "$rel" "shell syntax error in ${sh#"$dir"/}"
    done < <(find "$dir" -type f \( -name '*.sh' -o -name '*.sbatch' \))
    while IFS= read -r sh; do
        script="${sh#"$dir"/}"
        [[ "$script" == scripts/* ]] || { fail "$rel" "$script: shell scripts go in scripts/"; continue; }
        grep -q '^# usage: ' "$sh" || fail "$rel" "$script: no '# usage:' header line"
        bash -n "$sh" 2>/dev/null && { bash "$sh" -h 2>/dev/null | grep -q '^usage: '; } || fail "$rel" "$script: -h does not print the usage"
        grep -q "$(basename "$sh")" "$file" || fail "$rel" "$script is not mentioned in SKILL.md"
    done < <(find "$dir" -type f -name '*.sh')
    if [[ -n "$validator" ]]; then
        "$validator" validate "$dir" >/dev/null 2>&1 || fail "$rel" "agentskills validate: $("$validator" validate "$dir" 2>&1 | tail -n +2 | tr '\n' ' ')"
    fi
done
[[ -n "$validator" ]] || echo "note: agentskills not found, skipped spec validation (pip install skills-ref)"

(( status == 0 )) && echo "OK: all skills valid"
exit $status
