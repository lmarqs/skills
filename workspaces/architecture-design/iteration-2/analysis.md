# Iteration 2 analysis

Eleven evals, two configurations, one run each. `with_skill` is the rebuilt skill on this branch;
`old_skill` is `skills/architecture-design` as it stands on `main`. The baseline copy is not tracked in
git: materialize it when an iteration runs with
`git archive main skills/architecture-design | tar -x -C <scratch>/skill-snapshot --strip-components=2`
(the path `workspaces/*/skill-snapshot/` is ignored).

Each eval was graded by one judge holding both runs, rather than one judge per run. Iteration 1 produced
two graders who applied opposite standards to identical section shapes on eval 2, and one grader who used
a reference file that exists only in the new skill as a rubric. Graders here were told to read no skill
definition and to re-read any assertion whose two verdicts differed before writing.

## Result

The rebuild is ahead of the version it replaces: **96.1% against 68.6%** (98 and 70 of 102 assertions).
Iteration 1 was 77.8% against 81.1%.

| Eval | with_skill | old_skill |
| --- | --- | --- |
| 0 rfc-rate-limiting | **13/14** | 10/14 |
| 1 rfc-message-queue | **14/14** | 10/14 |
| 2 tech-doc-retrospective | 8/10 | 8/10 |
| 3 rfc-constraint-laden-input | **10/10** | 6/10 |
| 4 rfc-evidence-in-context | **8/8** | 7/8 |
| 5 rfc-requirements-are-all-solutions | **8/8** | 6/8 |
| 6 rfc-framing-challenge | 7/8 | 7/8 |
| 7 rfc-regulation-vs-platform-decision | **8/8** | 5/8 |
| 8 rfc-departments-to-usage-roles | **8/8** | 4/8 |
| 9 rfc-embedded-diagrams | **7/7** | 5/7 |
| 10 rfc-hidden-shared-decision-open-question | **7/7** | 2/7 |

The new skill wins nine evals and ties two. It costs 140.9k tokens and 695 s per run against 93.8k and
469 s, about 1.5x on both, and the gap holds on every eval rather than coming from outliers. That is the
price of four reference files and a wider option space, and it is the main argument against the rebuild.

## Finding 1: the constraints concept now works

Eval 3 was iteration 1's worst result, 3/10 against the baseline's 4/10, because naming a bucket called
"constraint" gave the model somewhere to file the things it would rather not argue about. It is now
10/10 against 6/10, and each of the four fixes is visible in the output:

- the prior-decisions table carries populated *source* and *cost to reverse* columns on all four of the
  user's givens ("Platform team"; "Low: a team practice, changeable in a pull request");
- two non-Kafka transports have rows in the tradeoff table with the conflict priced as a con plus a risk
  row, rather than being excluded before analysis;
- "out of scope" is applied to problems, and the browsing-UI wish became a pro and a launch phase.

The baseline fails the same four assertions the rewrite used to fail. It promotes the company API
standard into the requirements as N5, attributes only Kafka to a decider, gives the coverage gate no
reversal cost, and scopes its transport dimension to "Kafka flavour", discussing the no-broker option in
prose outside the table. Eval 7 shows the same pattern on a harder input: both runs separate the
regulation from the platform team's 2025 standard, but the baseline never writes the word "goal" at all.

## Finding 2: the requirement rules now reach the output

Iteration 1's finding 2 was that the goal, metric and proof rules landed on eval 0 and missed elsewhere,
because they lived in prose competing with 457 lines and the forcing tables lived in
`assets/template.md`, which most runs never opened. Moving the table skeletons into the body worked.
Requirement rigour is now the single largest source of the gap, and it is where nine of the eleven wins
come from:

- eval 1: the three assertions the rewrite failed in iteration 1 (goal, metric, proof) all pass, and the
  eval goes 11/14 to 14/14;
- eval 5: goal and proof columns filled on all seven requirements, against a baseline with no goals
  section and four of ten requirements stating no proof;
- eval 8: six distinct Given/When/Then scenarios as proofs, against eight bare prose bullets;
- eval 0: populated Goal, Source and Proof on all ten entries and a number with a unit on all five
  non-functional targets, against five of seven adjectival.

## Finding 3: what the new skill lost

Eval 2 is a tie, and inside the tie is a regression the assertions do not see. The baseline document
carries a maintainer operations section (triage order for a notification that was not sent, dead-letter
redrive, archive replay, adding a channel), a requirement-to-component traceability check, and a
concrete event-envelope contract. The new document has none of the three, and the prompt's stated purpose
was that new maintainers could understand and maintain the service. The retrospective shape gained
sizing, roles and evidence labels and lost the operational content that makes a retrospective document
useful. Step 6 should require, for a document about something already running, the procedures a
maintainer needs, and `example-technical-doc.md` should model one.

