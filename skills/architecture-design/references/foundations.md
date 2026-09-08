# Foundations

The method in `SKILL.md` is not invented. Every rule in it has a lineage in the architecture and
requirements literature, and knowing the lineage is useful for two reasons: it tells you what the rule
is actually for, and it gives you something to cite when someone pushes back on it.

Entries are grouped by which part of the method they support. Each says what this skill takes from the
source, not a summary of the whole work.

## Requirements

**Bass, Clements & Kazman — *Software Architecture in Practice* (4th ed., 2021).** The origin of two
ideas the skill leans on hardest. *Architecturally significant requirements*: only a small subset of
requirements shapes the structure, and identifying that subset is the architect's job, which is what
step 2's relevance tests do. And the *quality attribute scenario*: a non-functional requirement written
in six parts (source of stimulus, stimulus, artifact, environment, response, response measure) so it
can be tested rather than argued about. The skill compresses that into metric, target, condition and
measurement. The same book treats *constraints* as design decisions already made for you, which is why
they sit in Context rather than Requirements.

**ISO/IEC/IEEE 29148:2018, *Requirements engineering*.** Gives the characteristics a single requirement
must have: necessary, appropriate, unambiguous, complete, singular, feasible, verifiable, correct and
conforming. Two of them do most of the work here. *Necessary* is why an unjustified requirement is
suspect: if you cannot say what breaks without it, it is not necessary. *Verifiable* is why every row
carries a proof.

**Volere Requirements Specification Template (Robertson & Robertson).** Its requirement "shell" carries
a *Rationale*, an *Originator* and a *Fit Criterion* alongside the requirement text. Those are exactly
the Goal, Source and Proof columns in step 2, and Volere's argument for them is the one this skill
makes: a requirement without a rationale cannot be traded off, and one without a fit criterion cannot
be signed off.

**Gilb — Planguage (*Competitive Engineering*).** Insists that every quality requirement names a
*Scale* (how it is measured) and a *Meter* (how the measurement is taken), which is the metric and
measurement halves of the non-functional form. Planguage also separates commitment levels, and defines
a *Wish* as a stated value with no commitment behind it. That is the precise reason a wish cannot be a
requirement: it is a different kind of statement, not a lower-priority one.

**Wiegers & Beatty — *Software Requirements* (3rd ed.).** The taxonomy that keeps business requirements,
user requirements, functional requirements, quality attributes, constraints and business rules apart.
Useful when a list arrives flat and you need vocabulary for what each item is.

**van Lamsweerde — *Requirements Engineering: From System Goals to UML Models to Software Behaviors*
(KAOS).** Builds requirements downward from goals, so every requirement is an answer to "which goal
does this serve?". It is the formal version of the skill's "ask why until you reach a goal in the
user's world". Gause & Weinberg's *Exploring Requirements* makes the same point from the interviewing
side: the stated requirement is rarely the real one.

## Decisions

**Tyree & Akerman, "Architecture Decisions: Demystifying Architecture" (*IEEE Software*, 22(2), 2005).**
The earliest widely-cited decision template, and the most complete: issue, decision, status, group,
assumptions, constraints, positions, argument, implications, related decisions, related requirements,
related artifacts, related principles, notes. The skill borrows *positions* (the options considered,
stated fairly) and the insistence that cost, total cost of ownership and time to market are part of the
argument, not afterthoughts.

**Nygard, "Documenting Architecture Decisions" (2011).** The four-section ADR that made the practice
spread: context, decision, status, consequences, one file per decision, kept in version control. The
skill takes *consequences* as a required part of step 5, and the status lifecycle (proposed, accepted,
deprecated, superseded) that lets a corpus stay readable as it grows.

**MADR (Markdown Any Decision Records), 4.x, and Zimmermann's Y-statement.** Adds two things Nygard's
format leaves implicit: *decision drivers* stated before the options, so the analysis cannot be
reverse-engineered to fit a favorite, and *confirmation*, which says how the team will later check the
decision is holding. Both are in step 4 and step 5. The Y-statement is the one-sentence form: in the
context of X, facing Y, we decided Z to achieve W, accepting that V.

