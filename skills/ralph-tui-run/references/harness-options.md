# Harness options

Snapshot from Claude Code 2.1.292 and codex-cli 0.160.1, for the two harnesses this skill was written for. The refresh commands are the source of truth; prefer their output when it differs from this file.

## Claude Code

Refresh: `claude --help` (`--model`, `--effort`).

| Alias | Resolves to | Pick for |
|---|---|---|
| `haiku` | `claude-haiku-5-5` | Fastest and cheapest. Mechanical beads that quality gates fully check. |
| `sonnet` | `claude-sonnet-5-5` | Fast, balanced. Small, well-specified beads that follow a known pattern. |
| `opus` | `claude-opus-5-5` | Strong reasoning. Beads touching several files or needing design judgment. |
| `fable` | `claude-fable-5-1` | Most capable, slowest, costliest. Work where a wrong decision is expensive to undo. |

Effort: `low`, `medium`, `high`, `xhigh`, `max`.

## Codex

Refresh: `codex debug models`. Offer only models with `"visibility": "list"`; each model's `supported_reasoning_levels` is its valid effort set.

| Model | Pick for | Effort |
|---|---|---|
| `gpt-6-astra` | Most capable, slowest. Tasks that need the strongest capability across steps and tools. | `low` to `max`, `ultra` |
| `gpt-6.1-sol` | Near-Astra results at lower cost. The default choice for feature work when cost matters. | `low` to `max`, `ultra` |
| `gpt-6-luna` | Fastest, lowest cost. Focused, high-volume beads where a good result is well defined. | `low` to `max` |

Older models still listed (`gpt-6-sol`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`) only when the project pins one.

OpenAI's models guide documents `ultra` as available to subagents only, and available levels vary by ChatGPT plan. Whether `ultra` applies to a ralph-tui bead was not tested.

## Effort, both harnesses

- **Low end:** quick, little deliberation per bead. Mechanical beads where gates catch mistakes.
- **Middle:** the usual choice for feature work.
- **High end:** slower and more tokens per iteration. Ambiguous or cross-cutting beads, or an epic that needed rework on a previous run.
