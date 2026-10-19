#!/bin/bash
set -u
src="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
usage="usage: install.sh [--check | --uninstall | --personal]
Links every skill of this checkout into ~/.claude/skills and ~/.agents/skills.
  --check      list what would change; exit 1 if anything would
  --uninstall  remove only the links that point into this checkout
  --personal   create your own \$USER-lrc skill from templates/personal-lrc to fill in (never overwrites)"
mode=install
case "${1:-}" in
    "") ;;
    --check) mode=check ;;
    --uninstall) mode=uninstall ;;
    --personal) mode=personal ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "$usage" >&2; exit 2 ;;
esac
pending=0

if [[ $mode == personal ]]; then
    name="$(tr '[:upper:]_' '[:lower:]-' <<< "$USER")-lrc"
    dir="$HOME/.agents/skills/$name"
    if [[ -e $dir ]]; then
        echo "$dir exists; leaving it alone"
    else
        mkdir -p "$dir"
        sed "s/USERNAME/$USER/g; s/^name: .*/name: $name/" "$src/templates/personal-lrc/SKILL.md" > "$dir/SKILL.md"
        echo "created $dir/SKILL.md: replace its TODO lines"
    fi
    mkdir -p "$HOME/.claude/skills"
    [[ -e "$HOME/.claude/skills/$name" ]] || ln -s "$dir" "$HOME/.claude/skills/$name"
    exit 0
fi

act() {
    pending=1
    if [[ $mode == check ]]; then echo "would $1"; else echo "$1"; fi
}

for target in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    if [[ $mode == uninstall ]]; then
        for link in "$target"/*; do
            [[ -L "$link" && "$(readlink "$link")" == "$src/"* ]] || continue
            act "remove $link"
            rm "$link"
        done
        continue
    fi
    [[ $mode == check ]] || mkdir -p "$target"
    for link in "$target"/*; do
        [[ -L "$link" && "$(readlink "$link")" == "$src/"* && ! -f "$link/SKILL.md" ]] || continue
        act "remove stale $link"
        [[ $mode == check ]] || rm "$link"
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
            [[ $mode == check ]] || ln -sfn "$skill" "$dest"
        elif [[ -e "$dest" || -L "$dest" ]]; then
            echo "skip $dest: exists and is not from $src"
        else
            act "link $dest"
            [[ $mode == check ]] || ln -s "$skill" "$dest"
        fi
    done
done

[[ $mode == check ]] && exit $pending
exit 0
