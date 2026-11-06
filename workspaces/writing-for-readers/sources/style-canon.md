# Style canon: checkable criteria for reader-centered prose

Date: 2026-11-06

## Question

What objective, checkable criteria for good reader-centered prose do Strunk, Orwell, Thomas & Turner (with Pinker), Zinsser, Williams, Nielsen Norman Group, Basecamp/37signals and ASD-STE100 give, and which of them a reviewer can test on a Markdown doc, spec, README or agent chat answer?

## Answer

The sources converge on a short set of testable properties. Structure: the point comes first (NN/g inverted pyramid; Williams' point sentence at the end of the introduction; Zinsser's lead; Shape Up's problem-first pitch; STE's condition-before-command). Unit: one topic per paragraph with the topic sentence first (Strunk 8-9; NN/g; STE unverified rule 6.x; Zinsser's unity). Sentence: the character is the subject and the action is the verb, familiar information first, the new or stressed item last (Williams; Strunk 18; STE 3.6-3.7). Words: concrete, short, one meaning, no jargon the reader lacks (Strunk 12-13; Orwell ii, iii, v; NN/g plain language; Basecamp "don't use internal lingo"; STE dictionary). Stance: the writer presents what the reader cannot yet see and does not write about the writing (Thomas & Turner; Pinker's metadiscourse and curse of knowledge), while the practical reader with a job needs headings and answer-first structure (Thomas & Turner on practical style; NN/g measured +124 percent usability when text became concise, scannable and objective at once). Each criterion below has a one-line test, its source and the rule number or URL.

Verification legend: **[V]** verified against the primary text or official page; **[S]** confirmed only through secondary quotation of the primary text; **[U]** unverified or paraphrase.

---

## 1. Strunk, The Elements of Style (1918)

What it is: a 1918 handbook of 18 numbered rules (plus matters of form and misused words). Public domain; Project Gutenberg #37134 (https://www.gutenberg.org/ebooks/37134). Rules 1-7 are "Elementary Rules of Usage" (grammar and punctuation); rules 8-18 are "Elementary Principles of Composition" (reader-facing). All quotations below [V] from the Gutenberg text.

Grammar rules (1-7), not reader criteria: 1 possessive singular; 2 serial comma; 3 parenthetic commas; 4 comma before co-ordinate conjunction; 5 no comma splice; 6 no sentence fragments; 7 opening participial phrase refers to the subject. Rule 7 is the only one of these with a reader consequence (a dangling participle makes the reader attach the phrase to the wrong noun).

Composition rules (8-18), reader criteria:

| # | Rule (exact) | Checkable criterion | Test |
|---|---|---|---|
| 8 | "Make the paragraph the unit of composition: one paragraph to each topic." Source states the reason: "The object of treating each topic in a paragraph by itself is, of course, to aid the reader." | Each paragraph covers one topic. | Name the topic of each paragraph in three words; if you need "and", split. |
| 9 | "As a rule, begin each paragraph with a topic sentence, end it in conformity with the beginning." "The practice here recommended enables him to discover the purpose of each paragraph as he begins to read it." "Ending with a digression, or with an unimportant detail, is particularly to be avoided." | First sentence states the paragraph's claim; last sentence does not wander. | Read only first sentences: do they summarize the document? |
| 10 | "Use the active voice." "The active voice is usually more direct and vigorous than the passive." | Agent is the grammatical subject unless the agent is unknown or irrelevant. | Find "was/is/be + participle"; ask who does it; if known, rewrite. |
| 11 | "Put statements in positive form." "Make definite assertions." "Use the word _not_ as a means of denial or in antithesis, never as a means of evasion." | Statements say what is, not what is not. | Flag "not", "no", "never" used as hedges rather than denials. |
| 12 | "Use definite, specific, concrete language." "Prefer the specific to the general, the definite to the vague, the concrete to the abstract." "the surest method of arousing and holding the attention of the reader is by being specific, definite, and concrete." | Nouns name things, numbers are numbers. | Flag "some", "various", "appropriate", "a number of"; can a value, name or example replace each? |
| 13 | "Omit needless words." "Vigorous writing is concise. A sentence should contain no unnecessary words, a paragraph no unnecessary sentences ... but that he make every word tell." "In especial the expression _the fact that_ should be revised out of every sentence in which it occurs." | Every word changes meaning. | Delete each candidate word; if meaning holds, keep the deletion. |
| 14 | "Avoid a succession of loose sentences." | Not every sentence is "X, and Y, which Z". | Count consecutive compound sentences joined by and/but/which. |
| 15 | "Express co-ordinate ideas in similar form." "expressions of similar content and function should be outwardly similar." | Lists and parallel clauses share grammar. | Read list items as one sentence each; same part of speech first? |
| 16 | "Keep related words together." "The position of the words in a sentence is the principal means of showing their relationship." "Modifiers should come, if possible, next to the word they modify." | Modifier is adjacent to the modified word; subject near verb. | Count words between subject and verb; between relative pronoun and antecedent. |
| 17 | "In summaries, keep to one tense." | One tense per summary. | Tense check within each summary paragraph. |
| 18 | "Place the emphatic words of a sentence at the end." "applies equally to the words of a sentence, to the sentences of a paragraph." | The new or important item is last in the sentence. | Read the final word of each sentence; is it the point? |

Rule 9 also lists how a topic sentence may be developed: "by restating it in other forms, by defining its terms, by denying the contrary, by giving illustrations or specific instances; he may establish it by proofs; or he may develop it by showing its implications and consequences." [V] This is a checklist for what a paragraph body may legitimately contain after its topic sentence.

Reader vs grammar: rules 8, 9, 12 and 13 state the reader as the reason ("to aid the reader", "attention of the reader"); 10, 11, 14, 15, 16, 18 are stated as vigor and clarity rules without naming the reader (inference: they are reader criteria in effect); 1-7 and 17 are correctness.

---

## 2. Orwell, "Politics and the English Language" (1946)

What it is: an essay; official text at https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/politics-and-the-english-language/. All quotations [V] from that page.

Six rules (exact):

1. "Never use a metaphor, simile or other figure of speech which you are used to seeing in print."
2. "Never use a long word where a short one will do."
3. "If it is possible to cut a word out, always cut it out."
4. "Never use the passive where you can use the active."
5. "Never use a foreign phrase, a scientific word or a jargon word if you can think of an everyday English equivalent."
6. "Break any of these rules sooner than say anything outright barbarous."

Four "swindles and perversions" (Orwell's section headings), with the test each implies:

| Fault | Orwell's statement | Test |
|---|---|---|
| Dying metaphors | "a huge dump of worn-out metaphors which have lost all evocative power"; a fresh metaphor "assists thought by evoking a visual image". | For each figure of speech: can the reader picture it? If it is a stock phrase, delete or replace with the literal statement. |
| Operators, or verbal false limbs | "These save the trouble of picking out appropriate verbs and nouns." "The keynote is the elimination of simple verbs." | Flag "render inoperative", "make contact with", "play a leading part in", "be subjected to", "give rise to"; replace with one verb. |
| Pretentious diction | words "used to dress up simple statements and give an air of scientific impartiality to biassed judgements". | Flag Latinate or foreign terms with everyday equivalents (rule v). |
| Meaningless words | words "strictly meaningless, in the sense that they not only do not point to any discoverable object". | For each evaluative word, ask what observation would contradict it; none means delete. |

Questions "a scrupulous writer" asks "in every sentence" (exact): "What am I trying to say? What words will express it? What image or idiom will make it clearer? Is this image fresh enough to have an effect?" and "Could I put it more shortly? Have I said anything that is avoidably ugly?"

Stance rules: "What is above all needed is to let the meaning choose the word, and not the other way about." "In prose, the worst thing one can do with words is to surrender to them." Prefabricated prose "consists in gumming together long strips of words which have already been set in order by someone else"; ready-made phrases "will construct your sentences for you – even think your thoughts for you, to a certain extent"; "every such phrase anaesthetizes a portion of one's brain."

Test for prefabrication (inference): mark every run of four or more words you have seen in that order elsewhere; rewrite each from the meaning.

Motivating failures addressed: writing from the author's head rather than the reader's (meaning chooses the word; "What am I trying to say?"); examples that import irrelevant detail (dying metaphors evoke the wrong image).

---

## 3. Thomas & Turner, Clear and Simple as the Truth (1994; 2nd ed. 2011), and Pinker, The Sense of Style ch. 2

What it is: a theory of prose styles; classic style is defined against reflexive, practical, plain, contemplative, romantic, prophetic and oratorical styles. Second edition: Princeton University Press, 2011, 272 pp., four parts "Principles of Classic Style", "The Museum", "The Studio", "Further Readings in Classic Prose" [V, https://press.princeton.edu/books/paperback/9780691147437/clear-and-simple-as-the-truth]. Publisher's description [V]: "In classic style, the motive is truth, the purpose is presentation, the reader and writer are intellectual equals". Authors' excerpt page [V, http://classicprose.com/csx.html].

Classic style, criteria (exact quotes from the authors' excerpt page unless marked):

| Criterion | Source statement | Test |
|---|---|---|
| The prose presents; it does not argue for itself. | "its purpose is presentation; its motive is disinterested truth." "truth needs no argument but only accurate presentation" [V csx.html] | Remove every sentence that asserts the text's own value ("importantly", "it is worth noting"); nothing is lost. |
| Prose is a window on the subject. | "writing can be an undistorting window on its subject." [V csx.html]; Pinker: "prose is a window onto the world" and "The writer can see something that the reader has not yet noticed, and he orients the reader's gaze" [S, quoted at https://mindblog.dericbownds.net/2015/01/steven-pinkers-sense-of-style.html and in comments at https://www.lesswrong.com/posts/h8ZBxrBoSEtvpKc94/against-classic-style] | Each sentence is about the subject, not about the document, the writer, or the reader's reading process. |
| Writer and reader are equals; the text is a conversation. | "the symmetry between writer and reader allows the presentation to follow the model of conversation" [V csx.html]; Pinker: "The writer and the reader are equals" [S] | No condescension ("simply", "obviously") and no deference ("as you surely know"). |
| Order follows the subject, not the writer's discovery. | "the order of his presentation follows the order of truth, not of sensation" [V csx.html] | The document's order is the structure of the thing, not the order in which the author found it out. |
| Readable once, aloud, in order; no forward or backward reference. | p. 37: "Classic style models itself on speech and can be read aloud properly the first time." "it never requires the reader to look forward or backward". "Each phrase is presented as if it has only one chance—now—to do its job." [S, quoted with page numbers at https://www-users.york.ac.uk/~ss44/books/pages/t/FrancisNoelThomas.htm] | Read aloud once; every sentence is understood at the moment it ends, without a later sentence. |
| No hedges of process; no display of difficulty. | "It declines to acknowledge ambiguities, unessential qualifications, doubts, or other styles." [V csx.html]; "The writer hides all the effort." (p. 15) [S York]; "It excludes hedges of process: hesitations and uncertainties that arise because one is in the middle of thought." [S, https://www.stafforini.com/blog/summary-of-clear-and-simple-as-the-truth, summary that reproduces the book's wording without quotation marks] | Flag "I think", "it seems", "perhaps", "to some extent", "we tried to"; each is either a genuine qualification (keep, and state the condition) or a hedge (delete). |
| The reader is competent to verify. | "the reader will be competent to recognize it." [V csx.html]; "The silent convention is that a competent reader who had seen the evidence would have made the same decision." [S stafforini] | The text shows the evidence instead of asserting the conclusion's authority. |

Classic vs practical style (the distinction technical documentation needs):

- Thomas & Turner on practical style [S, quoted at https://www.3quarksdaily.com/3quarksdaily/2019/06/clear-and-simple-prose.html]: "Why else would anyone presume to take up a reader's time than to solve a problem for the reader?" Reviewers' paraphrase [U verbatim, consistent across York review, 3QD, Stafforini]: practical style assumes the writer conveys knowledge the reader needs for an instrumental purpose (learn a skill, prepare for a meeting, make a decision); the reader is busy and has a job; the writer and reader both have a job. "In classic style, by contrast, neither writer nor reader has a job" [S stafforini]. The York review paraphrases that classic prose "cannot be skim-read" whereas practical prose is built to be [U].
- Thomas & Turner name the teachers of practical style: p. 78 "The best teachers of practical style are Joseph Williams and Gregory Colomb"; p. 67 "What Strunk and White recommend is meant as good advice for the one style they have in mind" [S York].
- Pinker ch. 2 names practical style as "the language of memos, manuals, term papers, and research reports" [S, https://bernoff.com/blog/the-sense-of-style-by-steven-pinker-a-worthwhile-writing-guide].
- Consequence for this skill (inference from the above): Markdown docs, specs, READMEs and agent answers are practical-style artifacts: the reader has a problem and may not read in order, so headings, summaries and answer-first ordering are correct there even though classic style refuses them. Thomas & Turner say the choice of style is a choice, and the reader's job is the deciding fact.

Pinker's additions (ch. 2 and ch. 3), each [S] unless marked:

| Fault | Pinker's statement | Test |
|---|---|---|
| Metadiscourse | "metadiscourse is there to help the writer, not the reader" [S, quoted from the Chronicle adaptation at https://archive.blogs.harvard.edu/pamphlet/2014/09/29/inaccessible-writing-in-both-senses-of-the-term/]; example he condemns: "The preceding discussion introduced the problem of academese, summarized the principle theories" | Flag sentences whose subject is the document ("this section", "the preceding discussion", "we will now"). Keep only those that route a reader who is skipping. |
| Signposting | "Like all writing decisions, the amount of signposting requires judgement and compromise:" [S lesswrong comments] | A signpost earns its place when the reader needs it to navigate; not as a ritual opener. |
| Hedging vs qualifying | "Sometimes a writer has no choice but to hedge a statement." "Better still, the writer can qualify the statement, that is, spell out the circumstances in which it does not hold," [S lesswrong comments] | Replace each hedge with the condition under which the claim fails, or delete it. |
| Curse of knowledge | ch. 3; Pinker calls it the main cause of incomprehensible prose [U exact wording; page numbers in summaries disagree, 57-61]. Remedies reported by summaries: picture a specific unfamiliar reader; expand abbreviations; define jargon; show a draft to a representative reader [U]. | For each term, abbreviation and assumed fact: would the named reader know it on first encounter? If not, define it or cut it. |

Motivating failures addressed: author writes from own head (curse of knowledge; window stance); text only makes sense once read in full (read-aloud-once test, no forward reference); over-explaining to a knowing reader (equals; "no one in the field" wants hedges, per csx.html "nothing more irksome to someone in the field than a passage clotted with hedges" [V]).

---

## 4. Zinsser, On Writing Well

What it is: a nonfiction writing guide (1976; 30th anniversary ed. 2006). Chapters used: 2 Simplicity, 3 Clutter, 4 Style, 5 The Audience, 8 Unity, 9 The Lead and the Ending, 10 Bits & Pieces (chapter numbering from the 30th anniversary table of contents, cited in search results [S]). The book is copyrighted; the only verified wording comes from reader highlights with page numbers of the 30th anniversary edition at https://kobo-highlights.pages.dev/book/on-writing-well,-30th-anniversary-edition:-an-informal-guide-to-writing-nonfiction (section labels on that page are misaligned with chapters; page numbers are used here) and from LitCharts chapter summaries (paraphrase). Unofficial full-text uploads were not used.

| Criterion | Zinsser's statement | Status | Test |
|---|---|---|---|
| Strip each sentence to its cleanest components. | "But the secret of good writing is to strip every sentence to its cleanest components." (p. 19) | [S] | For each sentence: remove every word that does not carry a new function; what remains is the sentence. |
| Every word must serve a purpose. | "Examine every word you put on paper. You'll find a surprising number that don't serve any purpose." (p. 25) | [S] | Same as Strunk 13; apply per word. |
| First drafts can lose half their words. | "Most first drafts can be cut by 50 percent without losing any information or losing the author's voice." (p. 31) | [S] | Word count of draft vs edit; if the edit is above 70 percent of the draft, cut again. |
| Clutter is the disease; the writer must constantly ask what they are trying to say and whether it is clear to a first-time reader. | "Clutter is the disease of American writing." (ch. 2 opening; [S] via search snippet of an Emory course excerpt). The questions "What am I trying to say?" / "Have I said it?" / "Is it clear to someone encountering the subject for the first time?" are attributed to ch. 2 by secondary summaries. | [U] exact wording | Ask the three questions per paragraph; answer "no" to the third means rewrite. |
| Bracket the clutter. | Ch. 3 describes putting brackets around every component that is not doing useful work, so the writer sees what can go. | [U] exact wording; LitCharts paraphrase | Mark each phrase that restates, qualifies without condition, or announces; delete and reread. |
| Write for yourself, but be clear for the reader (craft vs attitude). | "You are writing for yourself. Don't try to visualize the great mass audience. There is no such audience—" (p. 34) | [S] | Two separate checks: craft (every sentence clear to a stranger) and attitude (voice is the author's). The craft check is the reviewer's. |
| Unity of pronoun, tense, mood. | Ch. 8: unity is "the anchor of good writing"; choose one pronoun, one tense, one mood and keep them [S, Sivers and LitCharts paraphrase]. | [U] exact wording | Count pronoun stance (I/we/you/one), tense and mood switches within a document; each switch needs a reason. |
| Decide the one point. | Ch. 8: before writing, decide "what one point do I want to leave in the reader's mind" [U exact]; "every successful piece of nonfiction should leave the reader with one provocative thought ... Not two thoughts, or five - just one" [S, https://sive.rs/book/OnWritingWell]. | [S]/[U] | State the document's one takeaway in one sentence; if the ending leaves a different one, fix the ending or the lead. |
| The lead captures immediately. | Ch. 9: "Your lead must capture the reader immediately and force him to keep reading." [S, search snippet of a PDF fragment]. "The most important sentence in any article is the first one." [U exact; LitCharts paraphrase agrees]. | [S]/[U] | Read sentence one alone: does it tell the reader why to read sentence two? |
| Stop when done. | Ch. 9: the ending should "take your readers slightly by surprise and yet seem exactly right" [S, secondary summary]; "when you're ready to stop, stop" [U]. | [U] | Delete the last paragraph; if nothing is lost, it was a summary the reader did not need. |
| Precise verbs over phrasal and passive. | p. 81: "'Joe saw him' is strong. 'He was seen by Joe' is weak." p. 111: "Don't say that the president of the company stepped down. Did he resign? Did he retire? Did he get fired?" | [S] | Flag vague verbs (step down, deal with, address); replace with the specific action. |
| No little qualifiers. | p. 112: "Don't say you were a bit confused and sort of tired and a little depressed and somewhat annoyed. Be confused." | [S] | Flag "a bit", "sort of", "rather", "quite", "somewhat", "in a sense". |
| No concept nouns in place of verbs. | p. 120: "Nouns that express a concept are commonly used in bad writing instead of verbs that tell what somebody did." Example (LitCharts): "the common reaction is incredulous laughter" vs "most people just laugh with disbelief". | [S] | Flag "-tion/-ment/-ance" nouns with weak verbs (is, occurs, takes place); recast as subject + verb. |
| Adjectives and adverbs must add information. | p. 112: "Don't write that someone clenched his teeth tightly; there's no other way to clench teeth." | [S] | Delete each modifier; if the noun or verb already implies it, keep the deletion. |

Motivating failures addressed: self-contradiction within a document (unity of pronoun/tense/mood; one point); text that only makes sense read in full (the lead; one point stated); author writing from own head (the first-time-reader question).

---

## 5. Williams, Style: Toward Clarity and Grace (1990) / Lessons in Clarity and Grace (editions through the 13th, 2021)

What it is: a lesson-structured method that explains why readers judge prose clear. Representative lesson list [V, https://en.wikipedia.org/wiki/Style:_Lessons_in_Clarity_and_Grace]: Part One Style as Choice: 1 Correctness and Style; Part Two Clarity: 2 Actions, 3 Characters, 4 Cohesion and Coherence, 5 Emphasis; Part Three Clarity of Form: 6 Framing Documents, 7 Framing Sections; Part Four Grace: 8 Concision, 9 Shape, 10 Elegance; Part Five Ethics: 11 The Ethics of Clarity, 12 Beyond Clarity. Numbering shifts between editions (the 12th edition has Actions as Lesson Three). The book is copyrighted; walled copies were not used. Verified wording comes from pin-cited quotations in a New York State Bar Association article (12th ed., 2016) [S, https://nysba.org/thoughts-on-legal-writing-from-the-greatest-of-them-all-joseph-m-williams-part-i/]; principles are otherwise paraphrased from several secondary summaries that agree.

Core claim: "Clarity is not a property of sentences but an impression of readers." (12th ed. p. 35) [S]. This is the book's justification for diagnosis: look at what readers experience, not at rules.

| Lesson | Principle | Diagnostic procedure | Status | Test |
|---|---|---|---|---|
| Actions | Main actions are verbs, not nominalizations. | Find the verbs; find nominalizations ("-tion", "-ment", "-ance" nouns naming actions); turn them back into verbs. Legitimate nominalizations: ones that "refer to a previous sentence", "replace an awkward *The fact* that", "name what would be the object of a verb", or "name a concept so familiar to your readers that it is a virtual character." (pp. 41-42) [S] | principle [S]; the "underline the first seven or eight words" step is widely attributed to Williams but was not confirmed [U] | For each sentence, find the verb; if the main action is a noun, rewrite with the actor as subject and the action as verb. |
| Characters | Main characters are subjects. | Identify the characters; weak sentences lose them in one of three ways: missing, buried in possessives or prepositional phrases, or replaced by abstractions [S, https://experiencemachines.substack.com/p/the-best-book-on-writing-is-style]. "Before revising an unclear sentence, identify its grammatical subjects and verbs" [S, summary at https://www.antoinebuteau.com/lessons-from-joseph-m-williams-joseph-bizup/] | [S] | Underline the subject of each clause; is it the agent the sentence is about? Count words before the subject and before the verb (LMU teaching handout derived from Williams: "get to the subject quickly", "get to the verb quickly", with examples where the subject arrives at word 27 vs word 2 [S, https://www.tcs.ifi.lmu.de/teaching/courses-ws-2026-27/scientific-and-technical-english/ste-slides-05-sentences-and-paragraphs-handout.pdf]). |
| Passive, when legitimate | Use the passive when "the agent of an action is self-evident", when "it lets you replace a long subject with a short one", or when "it gives your readers a coherent sequence of subjects." (p. 63) [S] | | [S] | A passive passes if one of the three reasons holds; otherwise make it active. |
| Cohesion (old before new) | Begin sentences with information familiar to the reader; end with the new. | Read the start of each sentence: does it link to the previous sentence's end? [S, secondary summaries agree] | [S] | For each sentence pair, the opening of sentence n+1 refers to something already given in sentence n or earlier. |
| Coherence (topic strings) | A passage's sentences share a small set of topics in subject position. | List the subjects of a paragraph's sentences; they should form a consistent set [S] | [S] | Write the subject of each sentence in a column; more than two or three unrelated topics means the paragraph is incoherent. |
| Emphasis (stress position) | The end of the sentence carries the new or important information. | Read the last few words of each sentence [S]; matches Strunk 18 | [S] | Does each sentence end on the word the reader should remember? |
| Concision | Cut words that mean little, that repeat, that are implied, phrases replaceable by a word, needless negatives, empty intensifiers. "Delete habitual words that add little meaning" [S antoinebuteau summary]; "do not cut so aggressively that the prose becomes cryptic or graceless" [S same] | | [U] exact list | Apply each cut type per sentence; stop before meaning or tone is lost. |
| Framing documents / Global coherence | Introduction = shared context, then problem, then solution or main point; the point sentence sits at the end of the introduction; headings and openings "let readers know what to expect so that they can read more knowledgeably" and "motivate readers so that they want to read carefully." (p. 95) [S]; "Get beginnings straight, and the rest is likely to take care of itself." (p. 118) [S] | | structure [U] exact; quotes [S] | Find the sentence that states the document's point; it should be at the end of the introduction, and each section's point at the end of its opening paragraph. |
| Ethics of clarity | Name the responsible agent when the reader needs to know who acted; write for the intended reader rather than assuming they see what you see [S antoinebuteau summary]. | | [U] exact | For each consequential decision in the text, the sentence names who made it. |

Motivating failures addressed: text that assumes context (old-before-new: every sentence opens on what the reader already has); self-contradiction between heading and body (framing: the heading's promise is the section's point sentence); author's-head writing (characters and actions force the story to be explicit).

---

## 6. Nielsen Norman Group reading research

What it is: eyetracking and usability studies, 1997-2020. All quotations [V] from the cited NN/g pages.

### 6.1 "How Users Read on the Web" (1997) https://www.nngroup.com/articles/how-users-read-on-the-web/

Findings: "79 percent of our test users always scanned any new page they came across"; "only 16 percent read word-by-word". Measured usability, relative to a promotional control: concise text 58 percent better; scannable layout 47 percent better; objective language 27 percent better; "Combined version" with all three 124 percent better. Nielsen's conjecture for the objective-language gain: "promotional language imposes a cognitive burden", since users must filter hype to find facts.

Rules stated: "Highlighted keywords"; "Meaningful sub-headings (not 'clever' ones)"; "Bulleted lists"; "One idea per paragraph (users will skip over any additional ideas if they are not caught by the first few words in the paragraph)"; "The inverted pyramid style, starting with the conclusion"; "Half the word count (or less) than conventional writing".

### 6.2 "F-Shaped Pattern for Reading Web Content" (2006, updated 2017) https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/

The pattern: "many fixations concentrated at the top and the left side of the page"; "Users first read in a horizontal movement, usually across the upper part of the content area", a second shorter horizontal movement, then a vertical scan of "the content's left side". Implications: "First lines of text on a page receive more gazes than subsequent lines"; "First few words on the left of each line of text receive more fixations than subsequent words on the same line." Condition: "People scan in an F-shape when all of these 3 elements are present": little or no web formatting, the user wants to be efficient, the user is not committed to reading every word. "The F-pattern is the default pattern when there are no strong cues to attract the eyes towards meaningful information." Remedy: "Include the most important points in the first two paragraphs on the page"; "Start headings and subheadings with the words carrying most information"; use headings, bolding, bullets, grouping; cut unnecessary content; "Good web formatting reduces the impact of F-scanning."

### 6.3 "How People Read Online: New and Old Findings" (2020) https://www.nngroup.com/articles/how-people-read-online/

"People rarely read online — they're far more likely to scan than read word for word", unchanged in 23 years. Evidence base: studies "spanning 13 years, involving over 500 participants and more than 750 hours of eyetracking time". New patterns: lawn-mower (cell-structured pages) and pinball (modern search result pages). Guidelines: "clear, noticeable headings and subheadings"; "Placing information up front" (front-loading) in body, subheadings and links; "bulleted lists and bold text"; "plain language to keep content concise and clear".

### 6.4 "Inverted Pyramid: Writing for Comprehension" (2018) https://www.nngroup.com/articles/inverted-pyramid/

Definition: "the most important information (or what might even be considered the conclusion) is presented first". Benefits: "Improve comprehension", "Decrease interaction cost", "Encourage scrolling", "Structure content logically", "Support readers who skim". Method: "Identify your key points"; "Rank secondary information"; "Write well and concisely"; "Frontload all elements of content with important information"; "Consider adding a summary or list of highlights". Rule: "The first sentence of every paragraph should be the most important."

### 6.5 "Plain Language Is for Everyone, Even Experts" https://www.nngroup.com/articles/plain-language-experts/

"Professionals want clear, concise information devoid of unnecessary jargon or complex terms." "highly educated online readers crave succinct information that is easy to scan". "No one has ever complained that a text was too easy to understand." Numbers: web copy at "fewer than 50% of the words you would use in a printed publication"; "Sentences should be no more than 15–20 words"; general audience "6–8th grade reading level", experts "10–12th grade reading level"; "Text beyond the 12th grade reading level requires too much mental effort, even for highly educated people." Cites Oppenheimer (2006), Applied Cognitive Psychology 20:139-156, on needless long words. Tips: "Know your audience"; "Choose words familiar to your audience" (define technical terms the reader may not know); "Use short sentences and paragraphs" (one idea per paragraph); "Aim for a 10-12th grade reading level"; "Follow web-formatting rules for readability".

### 6.6 "Microcontent: How to Write Headlines, Page Titles, and Subject Lines" https://www.nngroup.com/articles/microcontent-how-to-write-headlines-page-titles-and-subject-lines/

"Make sure the headline works out of context." "Tell readers something useful." "Avoid teasers (click bait) to entice people to click, but don't deliver on the promise." Page titles: 40-60 characters; "Remove nonessential words to improve scannability"; "Move the keywords to the front"; skip leading articles. Subject lines: "Clearly explain what the email is about in terms that relate to the user"; "Be concise and start with keywords". Reason: "people form opinions based on headlines and summaries, without putting in the effort to dig deeper"; readers "will leave (and not return) if they get disappointed by the destination content too often".

### 6.7 "Legibility, Readability, and Comprehension" https://www.nngroup.com/articles/legibility-readability-comprehension/

Three levels: legibility ("whether people are able to see, distinguish, and recognize the characters and words"), readability ("the complexity of the words and sentence structure"), comprehension ("whether a user can understand the intended meaning of a text"). Readability: "Use plainspoken words, the shorter the better"; short sentences; active voice. Comprehension: "terms familiar to your audience facilitate comprehension"; for specialists, use the field's terminology even if readability scores drop; lead with the conclusion; build on familiar mental models; minimize what the reader must remember between sections; use a diagram where it explains better; keep copy brief.

NN/g criteria and tests:

| Criterion | Test |
|---|---|
| Conclusion first (page, section, paragraph, sentence). | Cover everything after the first two paragraphs: is the main point already delivered? |
| One idea per paragraph; the first sentence is the most important. | Read first sentences only; do they tell the story? |
| Headings carry information in their first two words and work out of context. | Read each heading alone, truncated to two words; is the section's topic recoverable? |
| Half the words of print. | Word count vs the print-equivalent draft. |
| Sentences at most 15-20 words. | Count; flag longer ones. |
| Reading level 10-12 for experts, 6-8 for general readers. | Run a readability formula. |
| Terms familiar to the audience; technical terms defined where the reader may not know them. | For each term: in the audience's vocabulary, or defined at first use? |
| Objective language; no promotional claims. | Flag superlatives and unsupported evaluations. |
| Nothing to remember across sections. | For each section: does it depend on a definition or state from an earlier section without restating or linking it? |

Motivating failures addressed: text that only works read in full (front-loading, F-pattern); heading/body mismatch (headlines must deliver on the promise); over-explaining to experts (plain language for experts, but their terminology).

---

## 7. Basecamp / 37signals

### 7.1 Getting Real (2006)

Ch. 52 "Copywriting is Interface Design" [V, https://basecamp.com/gettingreal/09.7-copywriting-is-interface-design]: "If you think every pixel, every icon, every typeface matters, then you also need to believe every letter matters." "Copywriting is interface design." Questions to ask: "What do they need to know?" "How you can explain it succinctly and clearly?" Rules: "Don't use acronyms or words that most people don't understand." "Don't use internal lingo." "Don't sound like an engineer talking to another engineer." "Keep it short and sweet." "Say what you need to and no more." Scope: "Icons with names, form fields with examples, buttons with labels", "a clear explanation of your refund policy"; "Do you label a button Submit or Save or Update or New or Create?"

Ch. 51 "Context Over Consistency" [V, https://basecamp.com/gettingreal/09.6-context-over-consistency]: what belongs on a page depends on what the user needs there; "intelligent inconsistency" (credited to Mark Hurst); "It's better to be right than to be consistent."

Ch. 45 "Wordsmiths" [V summary, https://basecamp.com/gettingreal/08.6-wordsmiths]: hire the better writer; good writers "know what to leave out", can see things from others' perspectives; quotes Michael A. Covington, "Clear writing leads to clear thinking."

Ch. 59 "There's Nothing Functional about a Functional Spec" [V summary, https://basecamp.com/gettingreal/11.1-theres-nothing-functional-about-afunctional-spec]: specs "create an illusion of agreement" because people sign off on the same words while imagining different things; alternative is a one-page plain-language story written in a day or less.

Ch. 61 "Tell Me a Quick Story" [V, https://basecamp.com/gettingreal/11.3-tell-me-a-quick-story]: explain a feature as a brief story told the way you would in conversation; "Stick to the experience instead of getting hung up on the details."

Ch. 62 "Use Real Words" [V summary, https://basecamp.com/gettingreal/11.4-use-real-words]: no lorem ipsum; real copy exposes real length and meaning.

### 7.2 "The Basecamp Guide to Internal Communication" [V, https://basecamp.com/guides/how-we-communicate]

Writing-relevant rules (numbered as on the page): 6 "Writing solidifies, chat dissolves." "If it's important, critical, or fundamental, write it up, don't chat it down." 7 "Speaking only helps who's in the room, writing helps everyone." 8 "If your words can be perceived in different ways, they'll be understood in the way which does the most harm." 10 "If you have to repeat yourself, you weren't clear enough the first time." 11 "Poor communication creates more work." 14 "Be proactive about 'wait, what?' questions by providing factual context and spatial context." 20 "Occasionally pick random words, sentences, or paragraphs and hit delete." "Did it matter?" 23 "Where you put something, and what you call it, matters." "When titling something, lead with the most important information." "Keep in mind that many technical systems truncate long text or titles." 27 "Communication is lossy, especially verbal communication." 28 "Ask if things are clear." "Ask what you left out." "Ask if there was anything someone was expecting that you didn't cover." 29 "The right communication in the wrong place might as well not exist at all."

### 7.3 Shape Up, ch. 6 "Write the Pitch" [V, https://basecamp.com/shapeup/1.5-chapter-06]

Five ingredients: Problem ("The raw idea, a use case, or something we've seen that motivates us to work on this"), Appetite, Solution ("presented in a form that's easy for people to immediately understand"), Rabbit holes, No-gos ("Anything specifically excluded from the concept"). "The best problem definition consists of a single specific story that shows why the status quo doesn't work." Without a problem "there's no test of fitness to judge whether one solution is better than the other." "We need to stay high level, but add a little more concreteness than when we worked alone or with a partner." "we don't want to over-specify the design with wireframes or high-fidelity mocks." Hand-drawn breadboards look like "a soup of words and arrows" to people who did not see them made. 37signals podcast "Writing a Pitch" [V, https://37signals.com/podcast/writing-a-pitch/]: a pitch is "around 800 words or so"; a six-page pitch "turns it into a spec".

### 7.4 Jason Fried, "Then just say it like that!" (HEY World, 2023-10-18) [V summary, https://world.hey.com/jason/then-just-say-it-like-that-3fe992bb]

Observation: people struggle to explain something, then state it clearly in one plain sentence, then overcomplicate it again; his spoken home-page copy was better than what he "doctored" up for marketing; "work on being better listeners when we're talking." No post titled "Write like you talk" was found; Rework's chapter "Sound Like You" exists [V title via https://37signals.com/podcast/sound-like-you/] but its text was not verified [U].

Basecamp criteria and tests:

| Criterion | Test |
|---|---|
| The reader's need decides the words. | For each paragraph or label: what does this reader need to know here? Delete the rest. |
| No internal lingo, acronyms, engineer-to-engineer phrasing. | Every term passes the "most people" test or is defined. |
| Ambiguity resolves to harm; remove it. | For each sentence, find a second reading; if one exists, rewrite. |
| Context first (factual and spatial). | Does the text say what it is about and where it applies before the reader has to ask "wait, what?" |
| Title leads with the most important information, survives truncation. | Truncate the title to its first three words; still informative? |
| Random-delete test. | Delete a paragraph; if nobody would notice, it goes. |
| Problem before solution, as one specific story; no-gos stated. | A spec or pitch names the problem with one concrete case, and lists what is out of scope. |
| Say it the way you would say it aloud. | Read aloud; a sentence you would not say is rewritten. |

---

## 8. ASD-STE100 Simplified Technical English

What it is: a controlled language standard owned by ASD (Aerospace, Security and Defence Industries Association of Europe), maintained by the STEMG. Official site https://asd-ste100.org (home, https://asd-ste100.org/about_STE.html, https://asd-ste100.org/faq.html; all quotations below [V] from those pages via direct fetch). The specification is free but registration-gated ("Request your free official copy"); the Zenodo record linked from the site (https://doi.org/10.5281/zenodo.23666005, CC BY-NC-ND 4.0) returned 403 during this research, so the rule text itself was not read.

Structure [V]: "The STE standard consists of a set of writing rules and a controlled dictionary." Part 1, writing rules: "53 writing rules in 9 sections that focus on word choice, grammar, sentence structure, and style." Part 2, dictionary: "approximately 900 words, each with one meaning and one part of speech" plus "a list of words that are not approved (approximately 1200) with related alternative suggestions." Principle: "one word – one meaning"; example: "start" instead of "begin", "commence", "initiate", or "originate"; "to fall" means "to move down by the force of gravity", not "decrease". Company terms are allowed as technical nouns and technical verbs. Current issue: Issue 9, January 15, 2025 (the FAQ page still describes Issue 8, April 30, 2021). Issue 9 refined wording in 31 of the 53 rules and added no rules [V, https://www.asd-europe.org/news-media/news-events/news/simplified-technical-english-asd-ste100-issue-9].

Purpose [V]: "to help the users of English-language maintenance documentation understand what they read"; readers "with only a basic command of English"; "Complex technical instructions can be misunderstood, and misunderstandings can lead to accidents." On general use [V FAQ]: "It is not a language that you can use for 'general' writing, for example international correspondence. However, its basic principles (for example, short sentences, one topic per sentence, active voice etc., can be easily adopted." About page: "used well beyond its original purpose of maintenance documentation and outside the aerospace and defense domains." FAQ on writing: "STE was created for the maximum benefit of the reader. This does not necessarily mean it is simple to write." Writers must "Be able to structure thoughts and ideas logically and understand your reader's needs." On passives in procedures [V FAQ]: "we use the kind of language that we would use if we were standing next to the mechanic doing the job"; "Install the component" rather than "The component must be installed." On conditions [V FAQ]: a condition the operator must know before the step goes "at the beginning of the sentence" ("If hot oil touches your skin, it can cause burns."). On reading levels [V FAQ]: "STE does not guarantee compliance with reading grade levels."

Headline rules with numbers. The official pages do not print rule numbers or limits, so numbers and limits below are [S] from the TechScribe term-checker rule list for Issue 8 (https://simplified-english.co.uk/rules-ste8.html) and Wikipedia (https://en.wikipedia.org/wiki/Simplified_Technical_English); treat them as unverified against the standard and note that Issue 9 reworded 31 rules.

| Rule | Statement (Issue 8 summary wording) | Status |
|---|---|---|
| 1.1 | "Use approved words from the dictionary, technical names (TNs), and technical verbs (TVs)." | [S] |
| 1.3 | "Use an approved word only with its approved meaning." | [S] |
| 1.11 | "Do not use different technical names for the same thing." | [S] |
| 2.1 | "Write noun clusters of not more than 3 nouns." | [S]; Wikipedia: "Do not write multi-word nouns that have more than three words." |
| 3.4 | "Do not use helping verbs to make complex verb structures." | [S] |
| 3.6 | "Use only the active voice in procedural writing. Use the active voice as much as possible in descriptive writing." | [S]; FAQ confirms the principle [V] |
| 3.7 | "Use an approved verb to describe an action (not a noun or other part of speech)." | [S] |
| 4.1 | "Write short and clear sentences." | [S] |
| 4.3 | "Use a vertical list for complex text." | [S] |
| 4.4 | "Use connecting words and phrases to connect sentences that contain related topics." | [S] |
| 5.1 | "Write short sentences." Limit: 20 words per sentence in procedures. | number [S] Wikipedia and third-party lists |
| 5.2 | "Write only one instruction in each sentence unless two or more actions occur at the same time." | [S]; ASD "basics" page states "One instruction per sentence" [V, https://www.asd-europe.org/standards-specifications/simplified-technical-english/what-are-the-basics-of-simplified-technical-english] |
| 5.3 | "Write instructions in the imperative (command) form." | [S] |
| 6.x | Descriptive text: 25 words per sentence; one topic per paragraph; no more than six sentences per paragraph; give information gradually, one new fact per sentence. | [S]/[U]: Wikipedia gives the 25-word and six-sentence limits; rule numbers 6.1, 6.3, 6.5, 6.6 appear only in third-party lists |
| 7.2 | "Start a safety instruction with a clear and simple command or condition." | [S] |
| 9.3 | "When you use two words together, do not make phrasal verbs." | [S] |
| 9.4 | "When you select terminology or wording, always use a consistent style." | [S] |

Transfer to general reader-centered prose (inference, grounded in the FAQ's own list "short sentences, one topic per sentence, active voice"):

- Transfer directly: one meaning per word within a document and one word per meaning (1.3, 1.11, 9.4); no noun clusters over three nouns (2.1); action as verb (3.7); short sentences with a numeric ceiling (4.1, 5.1, 6.x: 20-25 words, which matches NN/g's 15-20); one instruction per sentence (5.2); imperative for instructions (5.3); condition before command (7.2, FAQ); one topic per paragraph with a paragraph ceiling (6.x); vertical lists for complex text (4.3); connectors between related sentences (4.4, which is Williams' cohesion).
- Aerospace-maintenance specific: the closed dictionary of about 900 words and the ban on unapproved words (1.1, 1.6); American spelling (1.14); the ban on "-ing" forms and helping-verb tenses (3.2-3.5); no semicolons (8.1); word-count conventions for parentheses and hyphenated words (8.4-8.7); safety-word levels (7.1); the requirement itself (ATA iSpec 2200, S1000D, EASA/FAA directives).

Tests: word count per sentence (20 in procedures, 25 in description); nouns in a row (max 3); one imperative per step; same term for the same thing throughout (grep for synonyms); paragraph sentence count (max 6); condition precedes the command it governs.

Motivating failures addressed: assumed context (one word one meaning removes the reader's guesswork); examples importing irrelevant detail (one instruction per sentence; one new fact per sentence); self-contradiction (consistent terminology, 1.11 and 9.4).

---

## Consolidated table

| Criterion | Test | Sources | Motivating failure addressed |
|---|---|---|---|
| The point comes first: document, section, paragraph, sentence. | Cover all but the first two paragraphs (or first sentence of each paragraph); the main point is already delivered. | NN/g inverted pyramid, F-pattern; Williams point sentence at end of introduction; Zinsser lead; Strunk 9; Basecamp 23 (titles lead with the most important information); STE 7.2 condition first | Text only makes sense once read in full |
| One topic per paragraph; first sentence states it; last sentence does not digress. | Read first sentences only; they summarize the document. Name each paragraph's topic in three words. | Strunk 8-9; NN/g 1997 and 2018; STE 6.x [S]; Zinsser unity | Text that only makes sense read in full; heading/body mismatch |
| Heading promises exactly what the body delivers, in its first two words, out of context. | Read each heading alone, truncated to two words; recover the section's point; compare with the section's point sentence. | NN/g microcontent and F-pattern; Williams framing (p. 95); Basecamp 23 | Self-contradiction between heading and body |
| Every sentence opens on what the reader already has and ends on the new item. | For each sentence pair, the opening of n+1 is given in n or earlier; the last words of each sentence are the point. | Williams cohesion and emphasis; Strunk 18; STE 4.4; Thomas & Turner "never requires the reader to look forward or backward" | Assumed context; text needing full read |
| No undefined term, abbreviation or assumed fact for the named reader. | For each term: in the reader's vocabulary or defined at first use; for each claim: does it rest on a fact the reader has not been given? | Pinker curse of knowledge; NN/g plain language and comprehension; Basecamp "no internal lingo"; STE dictionary; Zinsser "clear to someone encountering the subject for the first time" [U] | Assumed context; author's-head writing |
| Terms are consistent: one word per thing, one meaning per word. | Grep for synonyms of each key term; grep each key term for a second sense. | STE 1.3, 1.11, 9.4; Williams topic strings; Orwell "let the meaning choose the word" | Self-contradiction within a sentence or document |
| One pronoun stance, one tense, one mood per document; one takeaway. | Count switches; state the takeaway in one sentence and check the ending matches. | Zinsser unity; Strunk 17 | Self-contradiction |
| Character is the subject, action is the verb; no nominalized action with a weak verb. | Underline subject and verb of each clause; subject names the agent, verb names the act; "-tion" nouns recast. | Williams actions and characters; Zinsser concept nouns (p. 120); Orwell false limbs; STE 3.7; Strunk 10 | Author's-head writing; clutter |
| Active voice unless the agent is unknown, self-evident, or the passive preserves topic flow. | Each passive passes one of Williams' three reasons or is rewritten. | Strunk 10; Orwell iv; Williams p. 63; STE 3.6; NN/g readability | Clutter; ambiguity about who acts |
| Positive, definite assertions; no hedge without a stated condition. | Flag "not" used as evasion, "perhaps", "it seems", "to some extent"; replace each with the condition under which the claim fails, or delete. | Strunk 11; Thomas & Turner (no hedges of process); Pinker qualify-not-hedge; Zinsser little qualifiers (p. 112) | Over-explaining; author's-head writing |
| No metadiscourse or signposting beyond what a skipping reader needs. | Flag sentences whose subject is the document or the writer's process; keep only navigational ones. | Pinker; Thomas & Turner presentation stance; Orwell prefabricated phrases | Clutter; over-explaining to a knowing reader |
| Concrete, specific, short words; no stock phrase, jargon or Latinism with an everyday equivalent. | Flag "various", "appropriate", "a number of"; flag any four-word run seen elsewhere; flag long words with short equivalents. | Strunk 12; Orwell i, ii, v and the four swindles; NN/g plain language; Basecamp | Examples that import irrelevant details; clutter |
| Every word changes meaning; drafts lose up to half their words. | Delete each candidate word, paragraph; if nothing is lost, keep the deletion. Word count vs print draft. | Strunk 13; Orwell iii; Zinsser pp. 19, 25, 31; NN/g half the words; Basecamp 20 | Clutter; over-explaining |
| Sentence length ceiling. | Count words: 15-20 (NN/g), 20 in procedures and 25 in description (STE [S]). | NN/g plain language; STE 5.1, 6.x | Text needing full read |
| One instruction per sentence; imperative; condition before command; one new fact per sentence in description. | Each step has one verb in command form; any "if" precedes its command. | STE 5.2, 5.3, 7.2, 6.1 [S]; Basecamp "say what you need to and no more" | Examples importing irrelevant details |
| Noun clusters of at most three nouns; modifiers adjacent to what they modify. | Count consecutive nouns; count words between subject and verb and between modifier and head. | STE 2.1; Strunk 16; Williams (subject and verb early) | Ambiguity; assumed context |
| Parallel items share grammar; complex content goes in a vertical list. | Read list items as one sentence each; same part of speech first. | Strunk 15; STE 4.3; NN/g bullets | Clutter |
| Problem stated as one specific story before the solution; out-of-scope items named. | A spec names the problem with one concrete case and lists no-gos. | Shape Up ch. 6; Getting Real ch. 59, 61 | Examples importing irrelevant details; assumed context |
| Objective language; no promotional or evaluative claim without evidence the reader can check. | Flag superlatives and unsupported evaluations. | NN/g 1997 (+27 percent for objective language); Thomas & Turner (reader competent to verify); Orwell meaningless words | Author's-head writing |
| Writer and reader are equals: no condescension, no deference. | Flag "simply", "obviously", "as you know", "of course". | Thomas & Turner; Pinker; NN/g experts | Over-explaining to a reader who already knows |
| Readable once, in order, aloud. | Read aloud; every sentence is understood when it ends; a sentence you would not say is rewritten. | Thomas & Turner p. 37; Fried "say it like that"; Zinsser | Text needing full read; author's-head writing |
| Nothing to remember across sections; context is stated where it is used. | For each section, dependencies on earlier definitions or state are restated or linked. | NN/g comprehension; Basecamp 14 and 29 (factual and spatial context; right place) | Assumed context |
| Ambiguity resolves to the harmful reading; remove second readings. | For each sentence, construct a second reading; if one exists, rewrite. | Basecamp 8; STE purpose (ambiguity leads to accidents); Strunk 7 and 16 | Self-contradiction; assumed context |

---

## Where the sources disagree, and how audience and purpose resolve it

1. Signposting and headings. Thomas & Turner's classic style "never requires the reader to look forward or backward" and "declines to acknowledge ... other styles"; Pinker treats most metadiscourse as "there to help the writer, not the reader". NN/g measures the opposite: scannable layout alone improved usability 47 percent, and headings whose first two words carry the information are a stated rule. Thomas & Turner resolve it themselves: classic style is for a reader with no job; practical style exists because "Why else would anyone presume to take up a reader's time than to solve a problem for the reader?" Docs, READMEs, specs and agent answers serve readers with a job, so headings, summaries and answer-first ordering apply; the classic-style ban on metadiscourse still applies to the sentences inside each section (no "in this section we will").

2. Hedging. Classic style excludes hedges; Pinker allows that "Sometimes a writer has no choice but to hedge" and prefers qualification; NN/g's experts want succinct text; the user's own instructions require marking inference and speculation. Resolution: a hedge is a qualification when it names the condition under which the claim fails or the evidence it rests on (keep, as Pinker says); it is a process hedge when it only signals the writer's discomfort (delete, as Thomas & Turner say).

3. Prescriptive rules versus reader effect. Strunk, Orwell and STE give rules ("Never use the passive"; 20 words); Williams says "Clarity is not a property of sentences but an impression of readers" and lists when the passive and the nominalization are the right choice; Orwell's rule vi and Thomas & Turner's p. 67 remark on Strunk ("good advice for the one style they have in mind") concede the point. Resolution for a review skill: use the rules as detectors and Williams' reasons as the verdict: a flagged passive passes if the agent is unknown or self-evident, or if it keeps the topic string.

4. Writing for yourself versus the reader. Zinsser says "You are writing for yourself"; Basecamp, NN/g and STE ask what the reader needs. Zinsser splits the question into craft (be clear to a stranger) and attitude (voice). A reviewer checks craft; voice is the author's.

5. Word ceilings. STE's 20 and 25 words and six sentences per paragraph are hard limits for a safety-critical, basic-English reader; NN/g's 15-20 words and reading-level targets are averages for the web; Strunk explicitly does not require short sentences ("not that the writer make all his sentences short"). Resolution: use the limits as flags scaled to the audience (STE limits for procedures, NN/g for expository text, no limit on a single deliberately long sentence that Williams' subject-verb test passes).

6. Consistency versus context. STE 9.4 demands a consistent style; Getting Real says "It's better to be right than to be consistent." The disagreement is about layout and element choice, not terminology: both agree that the same thing keeps the same name.

---

## Gaps: what could not be verified

- Williams: the diagnostic "underline the first seven or eight words" and the exact lists (six principles of concision; introduction as shared context, problem, solution; "Here's the point" summaries) were not confirmed verbatim; the only verified wording is the 12th-edition quotations pin-cited by the NYSBA article.
- Zinsser: only the page-cited highlights (30th anniversary edition, pp. 19, 25, 31, 34, 81, 110-120, 124) are verified wording; "What am I trying to say? ... Is it clear to someone encountering the subject for the first time?", "what one point do I want to leave in the reader's mind", "The most important sentence in any article is the first one" and "when you're ready to stop, stop" are attributed by secondary sources only.
- Thomas & Turner: the practical-style passage on the reader's job, and whether the book itself says practical prose is built for skimming and headings, rest on reviewers' paraphrase; verified wording comes from the authors' excerpt page and page-cited quotations in the York review (pp. 15, 37, 67, 78).
- Pinker: ch. 2 and ch. 3 wording comes from quotations in blog posts and comments; the Chronicle adaptation and the APS Observer piece returned 403. "The main cause of incomprehensible prose" exact wording and page are unverified.
- Basecamp: "Write like you talk" as a Fried post title was not found; Rework's "Sound Like You" chapter text was not read. Getting Real chapter texts were summarized by the fetch tool with selected exact sentences.
- STE: rule numbers and numeric limits come from a term-checker vendor's Issue 8 rule list and Wikipedia; the standard (Issue 9) was not read; Issue 9 reworded 31 rules, so numbers may differ. The official site verifies only the structure (53 rules, 9 sections, about 900 approved and 1200 unapproved words), the one-word-one-meaning principle, the active-voice and condition-first reasoning, and the FAQ's list of transferable principles.
- NN/g: all cited figures verified on the NN/g pages; the 1997 study's sample size is not stated on the page.
