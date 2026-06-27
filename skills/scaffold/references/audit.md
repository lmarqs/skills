# Brownfield audit — detect drift, report, fix on approval

When the directory already has code, do **not** generate blindly. Audit what's there against the standard,
show the user a drift report, and apply fixes only after they approve — existing work is never overwritten
silently.

## Procedure

1. **Inventory.** Read any existing `mise.toml`, list `.mise/tasks/**`, and detect toolchains from the repo
   (`go.mod`, `package.json`, `*.tf`, `platformio.ini`, `compose.y*ml`, `requirements.txt`). Note the env
   file already in use and keep its format.

2. **Check against the standard** (each is a recommendation — report it, explain the cost, let the user
   decide whether to fix):

   | Check | Drift looks like | Why it matters |
   |-------|------------------|----------------|
   | Lean `mise.toml` | inline `[tasks]` in the toml | tasks belong in `.mise/tasks/` so they carry `#USAGE`/`dir` and stay greppable |
   | Task contract | files missing `#MISE description`, `set -e`, or the shebang | undiscoverable in `mise tasks`; silent failures pass CI |
   | Namespacing | flat names in a polyglot repo, or inconsistent separators | clashes; no `**:` fan-out |
   | Pinned tools | unpinned/floating `[tools]` | non-reproducible environments |
   | No leaked internals | hard-coded account ids/domains/regions in task scripts | leaks identifiers; ties tasks to one account |
   | House-rules skill | no project "mise" skill present | agents drift back to ad-hoc `cd && cmd` |
   | Command-skills | none for destructive tasks like `tf:apply` | no guardrails on state-changing operations |

3. **Report.** Present a concise table: each check, pass/drift, and the *recommended* fix with its tradeoff.
   Rank nothing as mandatory — these are recommendations.

4. **Propose patches.** For each drift the user wants fixed, show the exact diff (new file, or edit). Adding
   missing tasks/headers and generating the house-rules skill are low-risk; converting env format or
   re-namespacing existing tasks is higher-risk — flag those and default to leaving them.

5. **Apply on approval.** Write only the approved changes. Never touch `package.json`, lockfiles, source, or
   an existing env file's contents. Then run `mise tasks` to confirm everything still parses.

## Bias

Prefer the smallest change that closes the most important gaps — usually: add the house-rules skill, add the
core tasks that are missing, and fix task headers. Leave working conventions alone unless the user asks.
