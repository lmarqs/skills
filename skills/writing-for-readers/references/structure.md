---
description: How to order a text so a reader gets the point without reading all of it: answer first, headings that summarize, one topic per paragraph, one place per fact, and an ending on the next step.
audience: Whoever organizes a text or reviews its shape with the writing-for-readers skill.
---

# Structure

Structure decides whether a reader can get the point without reading everything. Most readers
do not read everything: in Nielsen's 1997 study, "79 percent of our test users always scanned
any new page they came across" and "only 16 percent read word-by-word". A structure built for
scanners also serves the reader who reads every word, since both start at the top and both
use the headings to know where they are.

## Contents

- Answer first, at every level
- Outline before drafting
- Headings
- Paragraphs
- One place per fact
- Checking a long text for contradictions
- Lists, conditions and steps
- Ending on the next step
- Checks

## Answer first, at every level

The point comes first in the document, in each section, and in each paragraph.

- **Document.** The answer is in the first paragraph. Nielsen Norman Group's eyetracking shows
  "First lines of text on a page receive more gazes than subsequent lines", and their advice
  is to "Include the most important points in the first two paragraphs on the page." Google's
  course puts the test as: "Imagine that your peers might only read the first paragraph of your
  document."
- **Section.** The first sentence under a heading keeps the heading's promise. Williams places
  a section's point at the end of its opening paragraph at the latest.
- **Paragraph.** The first sentence states the paragraph's claim. Strunk's rule 9: "begin each
  paragraph with a topic sentence, end it in conformity with the beginning", which "enables
  [the reader] to discover the purpose of each paragraph as he begins to read it."

Answer-first is the right order for documents and agent answers because their readers have a
job to do. Thomas and Turner, who describe a "classic" essay style that withholds signposts,
set practical prose apart by that job: it exists to solve a problem for the reader.

## Outline before drafting

Write the headings first, as statements, and check that they alone answer the reader's
question. Then draft each section from its heading.

The outline is the text's macrostructure, the global level a reader builds from headings and
topic sentences. McNamara et al. raised global coherence with two signals: "adding topic
headers" and "adding macropropositions serving to link each paragraph to the rest of the text
and overall topic".

## Headings

A heading is a promise about the text beneath it. The promise holds when:

- **It is specific.** "Rollback restores the previous image" beats "Rollback". Microsoft:
  "Be as specific as you can."
- **Its first words carry the topic.** NN/g: "Start headings and subheadings with the words
  carrying most information." Read a heading cut to its first two words; the topic survives.
- **It works out of context.** NN/g: "Make sure the headline works out of context." A heading
  read alone in a table of contents still says what the section holds.
- **Its body keeps the promise.** The first sentence under it delivers what it names, and
  nothing in the section contradicts it. A heading that states "Rollback is automatic" over a
  section describing a manual command is the heading-body contradiction readers notice first.
- **It has a body.** Google: "Don't use empty headings. Make sure headings are followed by
  content." Two headings in a row with nothing between them is an empty heading.
- **It uses the reader's words.** Microsoft: "choose words they'd use themselves."

Headings read in order form the outline. Microsoft: "Think of headings as an outline."

## Paragraphs

- **One topic per paragraph.** Strunk rule 8: "one paragraph to each topic", whose object "is,
  of course, to aid the reader". Gopen and Swan: "Each unit of discourse, no matter what the
  size, is expected to serve a single function, to make a single point." Test: name the
  paragraph's topic in a few words without "and".
- **Topic sentence first.** Google: "The opening sentence is the most important sentence of
  any paragraph."
- **The ending stays on topic.** Strunk: "Ending with a digression, or with an unimportant
  detail, is particularly to be avoided."
- **Short.** Google: "Readers generally welcome paragraphs containing three to five
  sentences." Microsoft: "Three to seven lines is about the right length for a paragraph."

## One place per fact

Each fact is stated in exactly one place; other places link to it. Clements et al., rule 2:
"Each kind of information should be recorded in exactly one place." A fact stated twice gets
edited once and the two copies drift into a contradiction. In agent-written text the drift
happens within a single draft: the model restates a figure or rule in a later section with a
different value.

## Checking a long text for contradictions

Mündler et al. (2023) found self-contradictions "in 17.7% of all sentences produced by
ChatGPT", and 35.2% of them "cannot be verified using online text": only reading the text
against itself finds them. ConStory-Bench (2026), a benchmark of long generated stories, found such errors
cluster in the middle of the text.

To check:

1. List the entities the text makes claims about: components, numbers, names, defaults,
   decisions.
2. For each entity, collect every sentence that says something about it, including headings,
   captions, tables and examples.
3. Compare the claims. Any two that cannot both be true are a finding, even when one is in a
   heading and the other in a code sample.
4. Give the middle third of the text the same attention as the opening and the end.

## Lists, conditions and steps

- **Enumerations become lists.** A sentence listing three or more parallel items reads faster
  as a list. Items share grammar: Strunk rule 15, "Express co-ordinate ideas in similar form."
- **Condition before instruction.** Google: "mention the circumstance, conditions, or goal
  before you provide the instruction." "If the deploy failed, run `make rollback`" lets the
  reader skip a step that does not apply before acting on it.
- **One instruction per step.** ASD-STE100: "One instruction per sentence."
- **Nothing to remember across sections.** A section that needs a definition from an earlier
  section links to it, since a scanning reader may arrive there first. The definition itself
  stays in one place.

## Ending on the next step

The last paragraph is the second place a scanning reader lands, and it is where the reader
decides what to do. It states the decision, the action the reader takes next, or that
nothing changes. An explanation that stops at its last piece of evidence makes the reader ask
"and?"; a text that ends on a list of links or a summary of itself spends its last line on
something the reader already has. Strunk's rule for the sentence, "Place the emphatic words
of a sentence at the end", holds for the text: the end carries the thing that matters most to
the reader, which is what they do with it.

## Checks

- The first paragraph holds the answer.
- The last paragraph gives the reader their next step, decision, or "nothing changes".
- The headings, read alone and in order, form a correct summary.
- Every heading is specific, leads with its topic word, has a body, and is kept by its body.
- Every paragraph has one topic, stated first.
- Every fact appears once; other mentions link to it.
- No two statements about the same entity conflict, middle sections included.
- Enumerations are lists; conditions precede the instruction they govern.
