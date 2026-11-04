# lmarqs/skills

A sharable collection of Claude Code skills that consumers install with `npx skills@latest add lmarqs/skills`; the
installer reads only `skills/**`. The [README](README.md) lists the skills.

Stack: Markdown skills; Python 3 with PyYAML for the vendored skill-creator scripts; Cook, pinned in `mise.toml`,
for the agent layout.

## Quick reference

- Install or add a dependency: `mise install`; `pip install pyyaml` (unverified); add a tool with
  `mise use <tool>@<version>`
- Run, build, lint, format, generate code, local services: none
- Test one file: `python3 .agents/skills/skill-creator/scripts/quick_validate.py skills/<name>`
- Quick check, seconds on what changed: the Test one file command on each skill you touched
- Done check, all that must pass before a change is done, in under ten seconds with no services:
  1. The Quick check, which also caps `description` at 1024 characters.
  2. Every `references/` file linked from its body, printing nothing:
     `sh -c 'for f in skills/$0/references/*.md; do [ -e "$f" ] && ! grep -q "references/${f##*/}" "skills/$0/SKILL.md" && echo "unlinked $f"; done; true' <name>`
  3. When `AGENTS.md`, `.agents/` or `.gitignore` changed: `sh .agents/skills/agents-layout/scripts/check.sh` and
     `cook check`.

## Boundaries

**Always**

- Run the Quick check before moving on. A change is done when the Done check passes.
- Report each check's result, or that it did not run.
- Update this file in the change that alters a command, path or rule it names.
- Keep this file under 800 words, with at most five Gotchas, each a trap any task can hit; past 1,200 words, move a
  section into a skill or memory file before adding. All `AGENTS.md` files together stay under 16 KiB.
- List a new skill in the README's skills table.
- Change generated files by cooking their recipe: `cook.lock`, `.agents/adapters/`, `.agents/hooks/session-start`,
  `.agents/hooks/worktree`, `.agents/skills/agents-layout/`, and the `cook:begin` sections of `.gitignore` and this
  file.
- Fix the cause when a check fails; the check stays as strict as it was.

**Never** commit secrets or credentials, or put personal data in logs, fixtures or commits.

**Stop and ask** before large edits or a non-trivial change without an approved plan, and when a check fails again
after a fix, a command is refused, or a decision is left open.

Enforced by `.agents/permission/policy.yaml`. A refusal is the rule working.

## Where things go

- New code: one skill per `skills/<name>/`, its trigger metadata in `SKILL.md` frontmatter, a lean body, and depth
  such as tables and examples in `skills/<name>/references/*.md`.
- The maintainer's global instructions: `global/AGENTS.md`.
- Tests: evals and benchmarks per skill in `workspaces/<name>/`, such as `workspaces/sql-migration-guide/iteration-1/`.
- Decisions and domain rules: the skill's own `references/`.
- A procedure an agent repeats: a skill in `.agents/skills/`.
- A trap in one area: `.agents/memory/`, listed under Deep dive.

## Rules

- A behavior change ships with a test; a bug fix with one that failed before the fix.
- Comments record only reasons the code cannot show.
- Change only what the task needs, matching the surrounding code.
- A skill's `name` is kebab-case and matches its directory. Its `description` is third person, leads with what it
  does, then the trigger conditions and synonyms users say, as `skills/sql-migration-guide/SKILL.md` does.
- Commits: one change per commit with an imperative subject; work reaches `main` through a pull request or a push.
- Deploy: none; consumers install from this GitHub repository, as the README's Install section says.

## Gotchas

- `quick_validate.py` rejects `skills/scaffold` for its `disable-model-invocation` frontmatter key, a key Claude Code
  reads; judge every other skill by its own result.
- skill-creator writes eval scratch to `skills/<name>-workspace/`, which `.gitignore` keeps out of the shipped
  `skills/**`; keep eval results in `workspaces/<name>/`.

## Deep dive (read on demand)

- Authoring, evals and description tuning: the skill-creator skill, `.agents/skills/skill-creator/SKILL.md`,
  pinned in `skills-lock.json`.
- Agent instructions, permissions and harness links: the agents-layout skill,
  `.agents/skills/agents-layout/SKILL.md`.
<!-- cook:begin io.github.lmarqs.cookbook:git#worktrees/worktrees -->
<!-- io.github.lmarqs.cookbook:git#worktrees --instructions=AGENTS.md -->
- Worktrees: branch `<branch>` is checked out at `.worktrees/<branch>`; `.worktrees/README.md` says how to
  create one ready to run and remove it.
<!-- cook:end io.github.lmarqs.cookbook:git#worktrees/worktrees -->
