# Iteration 1 analysis

Seven evals, two configurations, one run each. `with_skill` is the rewritten skill on this branch;
`old_skill` is `skills/architecture-design` as it stands on `main`, pinned at
`workspaces/architecture-design/skill-snapshot/`.

## Result

The rewrite is behind the version it replaces: **77.8% against 81.1%** mean pass rate.

| Eval | with_skill | old_skill |
| --- | --- | --- |
| 0 rfc-rate-limiting | **13/14** | 11/14 |
| 1 rfc-message-queue | **11/14** | 10/14 |
| 2 tech-doc-retrospective | 8/10 | **9/10** |
| 3 rfc-constraint-laden-input | 3/10 | **4/10** |
| 4 rfc-evidence-in-context | 8/8 | 8/8 |
| 5 rfc-requirements-are-all-solutions | 6/8 | **7/8** |
| 6 rfc-framing-challenge | 7/8 | **8/8** |

Wall clock and tokens are effectively tied: 252.9 s and 84.0k tokens for the new skill against
239.7 s and 82.2k for the old, well inside the run-to-run spread of a single run per cell.

## Finding 1: the constraints concept backfires

The headline feature of the rewrite made things worse on the eval built to test it.

On eval 3, the input was six items of which four are constraints. The `with_skill` run recorded Kafka
and AWS as givens and then wrote "Kafka and AWS are given, so they are not re-analyzed here" and "this
RFC does not evaluate alternatives to Kafka". Its tradeoff table covers ingestion pattern, audit store
and schema management, and no alternative to the two technologies the user was told to accept. On
eval 6 the same shape appeared: the run declared "only one dimension is actually open in this RFC" and
moved "optimize the existing Python service" into an out-of-scope note instead of pricing it in the
table. The `old_skill` runs, which have no concept of a constraint at all, kept more of the option
space in the analysis on both evals.

The rule the skill states is the opposite of what the runs did: "a constraint never pre-selects an
alternative: an option that violates one stays in the analysis, with the violation recorded as a cost".
That clause sits in step 1, surrounded by "imposed from outside this decision", "true from the start
rather than proved at the end", and a table whose columns invite the reader to file each given away and
move on. Naming the bucket gave the model somewhere to put the things it would rather not argue about.

What to change:

- Move the rule into step 4 as a condition on the table's contents, not a remark in step 1: the
  tradeoff table must contain, for every constraint the user imposed, at least one option that
  violates it, with the cost of challenging it in the row.
- Add a column to the constraints table that forces the alternative to be named, so the table cannot
  be filled without having thought of one.
- Reword step 1 so the operative sentence is about challengeability, not about provenance.
- Say explicitly that "out of scope" applies to problems, never to options: an option is rejected in
  the tradeoff analysis or not at all.

## Finding 2: the requirement rules fire inconsistently

The goal, metric and proof rules landed on eval 0 and missed elsewhere.

- eval 0 `with_skill`: 13/14, and the one failure is an honest one, a cost requirement it could not
  quantify.
- eval 1 `with_skill`: failed all three of the goal, metric and proof assertions, which are exactly
  the three the `old_skill` run failed. On that eval the rewrite changed nothing.
- eval 5 `with_skill`: named a proof on 1 of 8 requirements.

So the rules are not wrong, they are not reaching the output. Two plausible causes, both worth acting
on: the body is 457 lines of prose and the rules compete with everything else in it, and the forcing
structure that would make them unavoidable, the ID-keyed tables with a Proof column, lives in
`assets/template.md`, which most runs never opened. Candidate fixes: put the requirement table
skeleton in the body of the skill rather than only in the template, and make the closing checklist the
last instruction rather than one section among many.

## Finding 3: two evals do not discriminate, and one was graded inconsistently

- **eval 4** is 8/8 on both sides. The prompt says "I think reporting is maybe 40% of our database load
  but honestly I'm not sure, nobody has measured it", which hands the model the label the eval was
  supposed to test it for supplying. Rewrite the prompt so the uncertainty is undeclared: state the
  40% as flat fact and see whether the document asks where it came from.
- **eval 6** `old_skill` also scored 8/8, so the framing-challenge assertions do not separate the two
  versions either. The old skill's "generate real alternatives" instruction already covers most of it.
- **eval 2** was graded by two graders who applied opposite standards to identical section shapes: both
  documents left "lessons learned" as a header, a refusal to fabricate, and a list of open questions,
  and one grader passed it while the other failed it. A single judge re-scored two assertions across
  both runs. The verdicts swapped but the totals did not change, so eval 2's direction is real: the
  `old_skill` document expands "dead-letter queue" at first use and the `with_skill` one never expands
  DLQ at all.

Assertion-level notes from the graders worth folding into the eval set: the four-risk-attribute
assertion passes on structural presence, so a row reading Probability "Unknown" and Contingency "None
practical" satisfies it; the lessons-learned assertion needs to require at least one lesson; eval 5's
assertions 3 and 7 pull against each other, since refusing to invent an unverifiable numeric target
fails assertion 3 while satisfying assertion 7.

## Method caveats

- One run per cell. With pass rates in the 0.3 to 1.0 range and a single sample, per-eval differences
  of one assertion are noise; only the repeated pattern across evals 3, 5 and 6 is load-bearing.
- No execution transcripts were captured, so grading used the output files alone. Assertions about what
  the model verified rather than what it wrote could not be checked.
- Every run inherited the accuracy rules in the user's global `CLAUDE.md`, which pushed both
  configurations toward labelling unverified claims. That compresses the difference the evidence rules
  were meant to create, most visibly on eval 4. It affects both configurations equally, so the
  comparison holds, but the absolute numbers understate what the evidence rules do for a user without
  those global rules.
- One grader quoted `references/context-and-requirements.md`, a file that exists only in the new skill,
  while grading an `old_skill` run. It used it as a rubric rather than as evidence about the document,
  and its verdict is supported by quotes from the document itself, but the leak is recorded here.
