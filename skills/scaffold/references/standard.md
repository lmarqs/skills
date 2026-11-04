# The standard — conventions and their tradeoffs

These are the **recommended defaults**. Each is a strong recommendation with a stated cost, not a rule.
Present the recommendation, name the tradeoff, default to it, let the user choose. Record the choices —
they parameterize every template.

## The advisory forks

### Namespacing — *recommended: namespace by toolchain*

`.mise/tasks/<toolchain>/<task>` so the name is `toolchain:task` (`node:setup`, `tf:apply`). The namespaces
fall out of which toolchains the user picked, so this is rarely a separate question.

- **Pro:** uniform across every repo; `mise run '**:setup'` fans a step across all modules; no collisions.
- **Con / when to deviate:** a single-toolchain repo (e.g. one Go binary) reads fine with *flat* names
  (`build`, `test`, `fmt`). Offer flat when there's exactly one toolchain and the user prefers brevity.
- **Risk of flat in a polyglot repo:** name clashes (`test` for which stack?) and no `**:` fan-out.

### Env file — *recommended: `.env.yaml`*

mise auto-loads it via `_.file`. Structured YAML reads better for the handful of vars tasks need.

- **Pro:** nests cleanly, comments allowed, matches the house default.
- **Con / when to deviate:** plain `.env` (`KEY=value`) is more universal and what many tools expect; pick it
  if the project already uses `.env` or the user prefers it.
- **Brownfield:** detect and keep whatever already exists — don't convert it.

### Version pinning — *recommended: major.minor, resolved now*

Resolve the current release at scaffold time and pin `major.minor` (`node = "24"`, `terraform = "1.13"`).

- **Pro:** stable enough for a team, still picks up patches.
- **Con / alternatives:** *exact patch* (`node = "24.21.0"`) for byte-identical environments at the cost of
  noisy bumps; *major only* (loosest) if the user wants mise to float.

### Account-specific internals — *recommended: parameterize via env*

Tasks reference `${AWS_ACCOUNT_ID}`, `${CODEARTIFACT_DOMAIN}`, `${AWS_REGION}`, etc., sourced from the env
file; real values live there (and the env file is gitignored), never in task scripts.

- **Pro:** no internal identifiers committed; the same task works in any account.
- **Risk of hard-coding:** leaks account ids/domains (severe for public repos) and pins the task to one env.

### Agent-asset destination — *recommended: `.claude/`*

Generate the house-rules skill into `.claude/skills/` and command-skills into `.claude/commands/` so Claude
Code picks them up immediately.

- **Pro:** works out of the box.
- **Alternative:** teams that treat `.agents/` as the source of truth (and sync to `.claude/`) should target
  `.agents/skills` + `.agents/commands` instead. Ask if you see an existing `.agents/` tree.

## `mise.toml` skeleton

Lean by design — tools, env, settings, and **no inline tasks** (tasks are files under `.mise/tasks/`).
Include only the `[tools]` the user selected; include the `idiomatic_version_file_enable_tools` entries only
for node/python when those are selected.

```toml
[settings]
experimental = true
# Read node/python versions from .node-version/.python-version when those toolchains are used:
idiomatic_version_file_enable_tools = ["node", "python"]

[tools]
# Pinned major.minor, resolved at scaffold time. Only the selected toolchains appear here. Examples:
# node       = "24"
# python     = "3.13"
# go         = "1.25"
# terraform  = "1.13"
# aws-cli    = "2"
# pnpm       = "10.16"

[env]
_.file = ".env.yaml"                              # or ".env"
_.python.venv = { path = ".venv", create = true } # only when python is selected
```

## File layout produced

```
mise.toml
.env.yaml                 # or .env  (gitignored; commit a .env.example)
.node-version             # if node selected
.python-version           # if python selected
.mise/tasks/
  aws-auth                # sourced helper (not runnable) — only if AWS is involved
  <toolchain>/<task>      # one executable bash file per task
.claude/                  # or .agents/
  skills/<project>-mise/SKILL.md       # the house-rules skill (always)
  commands/<task>/SKILL.md             # only for destructive/multi-step tasks
```
