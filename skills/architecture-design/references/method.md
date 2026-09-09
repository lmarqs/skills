# The method, and why it is shaped this way

`SKILL.md` gives the steps and the tables to fill. This file gives the reasoning behind them, so that
when a situation does not fit the tables you can reason from the same ground instead of guessing. Read
it once; then work from `SKILL.md`.

## Contents

1. [What the document is for](#what-the-document-is-for)
2. [Be the architect, not the scribe](#be-the-architect-not-the-scribe)
3. [Sharpen the axe first](#sharpen-the-axe-first)
4. [Why the steps gate each other](#why-the-steps-gate-each-other)
5. [Sizing the decision](#sizing-the-decision)
6. [Two shapes, one method](#two-shapes-one-method)
7. [Working with a person](#working-with-a-person)
8. [Deciding: styles and conflicts](#deciding-styles-and-conflicts)
9. [Why structure beats prose](#why-structure-beats-prose)

## What the document is for

The real work is structured thinking about a technical decision: framing the problem, weighing the
options against what matters, and committing with reasons. The written artifact is the trace that
thinking leaves behind, so the next person (a new hire, a reviewer, your future self) can follow not
just what was chosen but why, and could have reached the same conclusion from the same evidence. Keep
that order of priority. A document that reads well but skips the thinking is worthless; treat the
artifact as a consequence of the reasoning, never as the goal, or it curdles into bureaucracy. Code
shows what was built; this record shows why it was built that way and what was rejected.

The method is a pragmatic framework, not a fixed format. It blends the two industry documents people
usually keep apart: an RFC (a proposal floated before building, to weigh options and invite comment)
and an ADR (a terse record kept after, capturing the decision and its consequences). Treat the
distinction as a spectrum. Most real documents sit somewhere in between, a proposal that, once
accepted, becomes the record. Pick the depth the decision warrants and the sections that carry the
reasoning; the goal is a useful artifact, not compliance with a template.

Two things make these documents hard, and the method exists to counter both. First, it is tempting to
follow hype or personal taste; decisions made without objective criteria cost the whole team later.
Second, we tend to make things more complicated than they need to be. Anyone can complicate, few can
simplify, and simplifying is the real work. So tie every choice back to a stated requirement, and cut
anything that is not pulling its weight.

## Be the architect, not the scribe

You are not transcribing someone else's decision. You are the architect on this decision, or the
architect's pair, and that changes what you do with the material you were handed. Whoever asked for
the document has already made assumptions, already narrowed the options, and probably already mixed
constraints, goals, prior decisions and solutions into one list. Sorting that out is the job.

**Every input is a claim, not a fact.** Numbers, current-state descriptions, "we already decided X":
each is a claim with a source, and the source may be memory. Verify what the codebase, the schema, the
dashboards, the tickets and the logs can answer. Do the lookup before asking the user; a question you
could have answered yourself spends their attention for nothing. When the user states a figure with no
source, the figure enters the document labeled *assumed*, with the user as its origin and a named way
to confirm it. That is not distrust; it is the same treatment every other claim gets.

**The framing is part of what you challenge.** "It is between X and Y" is a hypothesis about the
option space, not the option space. Ask what goal makes those two the candidates, then name at least
one credible option nobody proposed, including the boring ones: change nothing, do the smallest thing
that would work, buy instead of build. A useful check before the tradeoff table: write down what every
option on the list has in common. Each shared element is a decision that has already been made without
a row of its own. If all three options are "build an internal service in language L", then "build"
and "L" are prior decisions, and each needs an alternative beside it or a clause that excludes the
alternative.

**Ask why until you reach a goal in the user's world.** Why is more important than how (Richards &
Ford, *Fundamentals of Software Architecture*, second law). An input with no goal behind it is one of
three things: a constraint imposed from outside the organization, which gets recorded with its source
and clause; a prior decision made by someone inside, which gets recorded with its author and enters the
tradeoff table; or an invention, which gets dropped. The distinction matters because only the first can
exclude an option. "The platform team said so" is not a law; it is a decision with an author, and
decisions with authors can be revisited at a cost the document should name.

**Push back with reasons, and record it.** When an input looks wrong, say so once, plainly, with the
evidence and the alternative. If the user reaffirms it, it becomes a prior decision whose author is the
user, and the document says so. Deference without reasons is how weak decisions get laundered into
official documents.

**Skepticism cuts both ways.** The architect's own additions face the same tests as the user's list.
If you add a requirement the requester did not ask for, or one they explicitly declined (audit,
access control, retention), the row names the role it serves (an operator, a security function, a
compliance function, a negative stakeholder who bears the risk) and that role's goal. The requester's
objection is recorded as a stakeholder conflict in the Decision section. Quietly designing in what the
requester said they did not want is the mirror image of quietly accepting what they asked for, and it
is just as much a failure of the method.

**Skepticism is not obstruction.** Challenging inputs does not mean stalling on questions. Where an
answer would change the design, ask, one question at a time, with your recommended answer attached so
agreeing is cheap. Where it would not, state the assumption inline, label it, and keep going.

## Sharpen the axe first

> *"If I had eight hours to chop down a tree, I'd spend six sharpening the axe."* Attributed to
> Abraham Lincoln.

Architecture is the highest-leverage, hardest-to-reverse work in software. Get it wrong and no amount
of clean code downstream saves the project; the wrong foundation sinks everything built on it. So this
document always deserves your highest effort and slowest thinking. There is no quick mode, and a fast,
thin pass is itself a failure. Thinking time is not the bottleneck: a rushed plausible answer that is
subtly wrong costs far more than the hours spent getting it right.

Spend the bulk of your effort before the conclusion, sharpening: understanding the context, pinning
down the requirements that constrain the choice, exploring the alternatives in earnest. Concretely:

- **Do not commit to the first design that seems to work.** Generate real alternatives, at least two
  or three credible ones per dimension being decided, before you start narrowing. If you can only
  think of one option, you have not looked hard enough yet.
- **Grill your own recommendation.** For the option you favor, write down its strongest objection, not
  a strawman, and the specific conditions that would flip the decision the other way. A tradeoff table
  where every cell favors your pick is a warning sign, not a victory: you have stopped looking.
- **Steelman what you reject.** State each rejected alternative at its best, so a reader who prefers it
  sees you understood it and still had reasons. That is what makes the decision trustworthy.
- **Be precise; ambiguity is where bad decisions hide.** Concrete numbers, named components, grounded
  claims with a measurement. "Should be fast" hides a decision; "p95 at or below 300 ms under twice
  the measured peak, checked by the load run in CI" makes one.
- **Surface uncertainty honestly.** Where you are guessing, say so, and say what evidence (a spike, a
  proof of concept, a benchmark) would resolve it, then recommend running it. A proof of concept to
  de-risk an irreversible choice is the axe-sharpening, not a delay. It only counts as one, though, if
  it states before it runs which question it answers, what result passes, and what each outcome changes
  in the decision. Otherwise it is a way of not deciding.

## Why the steps gate each other

Work the steps in order, and finish each before starting the next. The sequence is the whole point,
not ceremony. The single most common way these efforts fail is rushing to a solution before the
problem is understood: a team arguing serverless versus containers before anyone has written down what
the system must do. When you feel the pull to name a technology, a component or an alternative while
you are still in Context or Requirements, that pull is the warning sign. Note the idea so you do not
lose it, then get back to the problem. A design built on a shaky requirement is wasted work, and a
tradeoff table over options nobody tied to a requirement is opinion dressed up as analysis.

So the earlier steps gate the later ones: do not open the Design until Context and Requirements are
settled, and do not run the Tradeoff until the Design is on the table. Hold the problem in focus until
it is understood; the solution discussion has to wait its turn.

The one moment to step back and read the whole document end to end is after the alternatives analysis
reaches its conclusion and before the decision. Check that the requirements still hold, that every
component traces to one, that every referenced identifier exists, that no two rows say the same thing,
and that the decision follows from the analysis. That review is the payoff of the discipline, earned by
working up to it; it is not permission to skip ahead.

## Sizing the decision

Before writing anything, decide how much decision this is, because that sets the depth of everything
else. The useful test is reversibility (Bezos, 2015 shareholder letter). A two-way door can be walked
back cheaply if it turns out wrong, so decide it fast and light, and say in one line why it is
reversible. A one-way door is expensive or impossible to undo: a data model, a public contract, a
consistency model, a security boundary, an external dependency you cannot remove. It earns the full
method, a proof of concept where the evidence is thin, and named reviewers. Architecture is exactly the
set of decisions that are hard to change (Fowler, *Who Needs an Architect?*, quoting Ralph Johnson).

A two-way door gets the light shape in `SKILL.md`: a Y-statement (in the context of, facing, we
decided, to achieve, accepting), two or three drivers, one line per option including do nothing, the
decision and decider, consequences, and what will be watched and when the decision will be revisited.
One page. Ceremony on a reversible choice is waste, and it teaches readers to skim the ones that
matter.

## Two shapes, one method

The RFC-to-ADR spectrum shows up as two practical shapes. Same method underneath; the framing and the
emphasis shift with when you are writing.

**Forward-looking (RFC, design doc).** You are choosing before building, to weigh options and invite
comment. This is the full method: the heart is the tradeoff analysis and the recorded decision. See
`example-rfc.md` and start from `../assets/template.md`; treat its sections as a checklist, not a
cage.

**Retrospective (ADR, technical documentation).** You are recording something already decided or
built. Same spirit, reshaped: Context (situation before, motivations, scope), Architecture (components
with responsibilities, step-by-step flows with a dynamic diagram), Risks and mitigations, Lessons
learned, improvement points, and a version history table. Every rule about evidence, roles, one name
per concept and standing alone still applies; only the decision machinery is replaced by what was
decided and what it taught. See `example-technical-doc.md`.

Pick the shape from what the user is doing: deciding, or recording a decision already made. When
unsure, ask.

## Working with a person

The user asked for an architect or an architect's pair, and a pair does not hand over a finished
document in one pass. When the request is interactive, stop at two checkpoints.

**After step 2.** Show, in a few lines, what you reclassified (which items moved from requirements to
constraints, prior decisions, design choices or wishes, and why), what you challenged (the framing,
a number, a claimed constraint) and what you assumed. Then show the requirement tables and ask for
confirmation before designing against them. A design built on requirements the user has not seen is a
design they will have to argue with later.

**After step 4.** Show the decision drivers and the tradeoff table before you write the decision. If
the user disagrees with a driver's priority, that changes the decision, and it is far cheaper to learn
it here.

Each checkpoint asks one thing and offers a recommended answer, so agreeing takes a word. Skip both
when the user asks for the document in one go, and say in the reply what you would have asked.

## Deciding: styles and conflicts

A decision has to be made and stated plainly: which alternative, and the reasoning that carried it.
Name the decider and the reviewers, and the style, so the basis is on the record. Autocratic: it is
one person's call; they consult and they own the outcome. Democratic: one vote each, majority decides,
with a fair tiebreaker for options that come out close. DACI is the same idea with the roles spelled
out: driver, approver, contributors, informed.

Record the stakeholder conflicts. Where a role's stated wish was overridden, say by which requirement
and whose, so the loser of the argument can see it was heard. Record the consequences (what becomes
easier, what becomes harder, what the team now has to live with), the residual risks the mitigations do
not remove, and the confirmation: the metric to watch, the automated check or fitness function, the
review date. A decision with no confirmation quietly decays into folklore.

Status goes proposed, accepted, superseded or deprecated, with the decisions this one supersedes or
relates to. A blocking open question, one whose answer would change the decision, holds the status at
proposed. Recommending an option above an unresolved legal question is not deciding; it is hoping.

## Why structure beats prose

A rule stated in prose is read once and forgotten by the time the section it governs is being written.
A table header is in front of the writer while they write. That is why `SKILL.md` gives every step its
skeleton and puts the tests beside it, why the goal column sits before the requirement column, why the
proof column exists at all, and why the tradeoff table has a requirements column: a cell that has to be
filled forces the comparison a paragraph merely recommends. When you find yourself writing a rule for
the document, ask which column would make the rule unnecessary.
