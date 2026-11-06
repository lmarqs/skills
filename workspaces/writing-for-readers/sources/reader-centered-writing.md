# What makes a text good for its reader: criteria from primary sources

Date: 2026-11-06

## Question

What do primary sources say makes a text good for its reader, stated as objective, checkable criteria? The criteria ground a Claude Code skill for writing and reviewing reader-centered prose (Markdown docs, specs, READMEs, agent chat answers).

## Answer

Across cognitive psychology (Flower, Kintsch, Clark, McNamara), rhetoric and style (Gopen & Swan, Williams, Pinker, Minto), pragmatics (Grice), plain-language standards (plainlanguage.gov / digital.gov, ISO 24495-1), documentation guides (Google, Microsoft, Diátaxis, Clements et al.), reading research (Nielsen Norman Group) and Anthropic's own guidance, the same criterion recurs: a text is good when it is built from the reader's state of knowledge, not the writer's. Concretely, that means (1) the audience and purpose are decided and stated before the body; (2) the point comes first, at document, section, and paragraph level, so the text never only makes sense once read in full; (3) each sentence starts from what the reader already has (given) and ends on what is new, so no "bridging" is needed; (4) every term, pronoun, and heading has one unambiguous referent that matches the text beneath it; (5) every unit (sentence, paragraph, example) makes exactly one point and carries no detail irrelevant to it; and (6) the level of explicitness is tuned to the declared audience's knowledge: low-knowledge readers need a fully coherent, explicit text, while high-knowledge readers are hindered by over-explicit text (McNamara et al. 1996). Verification status: web pages and the McNamara paper were read directly; Pinker, Williams and Minto books, Grice 1975, Kintsch & van Dijk 1978 and Clark & Haviland 1977 could not be opened in full text, and their claims are marked accordingly.

## Sources

### 1. Flower (1979), "Writer-Based Prose: A Cognitive Basis for Problems in Writing"; Flower & Hayes (1981)

What it is: Linda Flower, *College English* 41(1), September 1979, pp. 19-37 (JSTOR stable 376357). Flower & Hayes, "A Cognitive Process Theory of Writing", *College Composition and Communication* 32(4), 1981, pp. 365-387.

Verified from the published abstract (Semantic Scholar record for DOI 10.2307/376357): effective writers "do not simply express thought but transform it in certain complex but describable ways" "for the needs of a reader"; the less-transformed form is "Writer-Based prose"; "The symptoms can range from a mere missing referent or an underdeveloped idea" to "an unfocused and apparently pointless discussion"; "the source can often be traced to the writer's underlying strategy for composing". Writing Commons quotes p. 19: "writer-based prose is natural and adequate for a writer writing themself."

Unverified (full text not reachable; JSTOR page did not load, the Colorado State / WAC Clearinghouse copy of the companion JBW essay returned 403): the article's three named features of writer-based prose, which secondary sources summarise as narrative (the writer's own discovery path) or survey structure, egocentric focus, and "code words"/saturated terms whose meaning lives in the writer's head. Flower & Hayes 1981 could not be fetched (scispace copy empty); its "rhetorical problem includes the audience" claim is unverified.

Criteria:
- C1. The text is organised around the reader's question, not the order in which the writer discovered things. Test: does any section narrate the author's process ("first I looked at X, then Y") where the reader only needs the result?
- C2. No term carries meaning the reader was never given. Test: list each term or abbreviation that is used before it is defined or linked; each one is a "missing referent".
- C3. The point is stated, not left for the reader to infer from a survey of material. Test: can a reviewer underline the sentence that states the document's point in the first screen?

Citation: Flower, L. (1979). Writer-Based Prose: A Cognitive Basis for Problems in Writing. *College English*, 41(1), 19-37. https://doi.org/10.2307/376357 (abstract verified via https://api.semanticscholar.org/graph/v1/paper/DOI:10.2307/376357).

### 2. Pinker, *The Sense of Style* (2014)

What it is: Steven Pinker, *The Sense of Style: The Thinking Person's Guide to Writing in the 21st Century* (Viking, 2014). Chapter 2 "A Window onto the World" (classic style), chapter 3 "The Curse of Knowledge", chapter 5 "Arcs of Coherence" (pp. 139-186 per library TOC).

