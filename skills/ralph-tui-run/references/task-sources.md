# Task sources

The skill runs ralph-tui on one of two task sources: a beads epic (trackers `beads` and `beads-bv`) or a JSON task file (tracker `json`, usually `prd.json`). The workflow is the same; this table lists where they differ. [observed-behavior.md](observed-behavior.md) has the evidence for each json entry.

## Picking the source

1. The project's ralph-tui config names a `tracker`: use it.
2. Otherwise the user's words decide: an epic id means beads, a `.json` path means json.
3. Otherwise use what exists: `.beads/` with an open epic, or a JSON file whose root has `name` and `userStories` (look in `tasks/` and the repo root first).
4. Both exist and nothing above decides: ask.

Other trackers (`beads-rust`, `beads-rust-bv`, `linear`, `jira`) are not covered. If the config selects one, say so and stop.

## Differences

| Concern | Beads epic | JSON task file |
|---|---|---|
| Unit | bead | story |
| Read | `bd` config, open epics, child beads with acceptance criteria and blockers | the file: `name`, `branchName`, each story's `acceptanceCriteria`, `priority`, `dependsOn`, `passes` |
| Order | dependency tree (`bd`) | `passes: false` stories whose `dependsOn` all pass, lowest `priority` first, then file order |
| Already done | closed beads | stories with `passes: true` |
| Nothing to run | point to `ralph-tui-create-beads` | point to `ralph-tui-create-json` |
| Prompt check | the close step works with this database (see observed-behavior.md) | no close step; the engine marks the story |
| Worktree | the project's launcher or convention, else `bd worktree create`; check with `bd list` inside it | the project's launcher or convention, else `git worktree add`; the file appears there only if it is committed; check it exists inside it |
| Start | `--epic <id>` with the configured beads tracker | `--prd <absolute path>`; a relative path resolves against where ralph-tui starts, and without a path it opens an interactive picker |
| Progress | beads closed of total, from `bd` and `ralph-tui status` | stories passing of total, from the file and `ralph-tui status` |
| Engine writes | bead status in the beads database | the task file itself, at each story's start and completion |
| Auto-commit on | one commit per bead, message type from the bead type | one commit per story, `story: <id> <title>` by default, carrying that story's `passes` change; only if the file is inside the run directory and not ignored |
| Auto-commit off | tracked files untouched by the engine | the task file is left modified after the run |
| Branch | the project's convention | the project's convention; `branchName` in the file is a hint, ralph-tui never checks it out |
| You must not | close a bead | set `passes`, or edit the file while ralph-tui runs |
