# Review checklist

The full criteria for reviewing a text, grouped by the level where a text breaks, each with
the test a reviewer runs and the sources behind it. Run them in level order: contract, then
structure, then local. A wrong contract makes every later finding aim at the wrong reader.

## Contents

- Contract criteria
- Structure criteria
- Local criteria: coherence
- Local criteria: sentences
- Local criteria: examples
- Finding format
- What a review leaves alone
- Source strength

## Contract criteria

| # | Criterion | Test | Sources |
|---|---|---|---|
| C1 | The reader and their prior knowledge are stated. | Point to the sentence or `audience` field naming who reads and what they know. | McNamara et al. 1996; Google tech writing; digital.gov; Clements rule 1 |
| C2 | The reader's question is stated or evident. | Write it as one sentence ending in "?". | Minto; Shape Up; Flower 1979 |
| C3 | Scope and out-of-scope are stated. | Point to both. | Google tech writing; Shape Up no-gos |
| C4 | The answer comes before its support. | Stop after the first paragraph; the main point is known. | NN/g inverted pyramid and F-pattern; Microsoft; Google |
| C5 | Explicitness matches the reader. | New-to-domain reader: terms defined, relations stated. Expert: nothing they already know. | McNamara et al. 1996; Grice quantity; Anthropic |
| C6 | The document serves one kind of need. | Classify the document and each section as tutorial, how-to, reference or explanation; they match. | Diátaxis |
| C7 | A proposal states a concrete problem before the solution. | Point to one specific story of the status quo failing. | Shape Up; Minto |

## Structure criteria

| # | Criterion | Test | Sources |
|---|---|---|---|
| S1 | Headings alone form a correct summary. | Read only the headings, in order. | McNamara macrosignals; Microsoft "headings as an outline" |
| S2 | Each heading is kept by its body. | The first sentence under it delivers its promise; nothing below contradicts it. | Google; NN/g microcontent; Williams |
| S3 | Headings are specific, front-loaded, never empty. | Cut each heading to two words; the topic survives. No heading directly follows another. | NN/g F-pattern; Google; Microsoft |
| S4 | One topic per paragraph, topic sentence first. | Read first sentences only; the argument survives. | Strunk 8–9; Gopen & Swan; Google |
| S5 | Each fact lives in one place. | Search each key claim; it appears once. | Clements rule 2 |
| S6 | No two statements contradict. | Collect every claim about each entity, middle sections included; they agree. | Mündler et al. 2023; ConStory-Bench |
| S7 | Conditions precede the instruction they govern. | Each "if/when/to" clause comes before its imperative. | Google; ASD-STE100 |
| S8 | Enumerations are lists with parallel items. | Three or more parallel items sit in a list sharing grammar. | Strunk 15; NN/g |
| S9 | Each section stands without memory of earlier ones. | Any definition a section depends on is restated or linked. | NN/g comprehension; Basecamp |

## Local criteria: coherence

| # | Criterion | Test | Sources |
|---|---|---|---|
| L1 | Every pronoun and "this" has one antecedent. | Name it; exactly one candidate. | McNamara revision 1; Google; Haviland & Clark |
| L2 | Relations between sentences are stated where the reader would guess. | Name the relation for each pair; write the connective if you guessed. | McNamara revision 3; Gopen & Swan |
| L3 | Consecutive sentences share a noun. | Name the shared noun for each pair. | McNamara revision 4; Kintsch & van Dijk |
| L4 | Given before new; the point at the end. | Sentence N+1 opens on something in sentence N; each sentence ends on its point. | Gopen & Swan; Williams; Strunk 18 |
| L5 | One name per concept, one concept per name. | Search synonyms of each key term. | Microsoft; ASD-STE100; Google |
| L6 | New terms are defined or linked at first use. | List terms the declared reader may not know; each has a definition where it first appears. | Pinker; McNamara revision 2; Basecamp |
| L7 | No second plausible reading. | Write the alternative reading of each claim or instruction. | Clements rule 3; Basecamp rule 8; Grice manner |

## Local criteria: sentences

| # | Criterion | Test | Sources |
|---|---|---|---|
| L8 | Actor as subject, action as verb. | Underline subject and verb; a -tion noun beside "is" or "occurs" hides the verb. | Williams; Zinsser; Orwell; Gopen & Swan |
| L9 | Each passive is justified. | Unknown actor, shorter subject, or topic string; otherwise active. | Williams; Strunk 10; Orwell |
| L10 | Concrete words and values. | Replace each "some", "various", "recently", "improved" with the value. | Strunk 12; Orwell |
| L11 | Every word survives deletion. | Delete it; if nothing is lost, it goes. | Strunk 13; Orwell; Zinsser; NN/g |
| L12 | Hedges are stated conditions. | Each "probably", "seems", "may" names when the claim fails, or goes. | Pinker; Thomas & Turner |
| L13 | No sentence about the document. | No subject like "this section", "as mentioned above", "it is worth noting". | Pinker; Thomas & Turner |
| L14 | No condescension or deference. | No "simply", "obviously", "just", "of course", "as you know". | Thomas & Turner |
| L15 | Length within the reader's flag. | Procedures 20 words; general explanatory 15–20; expert 25. | ASD-STE100; NN/g |
| L16 | Reads aloud once, in order. | Each sentence is clear when it ends. | Thomas & Turner; Fried |

## Local criteria: examples

| # | Criterion | Test | Sources |
|---|---|---|---|
| E1 | Every detail serves the point. | Delete each clause; the point survives only with what remains. | Grice relation and quantity |
| E2 | Contrasts are needed, in prose and in examples. | Each "X, not Y" names something the reader would otherwise do, and the text says why Y is wrong. | Grice |
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
- Surface tells of AI-written prose that do not affect the reader's understanding, which
  belong to the humanizer skill.

## Source strength

The research notes in the lmarqs/skills repository record each source's verification status.
In short:

- **Experimental:** McNamara et al. 1996 (explicitness relative to reader knowledge; the
  coherence operations); NN/g reading studies (scanning, answer-first, concise and scannable
  text); Mündler et al. 2023 (self-contradiction rate in model output); Haviland & Clark 1974
  (given-new bridging, via secondary description).
- **Verified guidance:** Gopen & Swan 1990; Strunk; Orwell; Google and Microsoft style guides;
  Diátaxis; Clements et al. rules; digital.gov plain language; Basecamp; ASD-STE100 principles.
- **Secondary only:** wording from Williams, Pinker, Zinsser, Minto and Grice was confirmed
  through quotations in other sources, not the books themselves. The principles agree across
  those sources; exact phrasing may differ from the originals.
