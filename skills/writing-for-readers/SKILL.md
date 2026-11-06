---
name: writing-for-readers
description: >-
  Holds any text a person or agent will read to objective, reader-centered criteria, both when
  writing it and when reviewing it. Declares the reader, what they already know, their question
  and the scope before the body; puts the answer first; keeps one topic per section and
  paragraph; makes every heading promise exactly what its body delivers; keeps each fact in one
  place so the text cannot contradict itself; resolves every pronoun and term; and builds
  examples that carry only their point. Use it whenever someone writes, rewrites or reviews
  prose for others: a README, doc, spec, design doc, runbook, how-to, PR description, release
  note, announcement, status report or an agent's answer. Triggers include "write the docs for
  X", "review this doc", "does this read well", "rewrite this for new hires", "this is
  confusing", "who is this for", or a Markdown file with audience frontmatter. Surface tells of
  AI-written prose and documents an agent executes, such as skills and AGENTS.md, need their own
  criteria.
---

# Writing for readers

A writer knows what they mean, so their own text always reads as clear to them. The reader has
only the page. Text fails when it is built from the writer's knowledge: it skips what the writer
takes for granted, follows the order the writer discovered things in, and names things the way
the writer thinks of them. Pinker calls this the curse of knowledge. Agents suffer it too, and
add a failure of their own: they lose the thread of a long text and contradict what they wrote
earlier.

A text is good relative to its reader, never in itself. McNamara and colleagues gave readers
the same content at two levels of explicitness: readers new to the domain learned more from the
explicit version, and readers who knew the domain learned more from the sparse one. So the
first act of writing is to declare the reader, and that declaration decides how much the text
spells out.

## Where a text breaks

| Level | What the reader says | What went wrong |
|---|---|---|
| **Contract** | "Who is this for? What do I do with it?" | No declared reader, question or scope, so the text assumes context the reader lacks. |
| **Structure** | "I had to read all of it before any of it made sense." | The answer is buried, headings do not match their bodies, or one document answers several kinds of question. |
| **Local** | "It contradicts itself." "What does *it* refer to?" | Two sentences disagree, a reference has two antecedents, one thing has two names, or an example carries detail its point does not need. |

Fix them in that order. A wrong contract makes every later fix aim at the wrong reader.

## The reader contract

Before the body, a text states four things:

1. **Reader.** Who reads it and what they already know. "A new backend engineer who knows
   Docker and has never deployed this service."
2. **Question.** What the reader needs from it: the problem it solves or the decision it
   supports.
3. **Scope.** What the text covers and what it leaves out.
4. **Answer.** The conclusion, decision or result, stated before any support for it.

In a Markdown file, the frontmatter carries the reader in `audience` and the question in
`description`; the opening paragraph carries the answer, then the scope:

```markdown
---
description: How to roll back a failed deploy of the billing service.
audience: Backend engineers on call. Know Kubernetes basics; have never touched billing.
---

# Rolling back billing

Roll back with `make rollback ENV=prod`; it restores the previous image in about two minutes.
Database migrations do not roll back with it; check them before you roll back. Incident
communication lives in the on-call handbook.
```

A reply in a conversation is a document too: the next response, with the conversation as its
contract. The reader is the person who asked and knows everything said so far; the question is
every question in their last message; the first sentence answers the first of them, and each
gets its answer in order. [`references/reader-contract.md`](references/reader-contract.md)
shows a reply before and after.

The reader decides explicitness. For a reader new to the domain, define each term at first use,
name the relation between sentences, and repeat the noun instead of a pronoun that could point
two ways. For an expert, cut everything they already know.

## Criteria

Each criterion has a test a reviewer can run on the text. These seventeen are the core set;
the code in the last column is its row in
[`references/review-checklist.md`](references/review-checklist.md), which adds the remaining
criteria and the sources behind each.

