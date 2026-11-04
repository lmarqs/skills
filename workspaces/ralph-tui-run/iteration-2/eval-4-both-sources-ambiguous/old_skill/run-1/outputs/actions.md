# Actions

All commands run in the project dir (`.../scratchpad/ev/e4-old`) unless noted. Nothing in the project was created or modified.

1. `cat skill-snapshot/SKILL.md`, `cat skill-snapshot/references/*.md`: read the skill and both references (harness-options, observed-behavior).
2. `ls -la; git status; git log --oneline -5`: repo has .beads, .claude, .codex, .cursor, .agents, AGENTS.md, CLAUDE.md, package.json, src/, tasks/. Clean tree on main. 3 commits, the last is "chore: add prd.json".
3. `cat CLAUDE.md AGENTS.md .gitignore package.json; ls ...; git remote -v; git branch -a`: gates are typecheck/lint/test, `feat/<topic>` branches, Conventional Commits, never commit to main, beads conservative git profile. package.json has scripts only, no deps. No remote. Only branch is main.
4. `cat tasks/prd.json src/index.ts .claude/settings.json .codex/config.toml .beads/config.yaml; ls .ralph-tui; bd list --all`: prd.json "Invoice PDF rendering" has 3 stories (linear deps, branchName ralph/invoice-pdf). src has only a version export. No .ralph-tui. Beads epic e4-old-uuo "Billing export" has 12 open children.
5. `bd show e4-old-uuo.1..12; bd show e4-old-uuo; bd dep tree`: strict linear chain .1→.12. Every bead's AC is "<title> works" + typecheck + lint.
6. `ralph-tui --version; bd --version; ralph-tui config show`: ralph-tui 0.12.0, bd 1.3.1, no config, defaults are claude / beads-bv / maxIterations 10. A trailing `echo ===` failed under zsh, which was harmless.
7. `ralph-tui plugins agents; ralph-tui plugins trackers; ralph-tui status`: agents include claude and codex. Trackers include json, beads, beads-bv. Status exited 2 with "No session found."
8. `ralph-tui template show --tracker beads-bv; which bv; ls node_modules; ls .git/hooks; ls .cursor/rules .agents/skills; cat .cursor/hooks.json .codex/hooks.json; bd worktree list`: the global template at ~/.config/ralph-tui/templates/beads-bv.hbs says "Do NOT create git commits" and uses `bd close --db`. bv is installed. No node_modules. Only bd hooks are present. The only worktree is main.
9. `ralph-tui template show --tracker json | grep ...; npm run typecheck/lint/test; ls tsconfig.json eslint.config.js package-lock.json`: the json template has the same no-commit rule. All three gates fail (tsc/eslint/vitest not found). No tsconfig, eslint config or lockfile.
10. `claude --version; codex --version; grep ~/.claude/settings.json; grep ~/.codex/config.toml; git config core.hooksPath; ls .github; ralph-tui run --help | grep`: Claude Code 2.1.302, codex 0.160.1. User claude settings: model opus, effortLevel xhigh, per-model modelSettings. Codex: gpt-6.1-sol, medium. hooksPath is .beads/hooks. No .github. Run flags confirmed: --epic, --prd, --tracker, --agent, --model, --iterations, --headless.
11. `mkdir -p .../outputs; git status --porcelain | wc -l`: created the outputs dir. The project tree is still clean (0).

## Files created/modified
- Created `/home/lmarqs/Work/skills/workspaces/ralph-tui-run/iteration-2/eval-4-both-sources-ambiguous/old_skill/run-1/outputs/response.md`
- Created `/home/lmarqs/Work/skills/workspaces/ralph-tui-run/iteration-2/eval-4-both-sources-ambiguous/old_skill/run-1/outputs/actions.md`
- No project files changed. ralph-tui was not started.
