---
description: The operations that make consecutive sentences connect, each with its test.
audience: Whoever writes or reviews a text with the writing-for-readers skill and finds it correct but hard to follow.
---

# Coherence

Coherence is what lets a reader move from one sentence to the next without stopping to work
out how they connect. A text can be correct sentence by sentence and still incoherent: every
claim true, but the reader left to guess what "it" means, why this sentence follows that one,
and whether two names refer to the same thing. Each guess is a chance to guess wrong.

## Contents

- How a reader links sentences
- Four operations that restore coherence
- Given before new
- One term per thing
- Defining at first use
- Removing second readings

## How a reader links sentences

McNamara et al. (1996) describe what building a coherent mental text requires: "the referents
of pronouns must be identified, synonymous terms must be matched, glaring gaps in the
coherence of the network must be filled by bridging inferences". Every one of those is work
the writer can do instead of the reader, and every bridge the reader has to build needs
knowledge they may not have.

## Four operations that restore coherence

McNamara et al. raised the local coherence of their text with four revisions (p. 21). Each is
a check a reviewer can run.

| Operation | Their wording | Test on a draft |
|---|---|---|
| Resolve pronouns | "Replacing pronouns with noun phrases when the referent was potentially ambiguous (e.g., replacing *it* with *the heart*)." | For each "it", "this", "that", "they": is there more than one candidate noun nearby? If so, use the noun. |
| Link the unfamiliar to the familiar | "Adding descriptive elaborations that link unfamiliar concepts with familiar ones." | Each term the declared reader does not know comes with a phrase in words they do know. |
| State relations | "Adding sentence connectives (e.g., however, therefore, because, so that) to specify the relation between sentences or ideas." | For each sentence pair, name the relation. If you had to guess it, write the connective. |
| Keep argument overlap | "Replacing words to increase argument overlap (e.g., replacing *person* and *cases* with *baby* or *babies*)." | Consecutive sentences share a noun. A sentence that shares none with its neighbour starts a new topic or leaves a gap. |

Google's course names the cost of the first one: "Using pronouns improperly causes the
cognitive equivalent of a null pointer error in your readers' heads."

How much of the second and third to apply depends on the declared reader (see the explicitness
table in [`reader-contract.md`](reader-contract.md)). The first and fourth apply to every reader.

## Given before new

Gopen and Swan (1990) describe where readers expect information within a sentence:

- The **topic position**, at the start, holds the person or thing the sentence is about and
  links back to what came before: "Place appropriate 'old information' (material already
  stated in the discourse) in the topic position for linkage backward".
- The **stress position**, at the end, holds what the reader should take away: "Place in the
  stress position the 'new information' you want the reader to emphasize."
- Subject and verb sit close together: "Follow a grammatical subject as soon as possible with
  its verb." A long phrase between them makes the reader hold the subject in memory while
  waiting for the action.
- Context comes before anything new: "provide context for your reader before asking that
  reader to consider anything new."

Williams teaches the same pattern as old before new, and adds the **topic string**: the
subjects of a paragraph's sentences come from a small, consistent set. List the subjects of a
paragraph in a column. If they name more than two or three unrelated things, the paragraph
has lost its thread.

Example. Each sentence opens on what the previous one ended with:

> The deploy job builds an image and pushes it to the registry. The registry tags each image
> with the commit hash. That hash is what `make rollback` uses to find the previous release.

## One term per thing

A reader assumes a new word means a new thing. When a text calls one component "the worker",
"the consumer" and "the job runner", the reader looks for three components, and finding one
makes them doubt everything else the text says about it.

- Microsoft: "Use one word for a concept, and use it consistently. Avoid using synonyms to
  refer to the same concept."
- ASD-STE100 builds its whole dictionary on "one word – one meaning", and the reverse: one
  name per thing.
- Google: "If you change the name of a variable midway through a method, your code won't
  compile."

The inverse holds too: one word keeps one meaning. A text that uses "deploy" for both the
build step and the release step has two things under one name.

Test: list the key concepts. Search the text for every name each one goes by. Each concept
ends with one name, and each name with one concept.

## Defining at first use

Pinker's curse of knowledge is "the failure to understand that other people don't know what we
know". Its visible symptom is the term the writer uses daily and the reader has never seen:
internal names, abbreviations, project jargon.

For each term the declared reader may not know:

- Define it in the sentence where it first appears, in words the reader knows, or link to its
  definition.
- Prefer describing what the thing is over what the writer uses it for. "The ledger, a
  Postgres table holding every balance change" beats "the ledger, which we use for audits".
- Expand an abbreviation at first use, unless the declared reader uses it daily.

## Removing second readings

Clements et al., rule 3: "Ambiguity occurs when documentation can be interpreted in more than
one way and at least one of those ways is incorrect."

Test: for each sentence that tells the reader what to do or what is true, write the second
reading. If a reader could plausibly hold it, rewrite until only one reading remains. Common
sources:

- A modifier far from what it modifies. Strunk rule 16: "Modifiers should come, if possible,
  next to the word they modify."
- A noun stack. ASD-STE100 caps noun clusters at three nouns; "database connection pool
  timeout setting" has four and can be read several ways.
- A negation with unclear scope. "All requests are not retried" can mean none are or some
  are not.
- A relative clause that could attach to two nouns.
