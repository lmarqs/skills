# lmarqs/skills

A small, sharable collection of agent skills.

## Install

```bash
npx skills@latest add lmarqs/skills
```

## Skills

| Skill | What it does | Triggers when… |
|-------|--------------|----------------|
| [`hexagonal-layout`](skills/hexagonal-layout/SKILL.md) | Keeps a system's business logic independent of its technology by reasoning about which way dependencies point. Three kinds of code — the reason it exists, its connections to the outside, and how it's run (core · adapters · run). Language- and framework-agnostic. | You add a feature, an external integration, or an entrypoint — or a dependency points the wrong way and you're unsure where a responsibility belongs ("where should this go", "wire it up", "which layer owns this"). |

## Adding a skill

Each skill lives at `skills/<name>/SKILL.md` with optional `references/` for
progressive-disclosure detail. Skills are authored and eval'd with the
[`skill-creator`](https://github.com/anthropics/skills) tool vendored under
`.agents/skills/` (pinned in `skills-lock.json`). See [CLAUDE.md](CLAUDE.md) for
the contributor guide.

## License

[MIT](LICENSE)
