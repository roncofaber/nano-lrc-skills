#!/bin/bash
set -u
src="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
check=false
[[ "${1:-}" == "--check" ]] && check=true
pending=0

act() {
    pending=1
    if $check; then echo "would $1"; else echo "$1"; fi
}

for target in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    $check || mkdir -p "$target"
    for link in "$target"/*; do
        [[ -L "$link" && "$(readlink "$link")" == "$src/"* && ! -f "$link/SKILL.md" ]] || continue
        act "remove stale $link"
        $check || rm "$link"
    done
    for skill in "$src"/skills/*/ "$src"/workflows/*/; do
        skill="${skill%/}"
        [[ -f "$skill/SKILL.md" ]] || continue
        dest="$target/$(basename "$skill")"
        current="$(readlink "$dest" 2>/dev/null || true)"
        if [[ "$current" == "$skill" ]]; then
            continue
        elif [[ -L "$dest" && "$current" == "$src/"* ]]; then
            act "relink $dest"
            $check || ln -sfn "$skill" "$dest"
        elif [[ -e "$dest" || -L "$dest" ]]; then
            echo "skip $dest: exists and is not from $src"
        else
            act "link $dest"
            $check || ln -s "$skill" "$dest"
        fi
    done
done

$check && exit $pending
exit 0