Verification: the book text was not reachable (psychologicalscience.org excerpt, Chronicle essay and stevenpinker.com PDF all 403/404). Verified from Pinker speaking in his own words: Harvard Gazette report of his 2012 talk (https://news.harvard.edu/gazette/story/2012/11/exorcising-the-curse-of-knowledge) quotes him defining the curse of knowledge as "the failure to understand that other people don't know what we know", and recommending to "show a draft [of your writing] to a representative reader" and that "You don't need abstract language simply because the concept is difficult"; New Republic interview (https://newrepublic.com/article/119687/steven-pinker-language-interview-jesse-singal) quotes "It's very hard to imagine what it's like not to know something that you know" and that professionals "tend to think about it in different terms than the consumers of that knowledge". Secondary summaries attribute to the book: "the single best explanation I know of why good people write bad prose"; chunking (p. 67, packaging ideas into bigger units the reader does not share) and functional fixity (thinking of a thing by its use rather than what it is) as mechanisms; chapter 5: announce the topic early, state the point soon after, keep topic threads consistent. Treat these as unverified wording, verified gist.

Criteria:
- C4. Chunk labels the writer uses (jargon, abbreviations, internal names) are expanded or defined on first use for the declared audience. Test: for each specialised term, is there a definition, link or concrete instance within the same paragraph or a glossary?
- C5. Things are described by what they are, not only by the use the writer puts them to (functional fixity). Test: does each named artefact have a concrete description a newcomer could point at?
- C6. The topic is announced at the start of the text and of each section, and the point is stated right after. Test: read only the first sentence of each section; does it name the topic?
- C7. The draft has been checked against a reader who lacks the writer's context (Pinker's remedy; same as Anthropic's "colleague with minimal context" test). Test: a reviewer unfamiliar with the project can state what the text asks or claims.

Citation: Pinker, S. (2014). *The Sense of Style*, ch. 2, 3, 5. Quotations verified via the two interview pages above.

### 3. Williams, *Style: Toward Clarity and Grace* / *Style: Lessons in Clarity and Grace*

What it is: Joseph M. Williams, *Style: Toward Clarity and Grace* (U. Chicago Press, 1990); Williams & Bizup, *Style: Lessons in Clarity and Grace* (Pearson, 11th-13th eds.). Lessons 3 "Actions", 4 "Characters", 5 "Cohesion and Coherence", 9 "Concision" (11th ed. TOC: Lesson 5 begins p. 66).

Verification: no full text reachable (archive.org full-text copy returned 500; other PDFs are illegitimate copies). The secondary sources consistently report these principles; wording unverified: readers "expect to see central characters in most subjects" and "their important actions in most verbs"; "Begin sentences with information familiar to your readers" / "End sentences with information readers cannot anticipate" (old-before-new, Williams calls it the most important cohesion principle); cohesion is "a sense of flow" between sentence pairs while coherence is the whole passage holding together around a consistent set of topics; begin sentences in a passage with consistent topics (topic strings); concision: cut words that mean little, words that repeat others, words implied by others.

Criteria:
- C8. Each sentence's grammatical subject names the character the sentence is about and its verb names the action. Test: underline subject and verb; is the subject a thing the reader cares about and the verb a real action (not "is", "there are", or a nominalisation)?
- C9. Each sentence begins with information the reader already has and ends with new information. Test: for consecutive sentences, does the opening of sentence N+1 refer to something present in sentence N or earlier?
- C10. The sentences of a passage share a small set of topics in subject position. Test: list the subjects of all sentences in a paragraph; are they the same two or three things?
- C11. No word can be cut without losing meaning. Test: delete each hedging or repeating word; does the sentence still say the same?

Citation: Williams, J. M. (1990). *Style: Toward Clarity and Grace*. Williams, J. M. & Bizup, J. *Style: Lessons in Clarity and Grace*, Lessons 3-5, 9. Wording unverified; see Gaps.

### 4. Gopen & Swan (1990), "The Science of Scientific Writing"

What it is: George D. Gopen and Judith A. Swan, *American Scientist* 78(6), Nov-Dec 1990, pp. 550-558. Verified from the licensed reprint (LibreTexts, "reprinted here with the permission of American Scientist").

Verbatim: "Readers do not simply read; they interpret." "Each unit of discourse, no matter what the size, is expected to serve a single function, to make a single point." Writers "will not have to conjecture or infer" what their prose means because they know what they intended; readers must infer it from structure. The closing list of principles:
1. "Follow a grammatical subject as soon as possible with its verb."
2. "Place in the stress position the 'new information' you want the reader to emphasize."
3. "Place the person or thing whose 'story' a sentence is telling at the beginning of the sentence, in the topic position."
4. "Place appropriate 'old information' (material already stated in the discourse) in the topic position for linkage backward" and contextualisation forward.
5. "Articulate the action of every clause or sentence in its verb."
6. "In general, provide context for your reader before asking that reader to consider anything new."
7. "In general, try to ensure that the relative emphases of the substance coincide with the relative expectations" raised by structure.
"None of these reader-expectation principles should be considered 'rules.'"

Criteria:
- C12. Subject and verb are not separated by long interruptions. Test: count words between subject and verb; more than a handful signals an interruption the reader must hold in memory.
- C13. The item in the stress position (end of sentence) is the new, emphasised item; the item in the topic position (start) is the old, linking item. Test: mark the last noun phrase of each sentence; is it the thing the writer wants remembered?
- C14. Context precedes new material at every scale. Test: for each new concept, is the sentence or heading that introduces its context before it?
- C15. One point per unit of discourse (sentence, paragraph, section). Test: can each paragraph be summarised in one sentence without "and"?

Citation: Gopen, G. D., & Swan, J. A. (1990). The Science of Scientific Writing. *American Scientist*, 78(6), 550-558. Reprint: https://human.libretexts.org/Bookshelves/Composition/Technical_Composition/Effective_Technical_Writing_in_the_Information_Age_(Schall)/10%3A_Journal_Articles_about_Writing/10.06%3A_The_Science_of_Scientific_Writing (original https://www.americanscientist.org/blog/the-long-view/the-science-of-scientific-writing returned 503).

### 5. Minto, *The Pyramid Principle*

What it is: Barbara Minto, *The Pyramid Principle: Logic in Writing and Thinking* (1987; 3rd ed. FT Prentice Hall) and *The Minto Pyramid Principle* textbook (1996). Part 1 ch. 1 "Why a pyramid structure?".

Verification: only Minto's own site was reachable. Verbatim from https://www.barbaraminto.com/: thinking is easier for a reader to grasp when ideas are "organized as a pyramid under a single point"; the "Situation, Complication, Question Framework (SCQ Framework™) for identifying the question in your reader's mind". From https://barbaraminto.com/concept: the pyramid must obey "logical rules" and be "held together by a single thought"; communicating means guiding the reader down the pyramid. From https://barbaraminto.com/course: the course teaches "how to identify the reader's question", and "'There are three reasons' is not an appropriate insight!". Unverified (book text not reachable): the three pyramid rules (ideas at any level summarise the ideas grouped below; ideas in a grouping are the same kind; ideas in a grouping are logically ordered), the vertical question-answer dialogue, horizontal deductive/inductive logic, and MECE grouping. These are consistently reported by secondary sources but the wording is not confirmed.

Criteria:
- C16. The document opens by establishing the reader's question (Situation, Complication, Question) and then gives the Answer before any support. Test: is the main conclusion in the first paragraph, and is it an answer to a question the introduction raised?
- C17. Each heading is a summary of the content beneath it, and each lower level answers the question the level above raises. Test: read a heading, then its body; does the body answer "why?" or "how?" of the heading and nothing else?
- C18. Items in a list or group are the same kind of thing, non-overlapping and complete for the stated purpose. Test: name the category the list items share; check no item belongs to two slots and nothing obvious is missing.

Citation: Minto, B. (1987/2009). *The Pyramid Principle*, Part 1. Site pages above (verified); book wording unverified.

### 6. Grice (1975), "Logic and Conversation"

What it is: H. P. Grice, in Cole & Morgan (eds.), *Syntax and Semantics 3: Speech Acts*, Academic Press, pp. 41-58; reprinted in *Studies in the Way of Words* (1989), pp. 22-40.

Verification: no readable primary PDF (UCL copy 403; lawandlogic.org and SFU copies are scanned images without a text layer). The Stanford Encyclopedia of Philosophy entry "Implicature" (https://plato.stanford.edu/entries/implicature/) cites Grice 1975: 26-30 and gives the maxims as: Cooperative Principle "Contribute what is required by the accepted purpose of the conversation"; Quality "Make your contribution true; so do not convey what you believe false or unjustified"; Quantity "Be as informative as required"; Relation "Be relevant"; Manner "Be perspicuous; so avoid obscurity and ambiguity, and strive for brevity and order". Grice's original wording (Quantity: make your contribution as informative as is required, and not more informative than is required; Manner: avoid obscurity of expression, avoid ambiguity, be brief, be orderly) is widely reproduced but not verified here against the original pages.

Criteria:
- C19. Relation: every sentence, and every detail inside an example, bears on the reader's purpose. Test: for each clause in an example, ask "does removing this change what the example teaches?"; if not, it imports an irrelevant contrast (e.g. "not on the table" when tables were never in play) and the reader will infer a reason that does not exist.
- C20. Quantity: the text says as much as the reader needs and no more. Test: is there any explanation of something the declared audience already knows (over-informative) or any step the reader must guess (under-informative)?
- C21. Manner: no ambiguity, no obscurity, orderly sequence. Test: can any sentence be read two ways? Are steps given in the order they are performed?

Citation: Grice, H. P. (1975). Logic and Conversation. In Cole & Morgan (eds.), *Syntax and Semantics 3*, 41-58. Maxims verified via SEP "Implicature" (citing Grice 1975: 26-30).

### 7. Clark & Haviland (1977), Haviland & Clark (1974), Kintsch & van Dijk (1978)

What they are: Haviland, S. E. & Clark, H. H. (1974). What's new? Acquiring new information as a process in comprehension. *Journal of Verbal Learning and Verbal Behavior* 13, 512-521. Clark, H. H. & Haviland, S. E. (1977). Comprehension and the given-new contract. In Freedle (ed.), *Discourse Production and Comprehension*, 1-40. Kintsch, W. & van Dijk, T. A. (1978). Toward a model of text comprehension and production. *Psychological Review* 85(5), 363-394.

Verification: all three PDFs found (Stanford, ACL Anthology, Cambridge) are image scans with no text layer and no PDF tools are installed, so quotations are unverified. The Benjamins bibliographic annotation (via search) describes the 1974 result: "a hearer first searches memory for antecedent information matching the sentence's given information, and then" attaches the new information; sentences whose given part has no direct antecedent take longer because the reader must build a "bridge". The Kintsch & van Dijk model is summarised, with citations, in McNamara et al. 1996 (verified, section 15): the text base has "a local structure (the microstructure) as well as a global structure (the macrostructure)"; building it requires that "the referents of pronouns must be identified, synonymous terms must be matched, glaring gaps in the coherence of the network must be filled by bridging inferences" (McNamara et al., p. 3); when a simulated reader "broke down due to coherence gaps from one proposition to the next, text was added to make the relation explicit" (p. 2, describing Britton & Gulgoz 1991 using the 1978 model).

Criteria:
- C22. Every "given" element (definite noun phrase, pronoun, "this", "the above") has a unique antecedent already in the text or in the declared audience's knowledge. Test: for each pronoun or definite reference, point to its antecedent; if none, the reader must bridge.
- C23. Consecutive sentences share an argument (a repeated noun phrase or referent), so the propositional network has no gaps. Test: for each sentence, name a noun it shares with the previous one; a sentence sharing none is a coherence gap.
- C24. The text has an explicit macrostructure (headings and linking statements) that matches the local content. Test: do the headings alone form a correct summary of the body?

Citations as above; wording unverified (see Gaps).

### 8. Federal plain language guidelines (plainlanguage.gov, now digital.gov) and ISO 24495-1:2023

What they are: The US Federal Plain Language Guidelines, previously at https://www.plainlanguage.gov/guidelines/ (now 301 to https://digital.gov/guides/plain-language). ISO 24495-1:2023, *Plain language — Part 1: Governing principles and guidelines*.

Verified from digital.gov: the "first rule" is "write for your audience", taking readers' "current level of knowledge, expertise, and interest into account" (https://digital.gov/guides/plain-language/principles); "Have a topic sentence. Good opening sentences help organize the structure of writing."; "Organize the information. Prepare readers for what to expect. Summarize lengthy documents up-front."; "Use lists."; "Plain language writing requires communicating clearly for your specific audience."; "Active voice makes it clear who should do what." (https://digital.gov/guides/plain-language/writing). The older guideline sub-pages ("Identify your audience", "Address separate audiences separately", "Put the most important information first", "Use headings") were not reachable at their old URLs; their existence is unverified in the new site.

ISO 24495-1: the ISO page (https://www.iso.org/standard/78907.html) returned 403, the OBP preview 403, and vendor previews were unreachable. From vendor listings found by search (globalspec, standards.govt.nz): Principle 1 "Readers get what they need (relevant)"; Principle 2 "Readers can easily find what they need (findable)"; Principle 3 "Readers can easily understand what they find (understandable)"; Principle 4 "Readers can easily use the information (usable)"; the standard's premise is that a document is usable if the information is relevant, findable and understandable; the introduction says plain language is judged by how successfully readers can use the document, not by readability formulas. The clause 5.1 guidelines on identifying readers and purpose first are reported by secondary sources but unverified here.

Criteria:
- C25. The audience is identified before writing and named in the text, with their assumed knowledge. Test: does the text state who it is for and what it assumes they know?
- C26. The most important information comes first; long documents open with a summary. Test: is the first paragraph a summary a reader could stop after?
- C27. Each paragraph opens with a topic sentence. Test: read first sentences only; is the argument still recoverable?
- C28. Readers can find what they need (headings, lists, tables), understand it (familiar words, active voice, who does what), and use it (actions are explicit). Test: for a sample reader task, can the reviewer locate the answer by headings alone?

Citations: https://digital.gov/guides/plain-language/principles ; https://digital.gov/guides/plain-language/writing ; ISO 24495-1:2023 (principles verified only via vendor summaries).

### 9. Google developer documentation style guide and technical writing course; Microsoft Writing Style Guide

What they are: Google developer documentation style guide (https://developers.google.com/style/), Google Technical Writing One (https://developers.google.com/tech-writing/one/), Microsoft Writing Style Guide (https://learn.microsoft.com/en-us/style-guide/).

Verified verbatim:
- Google tech writing, Audience: "good documentation = knowledge and skills your audience needs to do a task − your audience's current knowledge and skills"; experts' "expert understanding of a topic ruins their explanations to newcomers" (curse of knowledge). https://developers.google.com/tech-writing/one/audience
- Google tech writing, Documents: "A good document begins by defining its scope."; "A better document additionally defines its non-scope"; "A good document explicitly specifies its audience."; "This document assumes that you understand matrix multiplication and the fundamentals of backpropagation."; "Ensure that the start of your document answers your readers' essential questions."; "Imagine that your peers might only read the first paragraph of your document." https://developers.google.com/tech-writing/one/documents
- Google tech writing, Paragraphs: "The opening sentence is the most important sentence of any paragraph."; "A paragraph should represent an independent unit of logic."; "Good paragraphs answer the following three questions:" what, why, how; "Readers generally welcome paragraphs containing three to five sentences." https://developers.google.com/tech-writing/one/paragraphs
- Google tech writing, Short sentences: "Focus each sentence on a single idea"; "Shorter documentation reads faster than longer documentation." https://developers.google.com/tech-writing/one/short-sentences
- Google tech writing, Words: "learn to recognize terms that might be unfamiliar to some or all of your target audience"; "If you change the name of a variable midway through a method, your code won't compile."; "Using pronouns improperly causes the cognitive equivalent of a null pointer error in your readers' heads." https://developers.google.com/tech-writing/one/words
- Google style guide, Headings: "Use descriptive headings and titles because they help a reader navigate their browser and the page."; "Write document titles based on the primary purpose of the document."; "Don't use empty headings. Make sure headings are followed by content."; "Task-based headings are frequently used in quickstarts, how-to documents, and tutorials." https://developers.google.com/style/headings
- Google style guide, Paragraph structure: "Each paragraph should address a single idea in the fewest words and in the fewest sentences possible."; "Put the most important information first in a paragraph." https://developers.google.com/style/paragraph-structure
- Google style guide, Sentence structure: "try to mention the circumstance, conditions, or goal before you provide the instruction." https://developers.google.com/style/sentence-structure
- Google style guide, Tone: "the primary purpose of the document is to provide information to someone who's looking for it and may be in a hurry." https://developers.google.com/style/tone
- Google style guide, Example data: "Don't use unclear components like foo, bar, and baz in names."; "Ensure that the name is applicable to the reader's environment." https://developers.google.com/style/examples . Note: neither Google examples page states "keep examples minimal / no unrelated detail"; that rule is supported by Grice (C19) and Anthropic (section 13), not by Google.
- Microsoft, Top 10 tips: "Get to the point fast. Lead with what's most important. Front-load keywords for scanning."; "Be brief. Give customers just enough information to make decisions confidently." https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice
- Microsoft, Scannable content: "lead with what's most important to the customer"; "Lead with what's most important. Place important keywords near the beginning of headings, table entries, and paragraphs"; "Three to seven lines is about the right length for a paragraph." https://learn.microsoft.com/en-us/style-guide/scannable-content/
- Microsoft, Headings: "Think of headings as an outline"; "Each new heading represents a new or more specific topic."; "Avoid having two headings in a row without text in between"; "Be as specific as you can"; "Focus on what matters to customers, and choose words they'd use themselves." https://learn.microsoft.com/en-us/style-guide/scannable-content/headings
- Microsoft, Writing tips: "Write short, simple sentences."; "Use one word for a concept, and use it consistently. Avoid using synonyms to refer to the same concept"; "Keep adjectives and adverbs close to the words they modify." https://learn.microsoft.com/en-us/style-guide/global-communications/writing-tips

Criteria:
- C29. Scope, non-scope, audience and prerequisites are stated at the top. Test: are there sentences of the form "This document describes...", "does not describe...", "is aimed at...", "assumes that you..."?
- C30. Headings are specific, describe the content beneath them, are never empty, and use the reader's words. Test: for each heading, does the first sentence under it deliver what the heading promises? Is there any heading immediately followed by another?
- C31. One idea per sentence, one idea per paragraph, most important first, 3-5 sentences per paragraph. Test: split any sentence with two independent claims; split any paragraph whose first sentence does not cover it.
- C32. One term per concept, used consistently; pronouns have a nearby unambiguous noun. Test: grep for synonyms of a key term; for each "it/this/that", name the noun.
- C33. Conditions and goals precede instructions. Test: in each step, does the "if/when/to..." clause come before the imperative?
- C34. Example names are meaningful and applicable to the reader's environment. Test: no foo/bar; names match the domain.

### 10. Diátaxis (diataxis.fr)

What it is: Daniele Procida's documentation framework; four kinds (tutorials, how-to guides, reference, explanation) mapped to four user needs.

Verified verbatim: "Diátaxis identifies four distinct needs, and four corresponding forms of documentation." (https://diataxis.fr/). "Diátaxis is underpinned by a systematic description and analysis of generalised user needs"; a practitioner is "at work" (applying) or "at study" (acquiring) (https://diataxis.fr/foundations/). Map: tutorials answer "Can you teach me to…?", how-to "How do I…?", reference "What is…?", explanation "Why…?"; "When these distinctions are allowed to blur, the different kinds of documentation bleed into each other." (https://diataxis.fr/map/). Compass: "action or cognition?" and "acquisition or application?" (https://diataxis.fr/compass/). Tutorials vs how-to: a tutorial "doesn't offer choices or alternatives" and "must be safe"; a how-to "cannot promise safety"; a mixed clinical document "would be a literally deadly document"; mixing causes "a great deal of low-level inconvenience and unhappiness" and risks "getting in the way of those newcomers" (https://diataxis.fr/tutorials-how-to/). Quality: disruption occurs "when a digression into explanation interrupts a how-to guide" (https://diataxis.fr/quality/).

Criteria:
- C35. The document serves exactly one of the four needs, declared or evident from its form. Test: apply the compass to the whole and to each section; any section that answers a different question than the document ("why?" inside a "how do I?") is a mixture.
- C36. A tutorial has one path and no choices; a how-to may branch; reference describes, it does not instruct; explanation discusses, it does not instruct. Test: look for imperatives in reference, for alternatives in tutorials, for digressions in how-tos.

### 11. Clements et al., *Documenting Software Architectures: Views and Beyond* (2nd ed., 2010), Prologue P.5 "Seven Rules for Sound Documentation"

What it is: Clements, Bachmann, Bass, Garlan, Ivers, Little, Merson, Nord, Stafford (Addison-Wesley, 2010). Verified from the publisher's excerpt (https://www.informit.com/articles/article.aspx?p=1641654&seqNum=5).

Verbatim: Rule 1 "Write Documentation from the Reader's Point of View" — "Make your document serve its stakeholders and their intended uses of it." Rule 2 "Avoid Unnecessary Repetition" — "Each kind of information should be recorded in exactly one place." Rule 3 "Avoid Ambiguity" — "Ambiguity occurs when documentation can be interpreted in more than one way and at least one of those ways is incorrect." Rule 4 "Use a Standard Organization". Rule 5 "Record Rationale" — "For the most important decisions, you should record why you made them the way you did." Rule 6 "Keep Documentation Current but Not Too Current" — "Documentation that is kept current and accurate is used." Rule 7 "Review Documentation for Fitness of Purpose" — "Only the intended users of a document will be able to tell you whether it contains the right information".

Criteria:
- C37. The document names its stakeholders and the uses they will put it to. Test: for each section, name the reader who needs it and the task it supports; a section with none is writer-centred.
- C38. Each fact appears in exactly one place (or is linked). Test: search for the same fact stated twice; two statements drift into contradiction.
- C39. No sentence admits a second, incorrect reading. Test: for key sentences, write the alternative reading; if one is plausible and wrong, rewrite.
- C40. A standard, predictable organisation (template) is used. Test: do readers of a sibling document find the same sections in the same order?
- C41. Rationale is recorded for decisions. Test: for each decision stated, is there a "because"?
- C42. The intended users have reviewed it. Test: evidence of a reader-reviewer from the audience.

### 12. Nielsen Norman Group studies and the inverted pyramid

What they are: Nielsen, "How Users Read on the Web" (1997 study): "79 percent of our test users always scanned any new page they came across"; 16 percent read word by word; recommendations: highlighted keywords, meaningful subheadings, bulleted lists, "one idea" per paragraph, inverted pyramid, half the word count; measured improvements versus the promotional control: concise 58%, scannable 47%, objective 27%, all three 124% (https://www.nngroup.com/articles/how-users-read-on-the-web/). Pernice, "F-Shaped Pattern of Reading on the Web" (eyetracking, pattern first identified 2006, article 2017): "Users first read in a horizontal movement, usually across the upper part of the content area"; "The F-pattern is the default pattern when there are no strong cues"; "Include the most important points in the first two paragraphs on the page."; "First lines of text on a page receive more gazes than subsequent lines"; "Start headings and subheadings with the words carrying most information" (https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/). Schade, "Inverted Pyramid: Writing for Comprehension" (2018): "the most important information (or what might even be considered the conclusion) is presented first"; steps: identify key points, rank secondary information, write a strong lead, "each heading or subheading should be descriptive", consider a summary (https://www.nngroup.com/articles/inverted-pyramid/). The BBC/journalism origin of the inverted pyramid was not fetched from a primary journalism source and is unverified here.

Criteria:
- C43. The conclusion is in the first two paragraphs. Test: stop reading after paragraph two; is the main point known?
- C44. Headings and paragraph openings start with the most informative words. Test: read only the first two words of each heading and paragraph; do they identify the topic?
- C45. Lists and tables replace enumerations in prose; word count is about half a first draft. Test: any sentence listing more than two items becomes a list.

### 13. Anthropic guidance on writing for agents

What it is: Claude platform docs, "Skill authoring best practices" (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) and "Prompting best practices" (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices; the older "be-clear-and-direct" and "multishot-prompting" URLs now redirect there).

Verified verbatim (best-practices): "Default assumption: Claude is already very smart"; "Only add context Claude doesn't already have. Challenge each piece of information: 'Does Claude really need this explanation?' 'Can I assume Claude has this information?' 'Does this paragraph justify its token cost?'"; description "should include both what the Skill does and when to use it"; "Always write in third person"; "Use consistent terminology"; "Consistency helps Claude parse and follow instructions."; "Avoid offering too many options"; "Keep references one level deep from SKILL.md"; "For reference files longer than 100 lines, include a table of contents at the top."; "Examples are concrete, not abstract"; "Examples convey the desired style and level of detail to Claude more clearly than descriptions alone."

Verified verbatim (prompting best practices): "Think of Claude as a brilliant but new employee who lacks context on your norms and workflows."; "Key test: Show your prompt to a colleague with minimal context on the task and ask them to follow it. If they'd be confused, Claude will be too."; "Providing context or motivation behind your instructions, such as explaining to Claude why such behavior is important, can give Claude more information about your goals"; examples should be "Diverse: Cover edge cases and vary enough that Claude doesn't pick up unintended patterns."; "Include 3–5 examples for best results."

Criteria:
- C46. The text contains only what the declared reader lacks; nothing it already knows. Test: for each paragraph, ask "can I assume the reader has this?"; delete if yes.
- C47. The opening states what the document does and when to use it, in third person. Test: the first sentence names the activity and the trigger.
- C48. Examples are concrete, varied, and free of incidental features the reader could mistake for the rule. Test: compare examples; any feature shared by all examples but not part of the rule will be learned as the rule ("unintended patterns"); any contrast present in one example ("not on the table") will be read as a required contrast.
- C49. A colleague with minimal context can follow the text. Test: same as C7.
- C50. Reasons are given for instructions ("why" motivates behaviour). Test: each "must" has a "because".

### 14. Primary research on LLM-written text failures

What it is: Mündler, He, Jenko, Vechev (2023), "Self-contradictory Hallucinations of Large Language Models: Evaluation, Detection and Mitigation", arXiv:2305.15852 (ICLR 2024); ConStory-Bench, arXiv:2603.05890 (2026); DOC, Yang et al., arXiv:2212.10077; Re3, arXiv:2210.06774; "Integrating Planning into Single-Turn Long-Form Text Generation", arXiv:2410.06203.

Verified from abstracts: self-contradiction is "where the LM generates two contradictory sentences within the same context"; self-contradictions appear "in 17.7% of all sentences produced by ChatGPT"; "a large portion of self-contradictions (e.g., 35.2% for ChatGPT) cannot be verified using online text" (so they are detectable only by reading the text against itself) (https://arxiv.org/abs/2305.15852). ConStory-Bench: LLMs "can contradict their own established facts, character traits, and world rules"; "a taxonomy of five error categories with 19 fine-grained subtypes"; errors are most common in factual and temporal dimensions and cluster around the middle of narratives; errors are more frequent in higher-entropy segments (https://arxiv.org/abs/2603.05890). DOC reports planning with a detailed outline improves plot coherence by 22.5% absolute over Re3; the single-turn planning paper reports that training to produce an outline first yields higher-quality long documents (search-result summaries; abstracts not fetched directly, so figures are unverified beyond the search snippet).

Criteria:
- C51. No two sentences in the text contradict each other, including a heading and its body. Test: for each claim, search the rest of the text for the same entity and compare the predicates; pay particular attention to the middle of long texts.
- C52. Long text is written from an explicit outline (macrostructure) and the final text matches it. Test: reconstruct the outline from the headings and compare with the stated plan; sections that drifted are where global coherence was lost.

### 15. McNamara, E. Kintsch, Songer & W. Kintsch (1996), "Are Good Texts Always Better?"

What it is: *Cognition and Instruction* 14(1), 1-43, DOI 10.1207/s1532690xci1401_1. Verified from full text (author's lab posting, linked from https://soletlab.asu.edu/all-publications/; journal page = PDF page − 1).

What it says (verbatim):
- Text base vs situation model (pp. 3-4): "The text base contains the information that is directly expressed in the text, organized and structured in the way that the author had organized the material. It has a local structure (the microstructure) as well as a global structure (the macrostructure)." Building it requires that "the referents of pronouns must be identified, synonymous terms must be matched, glaring gaps in the coherence of the network must be filled by bridging inferences" (p. 3). "The situation model integrates the information provided by the text with prior knowledge" (p. 4); "For the purpose of reproducing a text in one way or another, a good text base suffices; learning from text, however, implies more than that and requires a good situation model" (p. 4). "Without adequate prior knowledge, students are limited in their constructive processes. Nevertheless, a well-written, fully coherent, explicit text at least will allow them to form a good text base." (p. 4)
- The four local-coherence revisions (p. 21): "1. Replacing pronouns with noun phrases when the referent was potentially ambiguous (e.g., replacing it with the heart). 2. Adding descriptive elaborations that link unfamiliar concepts with familiar ones (e.g., 'This disease usually follows a sore throat caused by bacteria known as streptococci. This is often called strep throat.'). 3. Adding sentence connectives (e.g., however, therefore, because, so that) to specify the relation between sentences or ideas. 4. Replacing words to increase argument overlap (e.g., replacing person and cases with baby or babies)."
- The two macrostructure signals (p. 21): "(a) adding topic headers (e.g., congenital heart disease, acquired heart disease) and (b) adding macropropositions serving to link each paragraph to the rest of the text and overall topic (e.g., 'There are many kinds of heart disease, some of which are present at birth and some of which are acquired later.')."
- Results (p. 33): "Low-knowledge readers could not form adequate situation models when the text did not support them, whereas high-knowledge readers actually constructed better situation models when they had to actively process a suboptimal text". "Here, maximum coherence clearly provided an advantage for all readers" on text-based questions. A text "overly supportive at the macrolevel, while at the same time difficult at the local level, may induce a false sense of understanding" (p. 33).
- Conclusions (pp. 34-36): "Increasing the coherence of a text has been found to improve readers' comprehension ... as well as in this study for low-knowledge readers." (p. 34). "constructing coherence without explicit textual support is only possible when students possess adequate background knowledge" (p. 35). "If the text is too hard, the construction of coherence may fail; on the other hand, if the text is too easy, the gains through more active processing may be too small" (p. 35). "Tuning the level of detail and coherence to the audience is implicitly expected of writers. Often, however, writers underestimate their audience and end up with an overly explicit text. What we have demonstrated is that overly explicit writing is not only annoying, but also prevents the audience from actively processing what we have to say." (p. 36)

Why it matters for this skill: it is the direct experimental evidence that the right level of explicitness is not a property of the text alone but of the text relative to the reader's knowledge. Declaring the audience's knowledge level before writing is therefore what decides how explicit the text must be: for readers who lack the domain (newcomers, agents without project context), apply all four local revisions and both macrosignals; for expert readers, the same additions are "overly explicit" and reduce learning. This is the empirical basis for the observed fix of declaring description + audience in frontmatter.

Criteria:
- C53. The audience's knowledge level is declared, and the text's explicitness matches it. Test: name the audience; if low-knowledge, check C54-C57 are all satisfied; if high-knowledge, check the text does not spell out what they already know (C46).
- C54. Pronouns with a potentially ambiguous referent are replaced by the noun phrase. Test: for each "it/this/they", is there more than one candidate noun in the previous sentence?
- C55. Unfamiliar concepts are linked to familiar ones at first mention. Test: each new term has an elaboration in the reader's vocabulary.
- C56. Relations between sentences are stated with connectives (however, therefore, because, so that). Test: for each sentence pair, can the reviewer name the relation; if only by guessing, add the connective.
- C57. Adjacent sentences repeat the same noun for the same thing (argument overlap). Test: same as C23 and C32.
- C58. Headings name topics, and each paragraph has a sentence linking it to the overall topic. Test: for each paragraph, find the sentence that says how it relates to the document's point.
- C59. The text is not simultaneously easy at the top (good headings) and hard locally (missing links), since that masks misunderstanding. Test: if headings are clear, sample the body for C54-C57.

## Consolidated table

| Criterion | Test a reviewer applies | Sources | Motivating failure addressed |
|---|---|---|---|
| Audience and its knowledge level are declared before the body | First screen states who the text is for and what it assumes they know | Google tech writing Documents/Audience; digital.gov principles; ISO 24495-1 (unverified wording); Clements Rule 1; McNamara 1996 p. 36; Anthropic skill description "what + when" | Assumes context the reader lacks; author writes from own head |
| Scope and non-scope are stated | Sentences "This document describes… / does not describe…" present | Google tech writing Documents | Assumes context; mixture of document kinds |
| Purpose or problem stated, then the answer, before support | Main conclusion is in the first paragraph and answers a question the opening raised | Minto (site verified, book unverified); NN/g inverted pyramid; Microsoft "Get to the point fast"; digital.gov "Summarize lengthy documents up-front"; Google "Imagine that your peers might only read the first paragraph" | Only makes sense once read in full |
| Explicitness tuned to declared audience | Low-knowledge: all local and macro signals present; high-knowledge: nothing they already know | McNamara 1996 pp. 4, 33-36; Anthropic "Only add context Claude doesn't already have"; Grice Quantity | Assumes context the reader lacks (under-explicit) and padding (over-explicit) |
| Topic announced first at document, section and paragraph level | First sentence of each unit names its topic | Pinker ch. 5 (gist verified); Google Paragraphs; digital.gov "Have a topic sentence"; NN/g F-pattern | Only makes sense once read in full |
| Heading matches and summarises its body; no empty headings | Body under each heading delivers what the heading promises; no two consecutive headings | Google Headings; Microsoft Headings; Minto (summaries above groups); McNamara macrosignals | Heading contradicts body; self-contradiction |
| No contradiction between any two sentences | For each entity, compare predicates across the text, especially the middle | Mündler et al. 2023; ConStory-Bench 2026; Clements Rule 3; Clements Rule 2 (single location) | Self-contradiction |
| Each fact recorded once | Search for the same fact stated twice | Clements Rule 2 | Self-contradiction via drift |
| Given before new in every sentence; stress position holds the new item | Opening of sentence N+1 refers to something in N or earlier; last phrase is the item to remember | Gopen & Swan principles 2-4, 6; Williams (unverified wording); Clark & Haviland (unverified); McNamara argument overlap | Only makes sense once read in full; assumes context |
| Every pronoun or definite reference has a unique antecedent | Point to the antecedent of each "it/this/the X" | Haviland & Clark 1974 (via annotation); McNamara revision 1; Google Words; Flower "missing referent" | Assumes context the reader lacks |
| One term per concept, used consistently | grep for synonyms of key terms | Microsoft Writing tips; Google Words; Anthropic "consistent terminology"; McNamara revision 4 | Self-contradiction; assumes context |
| New or specialised terms are defined or linked on first use | Each term has a definition, link or concrete instance | Pinker curse of knowledge (chunking); Google Words; McNamara revision 2; Flower "code words" (unverified) | Author writes from own head |
| Relations between sentences are explicit | Name the relation between each sentence pair | McNamara revision 3; Gopen & Swan "provide context before anything new"; Kintsch & van Dijk coherence gaps (unverified) | Only makes sense once read in full |
| One point per sentence, paragraph and section | Summarise each unit in one sentence without "and" | Gopen & Swan "single point"; Google Short sentences / Paragraph structure; NN/g "one idea" per paragraph | Self-contradiction; scanning failure |
| Subject names the character, verb names the action, subject and verb adjacent | Underline subject and verb; count words between them | Williams Lessons 3-4 (unverified wording); Gopen & Swan principles 1 and 5; digital.gov active voice | Author writes from own head (abstraction) |
| Every detail, including inside examples, is relevant to the reader's purpose | Remove each clause of an example; if the lesson is unchanged, the clause is an irrelevant contrast the reader will infer meaning from | Grice Relation and Quantity (via SEP); Anthropic "unintended patterns"; Google example data (meaningful names) | Examples importing irrelevant details |
| Examples are concrete and varied; no incidental feature shared by all | Compare examples for features not part of the rule | Anthropic prompting best practices; skill best-practices checklist | Examples importing irrelevant details |
| No ambiguous sentence | Write the alternative reading; if plausible and wrong, rewrite | Clements Rule 3; Grice Manner; Microsoft Writing tips | Self-contradiction |
| Conditions and goals precede instructions | "If/when/to…" clause before the imperative | Google Sentence structure; Gopen & Swan principle 6 | Only makes sense once read in full |
| Document serves one reader need (tutorial, how-to, reference, explanation) | Apply the compass to the document and each section | Diátaxis map, compass, tutorials-how-to | Mixture; assumes the reader's situation |
| Reasons recorded for instructions and decisions | Each "must" or decision has a "because" | Clements Rule 5; Anthropic "context or motivation" | Author writes from own head |
| Reader-scannable structure: descriptive headings, front-loaded words, lists, short paragraphs | First two words of headings and paragraphs identify the topic; enumerations are lists | NN/g 1997 and F-pattern; Microsoft Scannable content; digital.gov "Use lists" | Only makes sense once read in full |
| Nothing the declared reader already knows; no word that can be cut | Delete each paragraph or word and check the meaning survives | Anthropic "Concise is key"; Williams Concision (unverified); Microsoft "Be brief"; NN/g half the word count | Over-explicit text (McNamara) |
| Draft checked by a reader without the writer's context | A colleague or agent with minimal context can state what the text asks or claims | Pinker (Harvard Gazette); Anthropic "Key test"; Clements Rule 7; digital.gov Test for understanding | Author writes from own head |
| Long text written from an explicit outline that the final text matches | Reconstruct outline from headings; compare with plan | DOC / Re3 / single-turn planning (abstract-level); Kintsch macrostructure; McNamara macrosignals | Loss of global plan; self-contradiction |

## Structural devices placed before the body

| Device | What sources say | Evidence strength |
|---|---|---|
| Audience statement ("aimed at…", "assumes you know…") | Google tech writing Documents: "A good document explicitly specifies its audience." digital.gov: "write for your audience" is the first rule. Clements Rule 1. Anthropic: Skill description states what and when. | Experimental support: McNamara 1996 shows the same text is better or worse depending on reader knowledge, so the audience decides the right explicitness (pp. 33-36). Style-guide consensus otherwise. |
| Scope and non-scope | Google tech writing Documents, verbatim above. | Guideline, no experiment located. |
| Purpose or problem, then the answer first (SCQ then A; inverted pyramid; summary up front) | Minto's site: identify "the question in your reader's mind" then present ideas "under a single point". NN/g: conclusion first because 79% scan and the F-pattern concentrates gaze on the first lines. Microsoft: "Get to the point fast." digital.gov: "Summarize lengthy documents up-front." Google: readers "may be in a hurry". | NN/g 1997 measured usability: concise + scannable + objective rewrite 124% better than control. Eyetracking (F-pattern) supports front-loading. Minto's book-level claims unverified. |
| Description of what the document does and when to use it (frontmatter) | Anthropic skill best-practices: description "should include both what the Skill does and when to use it", third person, specific key terms. Google Headings: title based on "the primary purpose of the document". | Anthropic's own guidance for agent readers; aligns with Google. |
| Topic headers and a linking sentence per paragraph (macrosignals) | McNamara 1996 p. 21: topic headers plus macropropositions linking each paragraph to the overall topic. | Experimental: these signals improved low-knowledge readers' performance (p. 33). |
| Table of contents for long reference | Anthropic: "For reference files longer than 100 lines, include a table of contents"; Microsoft: navigation within long documents. | Guideline. |

## Gaps: what could not be verified

- Flower 1979 full text: only the abstract and one p. 19 quotation verified. The "narrative structure / survey structure / code words" terminology is from secondary sources. Flower & Hayes 1981 not reached.
- Pinker 2014: book text unreachable (403/404 on all excerpt hosts). Curse-of-knowledge definition and the "show a draft to a representative reader" remedy verified from Pinker's own spoken words in Harvard Gazette and New Republic; "single best explanation", chunking (p. 67), functional fixity, and chapter 5 content are from summaries.
- Williams: no legitimate full text reachable; all principle wording is from secondary sources and lesson/page numbers from a TOC listing.
- Gopen & Swan: verified from the LibreTexts licensed reprint; the American Scientist page returned 503 twice.
- Minto: only barbaraminto.com pages verified; the three pyramid rules, vertical/horizontal logic and MECE wording are unverified against the book.
- Grice 1975: no text-layer PDF found; maxims quoted from the Stanford Encyclopedia of Philosophy entry "Implicature", which cites Grice 1975: 26-30. Grice's exact imperative wording ("Make your contribution as informative as is required", "Be orderly") is unverified.
- Haviland & Clark 1974, Clark & Haviland 1977, Kintsch & van Dijk 1978: PDFs are image scans; no extractor available in this environment (pdftotext, pypdf, mutool absent). Claims rest on the Benjamins annotation (via search) and on McNamara et al. 1996's description of the model.
- ISO 24495-1:2023: iso.org returned 403; principle wording taken from vendor catalogue summaries found by search; clause 5.1 guidance on identifying readers unverified.
- plainlanguage.gov guideline sub-pages ("Identify your audience", "Address separate audiences separately", "Put the most important information first") now redirect to digital.gov, where those specific sub-pages were not found; the digital.gov pages cited above were verified.
- BBC/journalism primary source for the inverted pyramid: not fetched; NN/g's description used instead.
- LLM papers: Mündler et al. and ConStory-Bench abstracts verified; DOC, Re3 and the single-turn planning paper are cited from search snippets only, so their percentages are unverified.
- Google and Microsoft style guides contain no explicit rule "keep examples free of irrelevant detail"; that criterion rests on Grice and Anthropic.
