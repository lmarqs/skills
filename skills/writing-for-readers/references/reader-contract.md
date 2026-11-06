---
description: The four declarations a text makes before its body, how to write them, and how the declared reader sets explicitness and document kind.
audience: Whoever starts a new text or opens a review with the writing-for-readers skill, before any other criterion.
---

# The reader contract

The reader contract is four declarations a text makes before its body: who reads it, what they
need from it, what it covers, and what the answer is. Every other criterion is judged against
it. A heading is "clear" or a term "undefined" only relative to a declared reader.

## Contents

- Why the reader comes first
- The four declarations
- Where the contract goes
- Setting explicitness from the reader
- One reader need per document
- Problem before solution

## Why the reader comes first

McNamara, Kintsch, Songer and Kintsch (1996) wrote four versions of one text about heart
disease, adding or removing coherence signals, and tested readers who knew little or a lot
about the heart. Readers new to the domain did best with the fully explicit text. Readers who
knew the domain built a deeper understanding from the sparse text, because they had to supply
the links themselves. The authors conclude: "Tuning the level of detail and coherence to the
audience is implicitly expected of writers. Often, however, writers underestimate their
audience and end up with an overly explicit text." (p. 36)

So no text is clear in itself. The writer has to pick a reader first, and the most common
mistake is to pick none: the text then defaults to the writer's own knowledge, which is the
one reader it will never have. Linda Flower (1979) called this writer-based prose, whose
symptoms range "from a mere missing referent or an underdeveloped idea" to "an unfocused and
apparently pointless discussion".

## The four declarations

| Declaration | States | Example |
|---|---|---|
| **Reader** | Who reads, and what they already know and do not know. | "On-call backend engineers. Know Kubernetes; have never touched billing." |
| **Question** | The problem the text solves or the decision it supports, as the reader would ask it. | "How do I undo a bad billing deploy?" |
| **Scope** | What the text covers, and what it leaves to other documents. | "Covers the rollback command and the migration check. Incident communication is in the on-call handbook." |
| **Answer** | The conclusion, recommendation or result. | "Run `make rollback ENV=prod`; it restores the previous image in about two minutes." |

Google's technical writing course states the first three directly: "A good document begins
by defining its scope", "A better document additionally defines its non-scope", and "A good
document explicitly specifies its audience", for example "This document assumes that you
understand matrix multiplication". The US plain-language guidelines call "write for your
audience" the first rule, taking into account readers' "current level of knowledge,
expertise, and interest".

A text with two reader groups whose knowledge differs either picks one or gives each its own
section. One section written for both is too explicit for one group and too sparse for the
other.

## Where the contract goes

**Markdown documents.** The frontmatter carries the reader in `audience` and the question in
`description`; the first paragraph carries the answer, then the scope. The frontmatter keeps the text anchored while it is written,
since every section can be checked against it.

```markdown
---
description: <What this document does and when someone needs it, in one sentence.>
audience: <Who reads it. What they know. What they do not know.>
---

# <Title naming the subject in the reader's words>

<Answer in one or two sentences.> <Scope: what this covers and where the rest lives.>
```

For a spec, design note or proposal, the opening states objective, problem and goal before
any solution:

```markdown
---
description: Proposal to move invoice generation off the request path.
audience: Billing team and the platform reviewers who approve queue usage.
---

# Generate invoices asynchronously

**Objective.** Keep checkout under 300 ms at month-end peak.
**Problem.** On 31 March, checkout took 4.2 s for 40 minutes because each request rendered
its PDF invoice inline.
**Goal.** Checkout returns before the invoice exists; the invoice arrives by email within a
minute.
**Out of scope.** Changing the invoice format.
```

**Agent answers and replies.** The next response is the document, and the conversation sets
its contract:

- **Reader:** the person who asked. What they already know includes everything said in the
  conversation so far, claims the reply is about to change among them.
- **Question:** every question in their last message, plus any earlier one still unanswered.
- **Answer:** the first sentence answers the first question, and each question gets its answer,
  in the order asked, before anything new. An explanation ends on what it means for the
  reader: a decision, an action, or that nothing changes.

The reader already holds what the conversation said, so a claim that changes an earlier one
names it: "Earlier I blamed the worker pods; the eviction log shows only the api-server was
evicted." A reply that contradicts the conversation without saying so contradicts itself, as a
document does when its middle disagrees with its opening.

