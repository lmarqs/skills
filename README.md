# lmarqs/skills

[![skills.sh](https://skills.sh/b/lmarqs/skills)](https://skills.sh/lmarqs/skills)

A small, sharable collection of agent skills.

## Install

```bash
npx skills@latest add lmarqs/skills
```

## Skills

| Skill | What it does | Triggers when… |
|-------|--------------|----------------|
| [`hexagonal-layout`](skills/hexagonal-layout/SKILL.md) | Keeps a system's business logic independent of its technology by reasoning about which way dependencies point. Three kinds of code — the reason it exists, its connections to the outside, and how it's run (core · adapters · run). Language- and framework-agnostic. | You scaffold a new system, place a feature/integration/entrypoint, review how an existing one is shaped, or write a layout ADR — or a dependency points the wrong way and you're unsure where something belongs ("where should this go", "scaffold it ports-and-adapters", "review against hexagonal principles", "which layer owns this"). |
| [`architecture-design`](skills/architecture-design/SKILL.md) | Writes a structured architecture decision document — a pragmatic blend of RFC and ADR — recording *why* a non-trivial technical choice was made. Six-part method: contextualize, requirements, design (with diagrams), tradeoff analysis (pros/cons/risks, each risk with impact·probability·mitigation·contingency), the decision, then conclude & communicate. Matches the request's language. | You're choosing between technical options or documenting a decision ("write an RFC", "design doc", "architecture decision", "ADR", "tradeoff analysis", "technical documentation of an implementation") — including the retrospective case of documenting an implementation after the fact. |
| [`sql-quality-check`](skills/sql-quality-check/SKILL.md) | Audits SQL quality systematically — catches performance smells in raw SQL, ORM-generated queries, schema decisions, migrations, or PR diffs, explains the database-level impact, gives a corrected version, and makes the tradeoff explicit. Generic: no project/domain/ORM/language config; raises context (transactional table? intentional scan? expected volume?) during analysis. | You write, review, or optimize a query or data-access code ("review this query", "why is this slow", "check my migration", "is this index right") — or you spot N+1, `SELECT *`, a cartesian/row explosion, a missing date filter, OFFSET pagination, `LIKE '%term%'`, `NOT IN` with nulls, an unindexed sort, or a long transaction. |

## Adding a skill

Each skill lives at `skills/<name>/SKILL.md` with optional `references/` for
progressive-disclosure detail. Skills are authored and eval'd with the
[`skill-creator`](https://github.com/anthropics/skills) tool vendored under
`.agents/skills/` (pinned in `skills-lock.json`). See [CLAUDE.md](CLAUDE.md) for
the contributor guide.

## License

[MIT](LICENSE)
