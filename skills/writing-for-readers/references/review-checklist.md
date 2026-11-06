---
description: Every criterion of the writing-for-readers skill with its code, test and source, the finding format, what a review leaves alone, and where each source was read.
audience: Whoever runs a complete review with the writing-for-readers skill.
---

# Review checklist

The full criteria for reviewing a text, grouped by the level where a text breaks, each with
the test a reviewer runs and the sources behind it. Run them in level order: contract, then
structure, then local. A wrong contract makes every later finding aim at the wrong reader.
A row whose test reads "Core #n" is one of the seventeen core criteria; its test is row n of
the criteria table in [`SKILL.md`](../SKILL.md) and is stated only there.

## Contents

- Contract criteria
- Structure criteria
- Local criteria: coherence
- Local criteria: sentences
- Local criteria: examples
- Finding format
- What a review leaves alone
- Sources

## Contract criteria

| # | Criterion | Test | Sources |
|---|---|---|---|
| C1 | The reader and their prior knowledge are stated. | Core #1 | McNamara et al. 1996; Google tech writing |
| C2 | The reader's question is stated or evident. | Write it as one sentence ending in "?". In a reply, list every question the reader asked; each has an answer. | Diátaxis |
| C3 | Scope and out-of-scope are stated. | Core #3 | Google tech writing |
| C4 | The answer comes before its support. | Core #2 | NN/g inverted pyramid and F-pattern; Google |
| C5 | The text holds nothing the declared reader already knows. | Core #15. For a reader new to the domain, the reverse also holds: terms are defined and relations stated. | McNamara et al. 1996; Grice quantity; Anthropic |
| C6 | The document serves one kind of need. | Classify the document and each section as tutorial, how-to, reference or explanation; they match. | Diátaxis |
| C7 | A proposal states a concrete problem before the solution. | Point to one specific story of the status quo failing. | Gopen & Swan |
| C8 | One writer addresses one reader in one register throughout. | Core #17 | McNamara et al. 1996 |

## Structure criteria

| # | Criterion | Test | Sources |
|---|---|---|---|
| S1 | Headings alone form a correct summary. | Core #5 | McNamara macrosignals |
| S2 | Each heading is kept by its body. | Core #4 | Google; NN/g microcontent |
| S3 | Headings are specific, front-loaded, never empty. | Cut each heading to two words; the topic survives. No heading directly follows another. | NN/g F-pattern; Google |
| S4 | One topic per paragraph, topic sentence first. | Core #6 | Strunk 8–9; Gopen & Swan; Google |
| S5 | Each fact lives in one place. | Core #7 | Mündler et al. 2023 |
| S6 | No two statements contradict. | Core #8 | Mündler et al. 2023 |
| S7 | Conditions precede the instruction they govern. | Each "if/when/to" clause comes before its imperative. | Google; ASD-STE100 |
| S8 | Enumerations are lists with parallel items. | Three or more parallel items sit in a list sharing grammar. | Strunk 15; NN/g |
| S9 | Each section stands without memory of earlier ones. | Any definition a section depends on is linked from it. | NN/g comprehension |
| S10 | The text ends on what the reader does next. | Core #16. A link list or a summary of the text is not an ending. | Strunk 18, applied to the text; NN/g F-pattern |

## Local criteria: coherence

| # | Criterion | Test | Sources |
|---|---|---|---|
| L1 | Every pronoun and "this" has one antecedent. | Core #9 | McNamara revision 1; Google |
| L2 | Relations between sentences are stated where the reader would guess. | Core #12 | McNamara revision 3; Gopen & Swan |
| L3 | Consecutive sentences share a noun. | Core #12 | McNamara revision 4 |
| L4 | Given before new; the point at the end. | Core #12, plus: each sentence ends on its point. | Gopen & Swan; Strunk 18 |
| L5 | One name per concept, one concept per name. | Core #10, and the reverse: each name has one concept. | ASD-STE100; Google |
| L6 | New terms are defined or linked at first use. | Core #11 | Pinker; McNamara revision 2 |
| L7 | No second plausible reading. | Write the alternative reading of each claim or instruction. | Grice manner |

## Local criteria: sentences

| # | Criterion | Test | Sources |
|---|---|---|---|
| L8 | Actor as subject, action as verb. | Underline subject and verb; a -tion noun beside "is" or "occurs" hides the verb. | Orwell; Gopen & Swan |
| L9 | Each passive is justified. | Unknown actor, shorter subject, or topic string; otherwise active. | Strunk 10; Orwell |
| L10 | Concrete words and values. | Replace each "some", "various", "recently", "improved" with the value. | Strunk 12; Orwell |
| L11 | Every word survives deletion. | Delete it; if nothing is lost, it goes. | Strunk 13; Orwell; NN/g; Dubois et al. 2024 |
| L12 | Hedges are stated conditions. | Each "probably", "seems", "may" names when the claim fails, or goes. | Pinker |
| L13 | No sentence about the document. | No sentence that announces, recaps or comments on the text in place of content: "this section will discuss", "as mentioned above", "it is worth noting". A scope line names subjects and where the rest lives ("Incident communication lives in the on-call handbook"), so it passes. | Pinker |
| L14 | No condescension or deference. | No "simply", "obviously", "just", "of course", "as you know". | Google word list |
| L15 | Sentence length within the flag. | Procedures 20 words; descriptive text 25. A longer sentence stays when it passes L8 and makes one point. | ASD-STE100; Strunk |
| L16 | Reads aloud once, in order. | Each sentence is clear when it ends. | — |