Scope appears only when the answer covers less than was asked, as one sentence saying what was
left out and why. Reasoning follows only as far as the reader needs it to trust or act on the
answer.

An example. An SRE lead has asked three things after reading an eviction log: was it the
api-server and why was it evicted, is the worker memory bump still needed, and is release 4.12
safe to deploy. An earlier reply had blamed the workers. A reply written from the agent's
notes:

> I pulled the eviction log and the node metrics for the 08:40 window. There were two
> evictions on `general-b`, both with reason "node memory pressure", and node `general-b-7`
> was running the PDF renderer, which has no memory limit and used 6.1 GiB. The workers
> peaked at 410Mi. 4.12 only changes the pricing page and the logging library. So it looks
> like a node pressure issue rather than the workers.

The reader has to work out that the first question's answer is "yes", that the bump is not
needed, and that 4.12 is safe; the correction is never named. The same facts, written to the
conversation's contract:

> Yes, it was the api-server. My 09:10 answer was wrong: the workers were not OOM-killed and
> never restarted.
>
> **Why it was evicted:** the PDF renderer, which has no memory limit, grew to 6.1 GiB of
> `general-b-7`'s 8 GiB, and the api-server, with a 256Mi request, was evicted first at 08:41
> and 08:47.
>
> **Worker memory bump:** not needed. Workers peaked at 410Mi of 512Mi; I withdraw it.
>
> **4.12 this afternoon:** safe with respect to this incident; it touches none of these
> components. It also does not fix the cause.
>
> **Next:** a memory limit on the renderer and a higher request for the api-server, before the
> next invoice batch. Tell me whether to open them.

The first sentence answers the first question; the correction is named; each question is
answered in the order asked; the ending is the reader's decision.

**Short texts** (a commit message, a Slack update, a PR title) state the answer and let the
channel imply the reader. The contract still applies; it is implicit because the setting
already declares it.

## Setting explicitness from the reader

McNamara et al. raised a text's coherence with four local operations and two global signals.
For a reader new to the domain, apply all six. For an expert, apply only what removes real
ambiguity.

| Operation | New-to-domain reader | Expert reader |
|---|---|---|
| Replace a pronoun with its noun when two referents compete | Always | Always |
| Link each unfamiliar concept to a familiar one at first mention | Always | Only for terms outside their field |
| State the relation between sentences with a connective | Always | Where the relation is not obvious to an expert |
| Repeat the same noun for the same thing | Always | Always |
| Topic headings | Always | Always |
| A sentence linking each paragraph to the document's point | Always | In long documents |

Ambiguity removal applies to every reader. The rest scales with what the reader brings.

The test for over-explicitness is Anthropic's for agent readers, and it holds for people:
"Does [the reader] really need this explanation? Can I assume [they have] this information?"

## One reader need per document

Diátaxis sorts documentation by the reader's need:

| Kind | Reader asks | The text |
|---|---|---|
| Tutorial | "Can you teach me to…?" | Leads a learner through one safe path with no choices. |
| How-to guide | "How do I…?" | Gives a competent reader the steps for one task, with branches where reality branches. |
| Reference | "What is…?" | Describes the thing accurately and completely, without instructing. |
| Explanation | "Why…?" | Discusses context, reasons and alternatives. |

"When these distinctions are allowed to blur, the different kinds of documentation bleed into
each other." A how-to interrupted by a page of rationale loses the reader mid-task; a tutorial
that offers alternatives loses the learner. One document serves one kind. A section that
answers a different question than its document moves to its own document, with a link.

Agent answers usually have one kind too: a how-to ("run this"), a reference ("the value is
X"), or an explanation ("it fails because…"). An answer that mixes them puts the kind the
reader asked for first.

## Problem before solution

When the text proposes something, the reader judges the solution against the problem, so the
problem comes first and is concrete. Shape Up puts it plainly: "The best problem definition
consists of a single specific story that shows why the status quo doesn't work", and without
one "there's no test of fitness to judge whether one solution is better than the other". Its
pitch format also names the no-gos: "Anything specifically excluded from the concept."

Barbara Minto's opening for business writing does the same in three moves: the situation the
reader recognizes, the complication that changed it, and the question that follows, which the
document then answers.
