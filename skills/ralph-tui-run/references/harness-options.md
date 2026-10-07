# Harness options

Snapshot from Claude Code 2.1.292 and codex-cli 0.160.1. The refresh commands are the source of truth; run them in step 1 and prefer their output when it differs from this file.

## Claude Code

Refresh: `claude --help` (`--model`, `--effort`). Set effort for a run with `CLAUDE_CODE_EFFORT_LEVEL`.

| Alias | Resolves to | Pick for |
|---|---|---|
| `haiku` | `claude-haiku-5-5` | Fastest and cheapest. Mechanical beads that quality gates fully check. |
| `sonnet` | `claude-sonnet-5-5` | Fast, balanced. Small, well-specified beads that follow a known pattern. |
| `opus` | `claude-opus-5-5` | Strong reasoning. Beads touching several files or needing design judgment. |
| `fable` | `claude-fable-5-1` | Most capable, slowest, costliest. Work where a wrong decision is expensive to undo. |

Effort: `low`, `medium`, `high`, `xhigh`, `max`.

## Codex

Refresh: `codex debug models`. Offer only models with `"visibility": "list"`; each model's `supported_reasoning_levels` is its valid effort set. Set effort with `model_reasoning_effort` in `<dir>/.codex/config.toml`.

| Model | Pick for | Effort |
|---|---|---|
| `gpt-6-astra` | Most capable, slowest. Tasks that need the strongest capability across steps and tools. | `low` to `max`, `ultra` |
| `gpt-6.1-sol` | Near-Astra results at lower cost. The default choice for feature work when cost matters. | `low` to `max`, `ultra` |
| `gpt-6-luna` | Fastest, lowest cost. Focused, high-volume beads where a good result is well defined. | `low` to `max` |

Older models still listed (`gpt-6-sol`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`) only when the project pins one.

OpenAI documents `ultra` as available to subagents only. ralph-tui runs each bead as a top-level `codex exec`, so `ultra` likely does not apply; treat `max` as the ceiling unless the refresh shows otherwise. Available levels also vary by ChatGPT plan.

## Effort, both harnesses

- **Low end:** quick, little deliberation per bead. Mechanical beads where gates catch mistakes.
- **Middle:** the usual choice for feature work.
- **High end:** slower and more tokens per iteration. Ambiguous or cross-cutting beads, or an epic that needed rework on a previous run.
