# lmarqs/skills — contributor guide

Sharable collection of Claude Code skills, installed by consumers via
`npx skills@latest add lmarqs/skills`. This file is for *contributors*; it is not
shipped to consumers (the installer only reads `skills/**`).

## Layout

- `skills/<name>/SKILL.md` — one skill. Frontmatter `name` + `description` is the
  trigger metadata; keep `description` ≤ 1024 chars (it's always in context).
- `skills/<name>/references/*.md` — progressive-disclosure detail, linked from the
  body. Keep the SKILL.md body lean; push depth here.
- `.agents/skills/skill-creator/` — vendored authoring/eval tool (pinned in
  `skills-lock.json`); a dev dependency, not distributed.

## Conventions

- Skill name = kebab-case, matches its directory.
- Write `description` in third person, lead with what it does, then concrete
  trigger conditions and synonyms users might say.
- Keep SKILL.md bodies well under skill-creator's limits; move tables/examples to
  `references/`.

## Workflow

- Author/refine skills with the vendored skill-creator skill.
- Start non-trivial changes in Plan mode; get approval before large edits.

## Verification

- `python3 .agents/skills/skill-creator/scripts/quick_validate.py skills/<name>`
  on any skill you touch (frontmatter + structure; needs `pyyaml`).
- Confirm `description` ≤ 1024 chars and the body links every `references/` file.

## Adding a skill

1. Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter.
2. Add `references/` for depth; link them from the body.
3. List it in `README.md`'s skills table.
