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
| [`architecture-decision-doc`](skills/architecture-decision-doc/SKILL.md) | Writes a structured architecture decision document — a pragmatic blend of RFC and ADR — recording *why* a non-trivial technical choice was made. Six-part method: contextualize, requirements, design (with diagrams), tradeoff analysis (pros/cons/risks, each risk with impact·probability·mitigation·contingency), the decision, then conclude & communicate. Matches the request's language. | You're choosing between technical options or documenting a decision ("write an RFC", "design doc", "documento de arquitetura", "decisão arquitetural", "ADR", "tradeoff analysis", "documentação técnica da implementação") — including the retrospective case of documenting an implementation after the fact. |

## Adding a skill

Each skill lives at `skills/<name>/SKILL.md` with optional `references/` for
progressive-disclosure detail. Skills are authored and eval'd with the
[`skill-creator`](https://github.com/anthropics/skills) tool vendored under
`.agents/skills/` (pinned in `skills-lock.json`). See [CLAUDE.md](CLAUDE.md) for
the contributor guide.

## License

[MIT](LICENSE)
