# Iteration 3 analysis

Two evals, two configurations, one run each. They test the repository-record rule from issue #8:
eval 11 seeds a repository with Nygard-format records and an accepted decision; eval 12 seeds a record
format with no status field and a proposed decision. `with_skill` is the skill on this branch before
commit `8883d4d`; `old_skill` is `skills/architecture-design` as it stands on `main`, materialized with
`git archive main skills/architecture-design | tar -x -C skill-snapshot --strip-components=2` (ignored
by git). The fixture repositories come from `inputs/make-*-records-project.sh`.

Each eval was graded by one judge holding both runs, told to read no skill definition, as in
iteration 2.

## Result

**11 of 13 assertions against 9 of 13** (with skill, old skill).

| Eval | With skill | Old skill |
| --- | --- | --- |
| 11 rfc-writes-nygard-record | 7 / 9 | 5 / 9 |
| 12 rfc-proposed-no-status-record-format | 4 / 4 | 4 / 4 |

Cost is level: 132.6k against 134.6k tokens and 280 s against 339 s per run.

## Eval 11: what separates the runs

Both runs found `docs/adrs/`, wrote record 0003 in Nygard's four sections, titled it with the decision,
matched the document's status and left record 0002 alone. The old skill does this unprompted when the
user asks for the decision to be "on record", so assertions 1 to 3, 8 and 9 do not discriminate.

The difference is what goes inside the record. The new skill's record is four plain sections, with
"Drivers, in order:" in Context and each rejected option in one sentence under Decision. The old
skill's record is 4.5 KB: an "Options considered:" list inside Context, the implementation, rollout and
rollback inside Decision, and a "Confirmation:" plan inside Consequences. It keeps Nygard's headings and
carries the full document's sections under them (assertion 4, failed on a strict reading), has no
ranked drivers (assertion 5), and never mentions the full document (assertion 7).

Two failures are the new skill's own:

- **Assertion 6, rejected options.** The record dropped three options the tradeoff table rejects
  (hosted identity provider, back to one instance, a database table) and gave "do nothing" no line on
  what it offers. `references/repository-record.md` already asks for one line per row of the tradeoff
  table, baseline included; the run did not follow it.
- **Assertion 7, the link.** No issue or pull request exists in the eval environment, so there was no
  URL to link. The run named the carrier ("carried in the pull request that adds this record") and
  listed the link as a task, which is the right move, but the skill did not say so. Commit `8883d4d`
  adds that rule; these runs predate it.

## Eval 12: does not discriminate

Both runs kept the decision proposed with legal as the blocking owner, wrote no record, and listed
writing it as a task once accepted. The old skill reads the repository's README and obeys its rule
that records are written only for decisions taken. The new skill names the record's file name and
template path; the old one adds a second blocking question (where the hosts run). Neither difference is
scored. The judge also found one overstatement in the with-skill reply: it says ADR 0001 shows hosts
"are replaced routinely", which ADR 0001 does not say.

## Changes for the next iteration

From the judges' `eval_feedback`, not applied here because the runs above were graded against the
current wording:

- Eval 11, assertion 4: say that no Options, Requirements or Confirmation block appears under any
  heading, not only as a heading.
- Eval 11, assertion 7: give the prompt an issue URL that carries the RFC, so linking is possible;
  without one, the assertion tests the environment.
- Eval 11: add an assertion that the record stays about one page.
- Eval 12, assertion 3: require the record task to name the template's sections or the
  `NNNN-<slug>.md` pattern, so a vague "write an ADR later" does not pass.
- Eval 12 needs a case the old skill gets wrong, such as a repository whose README does not state the
  rule and only the template's missing status field implies it.

## Caveats

- One run per configuration and two evals; the 11-to-9 gap is two assertions on one eval.
- `aggregate_benchmark` hardcodes "3 runs" and reads tokens as output characters when `grading.json`
  has a timing block. Both were repaired by hand from the `timing.json` files. Its deltas are old skill
  minus with skill.
- The `reply.md` files are the agents' final replies verbatim, with absolute scratch paths shortened to
  paths relative to `outputs/`.
- Every run inherited the user's global `CLAUDE.md`, as in iteration 2.
