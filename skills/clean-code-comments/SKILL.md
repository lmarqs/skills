---
name: clean-code-comments
description: >-
  Decide whether a code comment earns its place — write the good ones, drop the rest. On the Clean Code
  premise that a comment is a small failure of expression: the best comment is the one you found a way not
  to write, since comments aren't tested and drift into lies as code changes. Before commenting, try to say
  it in code (clearer name, extracted function, named constant); reach for a comment only when code can't
  carry the meaning — intent behind a decision, a warning of consequences, an external constraint, legal
  text, a TODO, public-API docs. Use it writing new code AND auditing existing code or a PR diff: catch
  comments that just restate the code, commented-out code,
  changelog and byline comments, noise, banners, closing-brace labels, and stale comments that no longer
  match the code — saying why each is a smell, with the rewrite. Reach for it whenever someone writes,
  reviews, or cleans up comments, asks "should I comment this" or "review these comments", or when a comment
  just paraphrases the line below.
---

# Clean code: comments

The real work here is **judging whether a comment earns its place — not mechanically adding or stripping
comments.** Anyone can run a "comment every function" linter; the skill is knowing that most comments are
a confession. A comment is a small failure of expression: you write one because the code couldn't say the
thing on its own. So the bar is high, and it cuts both ways — a useful comment that survives the bar is
worth keeping and worth writing; a comment that fails it is noise to remove.

Three premises sit underneath every judgment. Keep them in view:

- **The best comment is the one you found a way not to write.** Before reaching for a comment, try to make
  the code say it: a more honest name, a function extracted with a name that *is* the comment, a named
  constant in place of a magic number, a guard clause that makes intent obvious. Clear code with few
  comments beats clever code propped up by many. Spend the effort cleaning the code, not narrating the mess.
- **Comments lie, and they lie more as time passes.** Code is executed and tested; comments are neither.
  Nothing forces a comment to stay true when the line beside it changes, so comments drift away from the
  code they describe. An out-of-date comment is worse than no comment — it actively misleads. The longer a
  comment has lived next to changing code, the more suspect it is.
- **"Don't comment bad code — rewrite it."** When code is so tangled it *needs* a paragraph to be
  understood, the comment is treating a symptom. The fix is almost always to untangle the code until the
  comment is unnecessary, not to write a better comment.

This is not "comments are forbidden." Some comments carry meaning that code structurally cannot — *why* a
decision was made, a warning about a non-obvious consequence, a constraint imposed from outside. Those
earn their place. The job is to tell the two apart.

## How to work

You may be writing new code, reviewing a PR diff, or cleaning up an existing file. Work it in this order:

1. **For every comment (or every comment you're about to write), run the test: can the code say this
   instead?** If a clearer name, an extracted and named function, a named constant, or a small
   restructuring would carry the meaning, that's the fix — prefer it over the comment. Reach for `references/
   refactor-over-comment.md` for the specific moves (the most important technique in this whole skill).
2. **If code genuinely can't carry it, classify the comment.** Read `references/comment-catalog.md` — the
   catalog of comment types that *earn their place* (intent, warning, clarification of an external
   constraint, legal, TODO, amplification, public-API docs) and the *smells* that don't (redundant,
   misleading/stale, mandated, journal, noise, banners, closing-brace, bylines, commented-out code, too
   much information, nonlocal). Match what you have against it.
3. **For each smell found, deliver the rewrite, not just the verdict.** Saying "this comment is redundant"
   is half the job. Show what to do: delete it, replace it with a better name, extract the function,
   promote it to a named constant — whatever removes the need. For a stale comment, either correct it or
   delete it. For commented-out code, delete it (version control remembers).
4. **For comments that earn their place, make sure they say *why*, not *what*.** A good comment explains
   intent or consequence — the thing the reader can't recover by reading the code. If a "good" comment is
   really just restating what the code does, it's a redundant comment wearing a nice label; send it back to
   step 1.

## The comment catalog (index)

Full detail — what each is, why it helps or hurts, and a to-avoid/preferred example — is in
`references/comment-catalog.md`.

**Comments that earn their place:**

1. **Intent** — *why* a decision was made, when the reasoning isn't visible in the code.
2. **Warning of consequences** — flags a non-obvious cost or danger ("not thread-safe", "runs for hours").
3. **Clarification** — translates an obscure value from an API/constraint you can't change.
4. **Legal** — copyright/license headers required by policy.
5. **TODO** — a deliberate, tracked marker for work that can't be done yet.
6. **Amplification** — stresses why something that looks trivial actually matters.
7. **Public-API documentation** — docstrings/Javadoc for a *published* interface with outside consumers.

**Smells — remove or rewrite:**

8. **Redundant** — restates the code; adds reading without adding meaning.
9. **Misleading / stale** — no longer matches the code; actively lies.
10. **Mandated** — comments added only to satisfy a "comment everything" rule; pure noise.
11. **Journal / changelog** — a history log in the source; that's version control's job.
12. **Noise** — states the obvious ("default constructor", "the day of the month").
13. **Banners / position markers** — ASCII dividers and section headers shouting in the file.
14. **Closing-brace** — `} // end while`; a signal the block is too long — extract instead.
15. **Bylines / attributions** — "added by X"; version control already tracks authorship.
16. **Commented-out code** — dead code left in place; delete it, history keeps it.
17. **Too much information / nonlocal** — irrelevant backstory, or a comment describing distant code.

## Output

Match the situation. A quick "should I comment this?" wants a direct answer plus the code-first
alternative. A PR review wants findings anchored to the offending lines, each with the rewrite. A file
cleanup wants the edited file with smells removed and the survivors justified. Whatever the shape, every
finding carries the same two parts — **why it's a smell** (or why it earns its place) and **the concrete
rewrite**. Lead with the comments that actively mislead (stale, misleading) — a lying comment costs more
than a merely redundant one — then the noise.

Don't strip comments blindly. A comment that explains intent, warns of a consequence, or clarifies an
external constraint is doing work code can't; keep it, and if anything make it clearer. The goal is fewer,
truer comments — not zero comments.

**Write your findings in English**, regardless of the language of the code or its comments. Keep
identifiers, string literals, and the comment text you're quoting verbatim from the source — translate the
analysis, not the code.

## References

- `references/refactor-over-comment.md` — the central technique: turning a comment into code (better names,
  extract-and-name a function, named constants/explanatory variables, guard clauses). Read it first — most
  "should I comment this?" questions are answered by removing the need for the comment.
- `references/comment-catalog.md` — the full catalog: the 7 comment types that earn their place and the 10
  smell categories, each with what it is, why it helps or hurts, and a to-avoid/preferred example. Read it
  when classifying any comment or reviewing a diff.