| # | Criterion | Test | Code |
|---|---|---|---|
| 1 | The reader and their prior knowledge are stated. | Point to the sentence or frontmatter field that names them. In a reply or a short text, the conversation or the channel names them; the text is pitched at that reader. | C1 |
| 2 | The answer comes first. | Stop after the first paragraph. The reader already has the main point. | C4 |
| 3 | Scope and what is out of scope are stated. | Point to both lines. A reply states scope only when it answers less than was asked, and then says what it left out. | C3 |
| 4 | Each heading promises exactly what its body delivers. | Read the heading, then the first sentence under it. The sentence keeps the heading's promise and nothing in the body breaks it. | S2 |
| 5 | Headings alone summarize the text. | Read only the headings, in order. They form a correct outline. | S1 |
| 6 | Each paragraph has one topic, stated in its first sentence. | Read only first sentences. The argument survives. | S4 |
| 7 | Each fact lives in one place. | Search for each key claim. It appears once; other places link to it. | S5 |
| 8 | No two sentences contradict each other. | For each entity, collect what the text says about it, middle sections included. The statements agree, and agree with what the reader was told earlier in the conversation unless the text names the correction. | S6 |
| 9 | Every pronoun and "this" has one antecedent. | Name the antecedent of each. There is exactly one candidate. | L1 |
| 10 | One term names one thing. | Search for synonyms of each key term. Each concept has one name. | L5 |
| 11 | Each new term is defined or linked where it first appears. | List terms the declared reader may not know. Each has a definition at first use. | L6 |
| 12 | Sentences connect: each opens on something the reader already has, and the relation is stated where the declared reader would have to guess it. | For each sentence pair, name the shared noun. If naming the relation took a guess, a connective states it. | L2–L4 |
| 13 | Every detail of an example serves its point. | Delete each clause of the example; if the lesson is unchanged, the clause goes. | E1 |
| 14 | Every contrast is one the reader needed. | For each "X, not Y", name what the reader would otherwise do with Y and why it is wrong. If you cannot, the contrast implies a rule nobody stated. | E2 |
| 15 | The text holds nothing the declared reader already knows. | For each paragraph, ask whether this reader has it already. If yes, it goes. | C5 |
| 16 | The text ends on what the reader does next. | Read the last paragraph alone. It states a decision, an action, or that nothing changes; a reader who finishes it does not ask "and?". | S10 |
| 17 | One writer addresses one reader in one register throughout. | Pick any two paragraphs. Both are pitched at the declared reader; neither explains to a novice what the other assumes of an expert. | C8 |

## How to use this guide

**To write a text:**

1. State the reader contract. When the reader is unknown, ask who will read it; when they can
   be inferred, write down the inference.
2. Outline with headings that are statements a reader could stop at. The outline is done when
   the headings alone answer the reader's question.
3. Draft each section from its heading: the first sentence keeps the heading's promise, the
   rest supports it.
4. Run the criteria table on the draft. Each failing row gets fixed before the next.
5. Read the text once, in order, as the declared reader. Every sentence is clear when it ends,
   without help from a later one.

**To review a text:**

1. Reconstruct the contract from the text. Any of the four declarations the text leaves
   unstated, and its setting does not supply, is the first finding. A reply takes its reader
   and question from the conversation; a short text takes them from its channel.
2. Run the criteria in level order: contract, then structure, then local.
3. Report each finding in the checklist's finding format: the quoted passage, the criterion it
   fails with its test, and a rewrite. Contract findings come first, then structure, then
   local, so the author fixes the largest problem first. A review longer than the text helps
   nobody: write out the findings that change most for the reader, and give the rest as a
   count per criterion.
4. Keep the author's terms and voice. A finding changes what the reader receives, never the
   author's taste.

## References

Read the one that matches the task. Each stands alone.

- [`references/reader-contract.md`](references/reader-contract.md): declaring reader,
  question, scope and answer; the frontmatter template; a reply before and after; how reader
  knowledge sets explicitness; the four kinds of documentation and why mixing them fails. Read
  it before writing anything new, or when a review's first question is "who is this for".
- [`references/structure.md`](references/structure.md): answer-first ordering, headings that
  summarize, one topic per paragraph, outlining before drafting, one place per fact, and how
  to check a long text for contradictions. Read it to organize a text or to review its shape.
- [`references/coherence.md`](references/coherence.md): the operations that make consecutive
  sentences connect: resolving pronouns, stating relations, given before new, one term per
  thing, defining at first use, and removing second readings. Read it when a text is
  correct but hard to follow.
- [`references/sentences.md`](references/sentences.md): sentences that read the way a person
  talks: actors as subjects, actions as verbs, concrete words, hedges turned into conditions,
  no sentences about the document itself, and length flags. Read it to edit
  sentence by sentence.
- [`references/examples.md`](references/examples.md): building examples that carry only their
  point, why one extra detail misleads, and how a set of examples teaches an unintended rule.
  Read it before writing or reviewing any example, sample or illustration.
- [`references/review-checklist.md`](references/review-checklist.md): the full criteria table
  with codes, tests and sources, the finding format, what a review leaves alone, and the
  Sources table with where each was read. Read it to run a complete review or to check a
  claim's source.