## Local criteria: examples

| # | Criterion | Test | Sources |
|---|---|---|---|
| E1 | Every detail serves the point. | Core #13 | Grice relation and quantity |
| E2 | Contrasts are needed, in prose and in examples. | Core #14 | Grice |
| E3 | Shared features are rules or varied. | List what all examples share. | Anthropic prompting guidance |
| E4 | Names come from the reader's domain. | No foo or bar. | Google |

## Finding format

Each finding has four parts:

```markdown
**S2 Heading kept by body.** "## Rollback is automatic" is followed by "Run `make rollback`
by hand after a failed deploy."
Test: the first sentence under the heading contradicts it.
Rewrite: "## Roll back manually with `make rollback`"
```

Order findings by level, contract first, then by position in the text. Unanswered contract
questions are findings in their own right: "C1: the text never says who it is for; the
glossary suggests new hires, the deploy section assumes the on-call team."

When a criterion passes everywhere, the review says nothing about it. When the text is
sound, the review says so in one sentence.

## What a review leaves alone

- The author's terms of art and names, which stay verbatim even when a finding rewrites the
  sentence around them.
- The author's voice: humor, first person, asides that carry personality without blocking
  the reader.
- Quotations, code, commands, URLs and error text.
- Surface tells of AI-written prose that do not affect the reader's understanding.

## Sources

A quotation in this skill was read at the address below. A source whose text is not published
online by its author or publisher gives this skill its principles in paraphrase, without
quotation marks, and the table says so. The research notes in the
[lmarqs/skills repository](https://github.com/lmarqs/skills/tree/main/workspaces/writing-for-readers/sources)
record the verification status of each claim.

**Classics**

| Source | Read at | What it gives this skill |
|---|---|---|
| Strunk, *The Elements of Style*, 1918 | [Project Gutenberg](https://www.gutenberg.org/ebooks/37134) | Rules 8–18: paragraph as unit, topic sentence, active voice, definite assertions, needless words, parallel form, emphasis at the end |
| Orwell, "Politics and the English Language", 1946 | [The Orwell Foundation](https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/politics-and-the-english-language/) | The six rules, the four questions, dying metaphors, verbal false limbs, pretentious diction |
| Grice, "Logic and Conversation" | [Stanford Encyclopedia of Philosophy, "Implicature"](https://plato.stanford.edu/entries/implicature/) | The cooperative principle and the maxims of quantity, relation and manner, as quoted there |
| Gopen & Swan, "The Science of Scientific Writing", 1990 | [American Scientist](https://www.americanscientist.org/blog/the-long-view/the-science-of-scientific-writing) | Topic and stress positions, given before new, subject–verb proximity |
| McNamara, E. Kintsch, Songer & W. Kintsch, "Are Good Texts Always Better?", *Cognition and Instruction* 14(1), 1996 | [doi:10.1207/s1532690xci1401_1](https://doi.org/10.1207/s1532690xci1401_1); the PDF is on the SoLET Lab publications page | Explicitness relative to reader knowledge; the four local-coherence operations and two macrosignals; experimental |
| Pinker, *The Sense of Style* | [Harvard Gazette, "Exorcising the curse of knowledge", 2012](https://news.harvard.edu/gazette/story/2012/11/exorcising-the-curse-of-knowledge) | The curse of knowledge, "the failure to understand that other people don't know what we know". Metadiscourse and hedging are paraphrased |

**Practice standards**

| Source | Read at | What it gives this skill |
|---|---|---|
| Google | [Technical Writing One](https://developers.google.com/tech-writing/one/) and [developer documentation style guide](https://developers.google.com/style/) | Audience statement, scope, paragraphs, headings, condition before instruction, example names, words that talk down |
| Nielsen Norman Group | [How Users Read on the Web](https://www.nngroup.com/articles/how-users-read-on-the-web/), [F-Shaped Pattern](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/), [Inverted Pyramid](https://www.nngroup.com/articles/inverted-pyramid/), [Microcontent](https://www.nngroup.com/articles/microcontent-how-to-write-headlines-page-titles-and-subject-lines/), [Legibility, Readability, and Comprehension](https://www.nngroup.com/articles/legibility-readability-comprehension/) | Scanning, answer first, headings that work out of context, the measured gains of concise, scannable and objective text; experimental |
| Diátaxis | [diataxis.fr](https://diataxis.fr/) | Tutorial, how-to, reference, explanation; why mixing them fails |
| ASD-STE100 | [asd-ste100.org](https://asd-ste100.org) | One word one meaning, active voice, condition first, one instruction per sentence. Rule numbers and word limits come from a vendor's Issue 8 list, so they are flags, not the standard's text. The 20- and 25-word limits apply here to text for any reader |

**Agent era**

| Source | Read at | What it gives this skill |
|---|---|---|
| Mündler et al., "Self-contradictory Hallucinations of LLMs", 2023 | [arXiv 2305.15852](https://arxiv.org/abs/2305.15852) | Self-contradiction rate in model output; experimental |
| Dubois et al., "Length-Controlled AlpacaEval", 2024 | [arXiv 2404.04475](https://arxiv.org/abs/2404.04475) | Automatic judges of model output favor longer outputs; experimental |
| Anthropic | [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) and [skill best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) | Examples that vary, the over-explanation test |
