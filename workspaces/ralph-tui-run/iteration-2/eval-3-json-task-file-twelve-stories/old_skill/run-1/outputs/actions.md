# Actions

## Commands (in order)
1. `cat SKILL.md; ls references/` (skill snapshot): read the skill. It coordinates a beads epic only. If no beads epic is reachable, it stops and points to `ralph-tui-create-beads`.
2. `cat harness-options.md observed-behavior.md`: read the references (ralph-tui 0.12.0 / beads 1.3.1 observations).
3. `find . -type f; git status; git log; git remote -v; git branch -a` (project): found the files package.json, CLAUDE.md, src/index.ts and tasks/prd.json. The tree is clean on `main` at a178f11. There is no remote and `main` is the only branch.
4. `cat package.json CLAUDE.md src/index.ts tasks/prd.json; ls -la; cat .gitignore; ls .ralph-tui .beads .claude`: found the gates (typecheck/lint/test), the `feat/<topic>` branches and Conventional Commits rules, and "never commit to main". `prd.json` has 12 stories in a strict linear chain, and every story's first criterion is "<title> works". `branchName` is `ralph/billing-export`. There is no .gitignore, .ralph-tui, .beads or .claude. `package.json` has no dependencies and there is no node_modules.
5. `which ralph-tui bd; ralph-tui --version; bd --version; bd list; ralph-tui status`: ralph-tui 0.12.0 and bd 1.3.1 are installed. `bd list` returned "no beads database found". `ralph-tui status` returned "No session found".
6. `ralph-tui plugins trackers; git status --short`: ralph-tui has the built-in trackers json, beads and beads-bv. The tree is still clean.

## Files created or modified
- In the project: none.
- Outputs: `response.md` and `actions.md` in this outputs directory.
