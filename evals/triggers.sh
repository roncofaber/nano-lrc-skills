#!/bin/bash
# Checks that the skill descriptions route requests to the right skills: for each line of evals/triggers.tsv, one
# model call sees only the skill names and descriptions (agentskills to-prompt) and names the skills it would load.
# A case passes when every expected skill is named (or none is, for "none"). One cheap call per case, 4 in parallel.
# usage: evals/triggers.sh [CASES_TSV]
# SKILL_DIRS (space-separated skill folders) replaces this repo's skills, e.g. SKILL_DIRS="$(echo ~/.agents/skills/*/)"
# tests an installed set, personal skills included, against your own cases file.
# Needs agentskills (pip install skills-ref) and an agent CLI that answers a prompt on stdout: EVAL_CMD, default
# "claude -p" (e.g. EVAL_CMD="opencode run" or "codex exec"). Exits 1 if any case fails.
set -uo pipefail
[[ ${1:-} == -h || ${1:-} == --help ]] && { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; exit 0; }
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cases=${1:-$repo/evals/triggers.tsv}
command -v agentskills >/dev/null || { echo "agentskills not found: pip install skills-ref" >&2; exit 2; }
export EVAL_CMD=${EVAL_CMD:-claude -p}
dirs=(${SKILL_DIRS:-$repo/skills/*/ $repo/workflows/*/})
export SKILLS_XML="$(agentskills to-prompt "${dirs[@]}" | grep -v -A1 '^<location>' | grep -v -e '^<location>' -e '^</location>' -e '^--$')"
export NAMES="$(basename -a "${dirs[@]}" | tr '\n' ' ')"

one() {
    local expected=$1 request=$2 prompt answer named=() name missing=""
    prompt="You are a coding agent with these skills available:
$SKILLS_XML

The user asks: \"$request\"

Which of these skills would you load before acting? Reply with only their names, comma-separated, or the word none."
    answer=$($EVAL_CMD "$prompt" 2>/dev/null | tr ',\n' '  ')
    for name in $NAMES; do grep -qw -- "$name" <<< "$answer" && named+=("$name"); done
    if [[ $expected == none ]]; then
        (( ${#named[@]} == 0 )) || missing="(expected none)"
    else
        for name in ${expected//,/ }; do [[ " ${named[*]} " == *" $name "* ]] || missing+=" $name"; done
    fi
    if [[ -z $missing ]]; then echo "ok   [$expected] $request"; else echo "FAIL [$expected] $request -> named: ${named[*]:-none}, missing:$missing"; fi
}
export -f one

results=$(grep -v '^#' "$cases" | while IFS=$'\t' read -r expected request; do printf '%s\0%s\0' "$expected" "$request"; done |
    xargs -0 -n2 -P4 bash -c 'one "$1" "$2"' _ | sort)
echo "$results"
! grep -q '^FAIL' <<< "$results"