**Richards & Ford — *Fundamentals of Software Architecture*.** Two laws the skill quotes directly.
First: everything in software architecture is a trade-off, which is why step 4 exists and why an
analysis with no downsides is incomplete. Second: why is more important than how, which is the whole
argument for putting the goal column before the requirement column.

**Ford, Parsons & Kua — *Building Evolutionary Architectures*.** Fitness functions: an architectural
characteristic you care about should have an automated check that tells you when it stops holding. That
is the strongest form of step 5's confirmation, and the reason a non-functional requirement's
measurement method is worth writing down at decision time.

**Bezos, 2015 Amazon shareholder letter.** One-way and two-way doors: irreversible decisions deserve
slow, thorough process; reversible ones are damaged by it. Step 0 uses this to size the document.
Fowler's "Who Needs an Architect?" (*IEEE Software*, 2003) supplies the matching definition, quoting
Ralph Johnson: architecture is the set of decisions that are hard to change.

**Atlassian's DACI.** Driver, approver, contributors, informed. The skill uses it to make "who decided"
answerable in step 5 without inventing governance the team does not have.

## Evaluation and risk

**ATAM, the Architecture Tradeoff Analysis Method (Kazman, Klein & Clements, SEI).** A structured
evaluation built on a *utility tree* of quality attributes refined into scenarios, then analysis to find
*sensitivity points* (where one decision strongly affects one attribute), *tradeoff points* (where it
affects two in opposite directions) and *risks*. Step 4's requirement-by-requirement weighing is a
lightweight ATAM, and "state the tradeoff points explicitly" is the part most documents skip.

**DeMarco & Lister — *Waltzing with Bears: Managing Risk on Software Projects*.** Where the four risk
attributes come from: a risk that is named but not quantified and not given a response is not managed.
Mitigation (stop it happening) and contingency (act if it happens anyway) are distinct, and both are
needed.

## Structure and writing

**arc42.** A twelve-section template whose section boundaries the skill mirrors: constraints get their
own section (2), building-block view (5), runtime view (6), deployment view (7), decisions (9), quality
requirements (10), risks and technical debt (11), glossary (12). If a section of your document feels
homeless, arc42 usually has a home for it.

**C4 (Brown).** Context, container, component, code: a discipline for saying which level of zoom a
diagram is at, and for not mixing two levels in one picture. Step 3's static diagram should be at one
level and say which.

**Clements et al. — *Documenting Software Architectures: Views and Beyond* (2nd ed.).** The seven rules
of sound documentation: write from the reader's point of view, avoid unnecessary repetition, avoid
ambiguity, use a standard organization, record rationale, keep documentation current but not too
current, and review it for fitness of purpose. "Write from the reader's point of view" is the source of
the newcomer-readable rule, and "record rationale" is why this document type exists at all. The same
work's *views* concept is behind step 3's "add a view when the decision turns on it".

**Minto — the SCQA structure (*The Pyramid Principle*).** Situation, complication, question, answer: the
shape of a Context section that lands on a problem instead of describing itself. Bryar & Carr's
*Working Backwards* makes the complementary case for self-contained narrative documents over slide
decks, which is where the "document stands alone" rule comes from.

**Ubl, "Design Docs at Google" (2020).** The practical argument for the genre: the value is in the
thinking and the alignment the document forces, and the document's usefulness peaks before the code is
written. It is also where the advice to keep them short enough that people actually read them belongs.

## Code-level neighbours

Two ideas from the code-craft literature earn a place because they catch requirement pathologies:
**YAGNI** ("am I solving a real problem or a hypothetical one?") is the same instinct as the wish-list
ban, and the distinction between **essential and accidental complexity** (Brooks, *No Silver Bullet*) is
useful when a design's complexity needs defending: essential complexity traces to a requirement,
accidental complexity traces to a choice, and only the second kind is negotiable.
