# Foundations

The method in `SKILL.md` is not invented. Every rule in it has a lineage in the architecture and
requirements literature, and knowing the lineage is useful for two reasons: it tells you what the rule
is for, and it gives you something to cite when someone pushes back on it.

Entries are grouped by which part of the method they support. Each says what this skill takes from the
source, not a summary of the whole work.

## Goals and roles

**van Lamsweerde, *Goal-Oriented Requirements Engineering: A Guided Tour* (RE'01, 2001), and
*Requirements Engineering: From System Goals to UML Models to Software Behaviors* (KAOS).** Goals are
refined downward until each leaf can be assigned to an agent; the leaves assigned to the software are
the requirements, the ones assigned to people or the environment are expectations. This is the formal
version of "ask why until you reach a goal in the user's world", the reason the Goals table exists in
step 1, and the test for a goal: a statement that already names the software's behaviour has skipped
the refinement. Gause and Weinberg's *Exploring Requirements* makes the same point from the
interviewing side: the stated requirement is rarely the real one.

**Alexander, *A Taxonomy of Stakeholders: Human Roles in System Development* (2005).** The onion model
places stakeholders by how they touch the system: operators, functional beneficiaries, maintainers,
regulators, sponsors, and negative stakeholders who lose something if the system succeeds. It is why
the stakeholder table is written in usage roles rather than departments, and why the architect's own
additions have to name a role: the negative stakeholder is usually the one nobody in the room speaks
for.

**Cockburn, *Writing Effective Use Cases* (2001).** A use case starts from an actor with a goal
against the system. The current-usage table and the "role, situation, action, observable result"
scenario in the Proof column come from here.

**North, *Introducing BDD* (2006).** Given/When/Then as the shape of an acceptance scenario. The skill
offers it as one way to write the Proof cell of a functional requirement, and takes from it the order
of work: scenario first, generalization second.

## Requirements

**Bass, Clements & Kazman, *Software Architecture in Practice* (4th ed., 2021).** The origin of two
ideas the skill leans on hardest. *Architecturally significant requirements*: only a small subset of
requirements shapes the structure, and identifying that subset is the architect's job, which is what
step 2's relevance tests do. And the *quality attribute scenario*: a non-functional requirement written
in six parts (source of stimulus, stimulus, artifact, environment, response, response measure) so it
can be tested rather than argued about. The skill compresses that into metric, target, condition and
measurement, and adds the derivation. The same book treats constraints as design decisions already made
for you, which is why they sit in Context rather than Requirements.

**ISO/IEC/IEEE 29148:2018, *Requirements engineering*.** Three things. The characteristics a single
requirement must have (necessary, appropriate, unambiguous, complete, singular, feasible, verifiable,
correct, conforming) and a set must have (complete, consistent, feasible, comprehensible, able to be
validated): *necessary* is why an unjustified requirement is suspect and *verifiable* is why every row
carries a proof. The definition of a constraint as an *externally imposed* limitation on the system,
its design or the process used to develop it: the reason the skill splits constraints from prior
decisions, and why a colleague cannot be the source of a constraint. And the list of language to
avoid (superlatives, subjective language, vague pronouns, ambiguous adverbs and adjectives, loopholes,
open-ended non-verifiable terms, comparatives, negative statements), which the words table is built
from.

**INCOSE, *Guide to Writing Requirements*.** The rules that turn the 29148 characteristics into
checks a reviewer can apply to a sentence. The words table cites four: R7 (avoid vague terms), R9
(avoid escape clauses), R10 (avoid open-ended clauses) and R28 (avoid absolutes).

**Meyer, *On Formalism in Specifications* (IEEE Software, January 1985).** The seven sins of the
specifier: noise, silence, overspecification, contradiction, ambiguity, forward reference, wishful
thinking. The first seven rows of the defect catalogue are these, and the catalogue is organized the
way it is because Meyer's list already existed and covered most of what one team had observed on its
own.

**Zave & Jackson, *Four Dark Corners of Requirements Engineering* (ACM TOSEM, 1997).** Requirements
describe the environment, specifications describe the machine. A technology inside a requirement is a
specification wearing a requirement's clothes, which is the sharpest statement of why overspecification
is a defect and where the mechanism should go instead.

**Glinz, *On Non-Functional Requirements* (RE 2007).** Shows that the usual functional versus
non-functional taxonomy leaks, and proposes a concern-based one. The skill keeps the two tables because
the non-functional table forces the five-part form, and cites Glinz to say plainly that the label is a
means, and the defect underneath a mislabeled row is a quality with no measure.

**Volere Requirements Specification Template (Robertson & Robertson).** Its requirement "shell"
carries a *Rationale*, an *Originator* and a *Fit Criterion* alongside the requirement text. Those are
the Goal, Source and Proof columns in step 2, and Volere's argument for them is the one this skill
makes: a requirement without a rationale cannot be traded off, and one without a fit criterion cannot
be signed off.

**Gilb, Planguage (*Competitive Engineering*).** Two contributions. Every quality requirement names a
*Scale* (how it is measured) and a *Meter* (how the measurement is taken), the metric and measurement
halves of the non-functional form. And the levels: *Past*, *Record* and *Trend* are benchmarks, *Goal*,
*Stretch* and *Wish* are targets, *Fail* and *Survival* are constraints. The *Derived from* column is
Planguage's *Past* beside its *Goal*: a target with no benchmark is a number with no argument. A *Wish*
is a stated value with no commitment behind it, which is the precise reason a wish cannot be a
requirement: it is a different kind of statement, not a lower-priority one.

**Mavin et al., EARS: *Easy Approach to Requirements Syntax* (RE 2009).** Five sentence patterns
(ubiquitous, event-driven, state-driven, unwanted behaviour, optional) in the form *while
<precondition>, when <trigger>, the <system> shall <response>*. Offered as an optional fixed form
because it forces a subject, a trigger and a response into every requirement sentence.

**Clegg & Barker, *Case Method Fast-Track* (1994); DSDM.** MoSCoW. The skill uses it as a bridge to
teams that already rank that way: only *Must* is a requirement.

**Wiegers & Beatty, *Software Requirements* (3rd ed.).** The taxonomy that keeps business requirements,
user requirements, functional requirements, quality attributes, constraints and business rules apart.
Useful when a list arrives flat and you need vocabulary for what each item is.

## Decisions

**Tyree & Akerman, *Architecture Decisions: Demystifying Architecture* (IEEE Software, 22(2), 2005).**
The earliest widely-cited decision template, and the most complete: issue, decision, status, group,
assumptions, constraints, positions, argument, implications, related decisions, related requirements,
related artifacts, related principles, notes. The skill borrows *positions* (the options considered,
stated fairly) and the insistence that cost, total cost of ownership and time to market are part of the
argument, not afterthoughts.

**Nygard, *Documenting Architecture Decisions* (2011).** The four-section ADR that made the practice
spread: context, decision, status, consequences, one file per decision, kept in version control. The
skill takes *consequences* as a required part of step 5, and the status lifecycle (proposed, accepted,
deprecated, superseded) that lets a corpus stay readable as it grows. A prior decision is a prior ADR
whether anyone wrote it down or not, which is why the prior decisions table records an author and a
date.

**MADR (Markdown Any Decision Records), 4.x, and Zimmermann's Y-statement.** Adds two things Nygard's
format leaves implicit: *decision drivers* stated before the options, so the analysis cannot be
reverse-engineered to fit a favorite, and *confirmation*, which says how the team will later check the
decision is holding. Both are in step 4 and step 5. The Y-statement is the one-sentence form and the
spine of the light shape for two-way doors: in the context of X, facing Y, we decided Z to achieve W,
accepting that V.

**Richards & Ford, *Fundamentals of Software Architecture*.** Two laws the skill quotes directly.
First: everything in software architecture is a trade-off, which is why step 4 exists and why an
analysis with no downsides is incomplete. Second: why is more important than how, which is the argument
for putting the goal column before the requirement column.

**Ford, Parsons & Kua, *Building Evolutionary Architectures*.** Fitness functions: an architectural
characteristic you care about should have an automated check that tells you when it stops holding.
That is the strongest form of step 5's confirmation, and the reason a non-functional requirement's
measurement method is worth writing down at decision time.

**Bezos, 2015 Amazon shareholder letter.** One-way and two-way doors: irreversible decisions deserve
slow, thorough process; reversible ones are damaged by it. Step 0 uses this to size the document.
Fowler's *Who Needs an Architect?* (IEEE Software, 2003) supplies the matching definition, quoting
Ralph Johnson: architecture is the set of decisions that are hard to change.

**Atlassian's DACI.** Driver, approver, contributors, informed. The skill uses it to make "who decided"
answerable in step 5 without inventing governance the team does not have.

## Evaluation and risk

**ATAM, the Architecture Tradeoff Analysis Method (Kazman, Klein & Clements, SEI).** A structured
evaluation built on a *utility tree* of quality attributes refined into scenarios, then analysis to
find *sensitivity points* (where one decision strongly affects one attribute), *tradeoff points* (where
it affects two in opposite directions) and *risks*. Step 4's requirements column is a lightweight ATAM,
and "state the tradeoff points explicitly" is the part most documents skip.

**DeMarco & Lister, *Waltzing with Bears: Managing Risk on Software Projects*.** Where the four risk
attributes come from: a risk that is named but not quantified and not given a response is not managed.
Mitigation (stop it happening) and contingency (act if it happens anyway) are distinct, and both are
needed.

## Structure and writing

**arc42.** A twelve-section template whose section boundaries the skill mirrors: constraints get their
own section (2), building-block view (5), runtime view (6), deployment view (7), decisions (9), quality
requirements (10), risks and technical debt (11), glossary (12). If a section of your document feels
homeless, arc42 usually has a home for it.

**C4 (Brown).** Context, container, component, code: a discipline for saying which level of zoom a
diagram is at, and for not mixing two levels in one picture. Every diagram in `diagrams.md` states its
level in its caption for this reason.

**Clements et al., *Documenting Software Architectures: Views and Beyond* (2nd ed.).** The seven rules
of sound documentation: write from the reader's point of view, avoid unnecessary repetition, avoid
ambiguity, use a standard organization, record rationale, keep documentation current but not too
current, and review it for fitness of purpose. "Write from the reader's point of view" is the source of
the newcomer-readable rule, and "record rationale" is why this document type exists at all. The same
work's *views* concept is behind step 3's "add a view when the decision turns on it".

**Minto, the SCQA structure (*The Pyramid Principle*).** Situation, complication, question, answer:
the shape of a Context section that lands on a problem instead of describing itself. Bryar & Carr's
*Working Backwards* makes the complementary case for self-contained narrative documents over slide
decks, which is where the "document stands alone" rule comes from.

**Ubl, *Design Docs at Google* (2020).** The practical argument for the genre: the value is in the
thinking and the alignment the document forces, and the document's usefulness peaks before the code is
written. It is also where the advice to keep them short enough that people read them belongs, and the
reason the decision document ends at confirmation while specifications live in their own files.

## Code-level neighbours

Two ideas from the code-craft literature earn a place because they catch requirement pathologies.
**YAGNI** ("am I solving a real problem or a hypothetical one?") is the same instinct as the wish-list
ban and the "anticipation" row of the words table. The distinction between **essential and accidental
complexity** (Brooks, *No Silver Bullet*) is useful when a design's complexity needs defending:
essential complexity traces to a requirement, accidental complexity traces to a choice, and only the
second kind is negotiable.
