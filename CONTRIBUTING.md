# Contributing a skill

1. Branch, add `skills/lrc-<software>/` (or `workflows/<workflow>/`) with a `SKILL.md`, open a pull request. CI runs `tests/run.sh` and `check.sh`; both must pass.
2. Frontmatter: `name` equal to the folder name (lowercase letters, digits, single hyphens, at most 64 characters) and a one-line `description` of at most 1024 characters that says when to use the skill and, if it overlaps another skill, when to prefer that one.
3. Keep `SKILL.md` short. Put detail that only some tasks need in `references/`, templates and job scripts in `assets/`, and link them with relative links.
4. Write for any nano member: no personal home paths (`/global/home/users/<name>`), personal checkouts, accounts other than `nano`, or credentials. Use `$HOME`, `$USER` and placeholders such as `CHECKOUT`. Personal conventions belong in your own dotfiles or a private skill.
5. One software or one workflow per skill. Write prose as unwrapped markdown, one line per paragraph or list item.
6. Run `./check.sh` locally before pushing.
