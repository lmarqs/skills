# Sentences

A good sentence reads the way a clear person talks: someone does something, in words the
listener knows, and the sentence stops when the point is made. Jason Fried describes the
pattern every writer has seen: someone struggles to explain an idea, then says it plainly in
one sentence, then writes something more complicated. The plain spoken sentence was the right
one. This reference turns that instinct into checks.

## Contents

- Actors as subjects, actions as verbs
- When the passive is right
- Concrete words
- Cutting
- Hedges and conditions
- Sentences about the document
- Writer and reader as equals
- Length
- Reading aloud
- Where the sources disagree
- Checks

## Actors as subjects, actions as verbs

Williams' central observation is that readers expect the main character of a sentence in its
subject and the main action in its verb. A sentence is hard when it hides either.

- **The action is a noun.** "The implementation of caching resulted in a reduction of
  latency." The actions are *implement* and *reduce*. Rewrite with the actor as subject and
  the action as verb: "We added caching and latency dropped." Zinsser: "Nouns that express a
  concept are commonly used in bad writing instead of verbs that tell what somebody did."
- **The actor is missing or buried.** "A decision was made to deprecate the endpoint." Who
  decided? Name them when the reader needs to know.
- **The verb is empty.** Orwell called phrases like "render inoperative", "give rise to" and
  "make contact with" verbal false limbs: "These save the trouble of picking out appropriate
  verbs and nouns." Each collapses to one verb.

Test: underline the subject and verb of each clause. The subject names who or what acts; the
verb names the act. A noun ending in -tion, -ment or -ance next to *is*, *occurs* or *takes
place* usually hides the real verb.

A nominalization earns its place when it refers back to the previous sentence ("This
decision…"), names a concept the reader already treats as a thing ("the migration"), or
replaces an awkward "the fact that".

## When the passive is right

Strunk (rule 10) and Orwell ("Never use the passive where you can use the active") give the
default. Williams gives the exceptions, and a flagged passive stays when one of them holds:

- The actor is unknown or self-evident: "The file was deleted at 03:12."
- The passive replaces a long subject with a short one.
- The passive keeps the topic string: the sentence stays about the same thing as its
  neighbours.

For instructions, use the imperative: "Install the component", rather than "The component
must be installed". ASD-STE100 explains the choice: write "the kind of language that we would
use if we were standing next to the mechanic doing the job."

## Concrete words

Strunk rule 12: "Prefer the specific to the general, the definite to the vague, the concrete to
the abstract." Replace each vague word with the value it stands for:

| Vague | Concrete |
|---|---|
| "a number of services" | "four services" |
| "recently" | "on 3 November" |
| "improved performance" | "p95 latency fell from 800 ms to 120 ms" |
| "the appropriate team" | "the billing team" |

Orwell's rules cover the rest: "Never use a long word where a short one will do", and "Never
use a foreign phrase, a scientific word or a jargon word if you can think of an everyday
English equivalent." His per-sentence questions make a usable editing pass: "What am I trying
to say? What words will express it? … Could I put it more shortly?"

Stock phrases deserve their own pass. Orwell: ready-made phrases "will construct your sentences
for you – even think your thoughts for you". A phrase that arrived without being chosen ("at
the end of the day", "moving forward", "a key consideration") is rewritten from what it means.

## Cutting

Strunk rule 13: "A sentence should contain no unnecessary words, a paragraph no unnecessary
sentences". Zinsser: "Most first drafts can be cut by 50 percent without losing any
information or losing the author's voice." NN/g measured the effect on web text: a concise
version scored 58 percent better than the original on their usability measure.

The test is deletion. Remove a word, sentence or paragraph and reread. If the reader loses
nothing, the deletion stays. Basecamp's version: "Occasionally pick random words, sentences,
or paragraphs and hit delete. Did it matter?"

Typical cuts:

- Words the verb or noun already implies: Zinsser, "there's no other way to clench teeth" than
  tightly.
- Qualifiers: "a bit", "sort of", "rather", "quite", "somewhat". Zinsser: "Be confused."
- Intensifiers: "very", "really", "extremely", "critical", "key".
- A closing sentence that restates the paragraph.

Williams adds a limit: cut until the prose would turn cryptic, then stop.

## Hedges and conditions

A hedge that names when the claim fails is information; keep it and make the condition
explicit. A hedge that only signals the writer's discomfort is noise; delete it. Pinker: the
writer can "qualify the statement, that is, spell out the circumstances in which it does not
hold".

| Process hedge | Stated condition |
|---|---|
| "This should probably work in most cases." | "This works for tables under 10 million rows; larger tables time out." |
| "It seems the cache may be the cause." | "The cache is the likely cause: errors stop when it is disabled. Not yet confirmed in production." |

When a claim is unverified, say that once, plainly, and say what would verify it.

## Sentences about the document

A sentence whose subject is the text itself ("This section will discuss…", "As mentioned
above…", "It is worth noting that…") spends the reader's attention on the writer's process.
Pinker: "metadiscourse is there to help the writer, not the reader." Replace each with the
content it announces. Headings already tell a scanning reader where they are.

## Writer and reader as equals

Thomas and Turner describe the stance of clear prose: the writer has seen something and shows
it to a reader who is "competent to recognize it". Words that talk down ("simply",
"obviously", "just", "of course") tell a reader who is stuck that the fault is theirs. Words
that defer ("as you surely know") spend a sentence on something the reader either knows or
does not. Both go.

## Length

Sentence length is a flag, scaled to the reader:

| Text | Flag sentences over |
|---|---|
| Procedures and steps | 20 words (ASD-STE100) |
| Explanatory text for a general or mixed audience | 15 to 20 words (NN/g) |
| Explanatory text for experts | 25 words (ASD-STE100 descriptive limit) |

A long sentence that passes the subject-verb test and has one point can stay. Strunk does not
require short sentences, only that "every word tell."

## Reading aloud

Thomas and Turner: clear prose "can be read aloud properly the first time" and "never requires
the reader to look forward or backward". Read the text aloud once, in order. A sentence that
you stumble on, that you would never say, or that only makes sense after the next one gets
rewritten.

## Where the sources disagree

- **Rules versus effect.** Strunk, Orwell and ASD-STE100 give rules; Williams says "Clarity is
  not a property of sentences but an impression of readers." Use the rules to find candidates
  and the reader's effect to decide. A flagged passive that keeps the topic string stays.
- **Signposts.** Classic style refuses them; NN/g measured that scannable layout improved
  usability by 47 percent. Documents and answers serve readers with a job, so headings and
  summaries stay, and the sentences inside a section still speak about the subject, never
  about the document.
- **Voice.** Zinsser tells writers to write for themselves. He means voice: the author's
  attitude and personality stay. Clarity for the reader is a separate check, and it is the one
  a review makes.

## Checks

- Each clause names its actor as subject and its action as verb.
- Each passive is justified by an unknown actor, a shorter subject or the topic string.
- Instructions are imperatives.
- Vague quantities and times are replaced with values.
- No stock phrase, false limb or jargon word where an everyday word fits.
- Each word, sentence and paragraph survives the deletion test.
- Each hedge is a stated condition or is gone.
- No sentence has the document as its subject.
- No "simply", "obviously", "just", "of course".
- Sentences over the length flag for this reader are split or justified.
- The text reads aloud once, in order, without stumbling.