## Finding 4: two documents overclaimed their own evidence discipline

The skill taught the claim without making it true.

- eval 3 `with_skill` states "every figure below is labeled *assumed*" while its roadmap estimates and
  alarm thresholds are not.
- eval 9 `with_skill`'s reply says "no product is named" while its ER diagram declares `bytea`, `jsonb`
  and `timestamptz` columns.

Both are self-refuting sentences of exactly the kind the evidence rule exists to prevent. The fix is not
another rule but removing the invitation: a document should label its claims and not announce that it
has. Worth adding to the closing checklist as a check that no summary sentence asserts a property of the
document itself.

## Finding 5: vendor neutrality had leaked into the output

Found while reviewing this iteration, not by an assertion. The skill's own files name no internal tooling
because they ship in a public repository; four places stated that as a writing rule, so produced
documents inherited it and referred to instruments generically. `assets/template.md` was the worst,
since the line sat inside the skeleton the model copies. A reader who cannot tell which dashboard a
number came from cannot check it, which defeats the evidence rule the same files argue for. Fixed: the
Evidence rule now asks for the instrument and the date as the reader knows them, product name included,
and both worked examples say their instruments are generic only because the file is public.

The requirement-versus-solution test that also mentions product names is a different and valid rule and
was left alone: a requirement that can only be written with a product name in it is a solution, which
says nothing about whether the Design or the tradeoff table may name one.

## The eval set needs work more than the skill does

Of 102 assertions, 69 passed on both configurations and 4 failed on both, so **29 carried the entire
signal**. Concrete changes, each from a grader that saw the outputs:

- **Split the four-attribute risk assertion** (evals 0, 1, 6). It fails both configurations while hiding
  a large gap: the baseline has rows whose four attributes are all em-dashes and not one of 22 rows
  carries a reason, while the new skill reasons all but a handful. As one assertion it reports a tie.
- **Reword eval 2's lessons-learned assertion.** As written it cannot be satisfied without fabrication:
  the prompt supplies one paragraph and no team access, and both runs kept the section while honestly
  disclaiming the provenance. Require a lesson attributable to the architecture as built, or supply the
  team's lessons in the prompt.
- **Fix eval 4's assertion 5.** It is ambiguous between "each claim has provenance somewhere" and "every
  mention is hedged", and that ambiguity sits exactly on the axis where the two documents diverge: the
  baseline labels the 40% figure in an evidence table and then re-asserts it as fact in the prose that
  carries the argument.
- **Add an evidence-quality assertion to eval 6.** Six of its eight assertions are satisfied by any
  document that reframes the question at all. The real difference was that the new skill grounded its
  challenge in a checkable external benchmark and a licence fact while the baseline argued from a generic
  cause taxonomy and picked on a self-labelled inference. Nothing measures that.
- **Add a factual-correctness axis.** On eval 1 the two documents state contradictory SQS payload limits
  (256 KiB and 1 MiB), each asserted confidently, and no assertion covers whether a vendor claim is
  right. This is the highest-value gap in the set: the documents are persuasive either way.
- **Eval 9's vendor-neutrality assertion is retired**, not reworded. It tested a property of the skill's
  own files rather than of a produced document. Its verdict was removed from both graded runs, which cost
  each side one pass and changed no direction.
- Eval 2 and eval 6 do not discriminate at all as they stand. Eval 4 discriminates by one assertion on a
  strict reading. Consider retiring eval 6 or rebuilding it around evidence quality.

## Method caveats

- One run per cell. Per-eval differences of one assertion are noise; the load-bearing claim is the
  direction across nine evals, and the 28-point aggregate gap is far outside what one run per cell could
  manufacture.
- No execution transcripts were captured, so grading used the output files alone. Assertions about what a
  run verified rather than what it wrote could not be checked, and the graders were told to fail those.
- Every run inherited the accuracy rules in the user's global `CLAUDE.md`, which push both configurations
  toward labelling unverified claims. That compresses the difference the evidence rules create, most
  visibly on eval 4. It affects both configurations equally, so the comparison holds, but the absolute
  numbers understate what the evidence rules do for a user without those rules.
- The aggregator reads `tokens` from `timing.json` only when `grading.json` carries no timing block. Our
  graders copied timing into `grading.json`, so the token column silently reported output *characters*
  until it was repaired from the timing files. Anyone re-running `aggregate_benchmark` here must repair
  it again or drop the timing block from the grading files.
