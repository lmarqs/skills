# Comment catalog

Two lists. The first is the comments that **earn their place** — they carry meaning that code structurally
can't, so they survive the "could the code say this?" test in `refactor-over-comment.md`. The second is the
**smells** — comments that add reading without adding meaning, or that actively mislead. Each entry has the
same shape:

- **What it is** — the pattern, in plain terms.
- **Why it helps / hurts** — what it does for or to the reader.
- **Example** — for good comments, what a good one looks like; for smells, a to-avoid vs. preferred pair.

Examples use generic identifiers and a C-family pseudosyntax; the principles apply in any language. Quote
real comment text verbatim when reviewing — translate the analysis, not the code.

Before using this catalog, run the comment through `refactor-over-comment.md`. Many "comments" are really
naming or extraction problems, and the best outcome is no comment at all. This catalog is for the comments
that survive that step.

## Table of contents

**Earn their place**
1. [Intent](#1-intent)
2. [Warning of consequences](#2-warning-of-consequences)
3. [Clarification](#3-clarification)
4. [Legal](#4-legal)
5. [TODO](#5-todo)
6. [Amplification](#6-amplification)
7. [Public-API documentation](#7-public-api-documentation)

**Smells — remove or rewrite**
8. [Redundant](#8-redundant)
9. [Misleading / stale](#9-misleading--stale)
10. [Mandated](#10-mandated)
11. [Journal / changelog](#11-journal--changelog)
12. [Noise](#12-noise)
13. [Banners and position markers](#13-banners-and-position-markers)
14. [Closing-brace](#14-closing-brace)
15. [Bylines / attributions](#15-bylines--attributions)
16. [Commented-out code](#16-commented-out-code)
17. [Too much information / nonlocal](#17-too-much-information--nonlocal)

---

# Comments that earn their place

## 1. Intent

**What it is.** A comment that explains *why* a decision was made — the reasoning behind the code, not what
the code does.

**Why it helps.** Code can show *what* it does and *how*, but it cannot show *why this approach and not the
obvious alternative*. When the next reader's instinct would be "this is weird, let me simplify it," a
sentence of intent saves them from re-deriving (or breaking) a hard-won decision.

**Example.**

```text
// We sort before the merge even though it looks redundant: the upstream feed
// occasionally arrives out of order, and the merge below assumes sorted input.
sort(records);
```

A reader who would otherwise delete the "redundant" sort now understands the constraint. The comment earns
its place because the reason lives outside the code.

## 2. Warning of consequences

**What it is.** A comment that warns about a non-obvious cost, danger, or side effect of using the code.

**Why it helps.** Some consequences aren't visible at the call site — that a method isn't thread-safe, that
a test takes ten minutes, that a function mutates its argument. A warning lets the caller make an informed
choice instead of discovering the cost in production.

**Example.**

```text
// Not thread-safe: callers must hold the connection lock before invoking this.
void flushBuffer() { ... }
```

## 3. Clarification

**What it is.** A comment that translates an obscure value or behavior into something readable — when the
obscure thing comes from an API, a standard library, or a constraint you **can't change**.

**Why it helps.** Normally you'd fix obscurity by renaming, but you don't own a third-party return code or
a protocol's magic number. A short clarification at the point of use prevents a misread. (If you *do* own
the value, prefer a named constant — see `refactor-over-comment.md` §3.)

**Example.**

```text
response = client.call();
// 0 = success, anything else is a documented error code from the vendor SDK
if (response.code != 0) { ... }
```

## 4. Legal

**What it is.** Copyright, license, or authorship headers required by company policy or a license.

**Why it helps.** It's a requirement, not an explanation. Keep it short and point to an external license
file rather than pasting whole terms into every source file.

**Example.**

```text
// Copyright (c) 2026 Example Corp. Licensed under the MIT License; see LICENSE.
```

## 5. TODO

**What it is.** A marker for work that genuinely can't be done now — a deferred cleanup, a placeholder for
a not-yet-available dependency, a note to revisit after a related change lands.

**Why it helps.** It records a real intention at the exact spot it's relevant. The discipline: a TODO is a
promise, not a graveyard. Track them, grep them periodically, and resolve or delete them — a TODO that's
two years old is just noise. It is never an excuse to leave bad code in place that you could fix now.

**Example.**

```text
// TODO: replace with the batch API once it ships in v2 (tracked in TICKET-481).
fetchOneByOne(ids);
```

## 6. Amplification

**What it is.** A comment that amplifies the importance of something that might otherwise look
inconsequential, so a reader doesn't "tidy it away."

**Why it helps.** Some code looks trivial and removable but isn't. Amplification tells the reader the
triviality is deceptive.

**Example.**

```text
// The trim is not cosmetic: a trailing space here silently breaks the dedup
// key downstream, so do not remove it.
key = raw.trim();
```

## 7. Public-API documentation

**What it is.** Structured docs (Javadoc, docstrings, doc comments) for an interface published to consumers
outside your codebase — a library, a public SDK, a shared module.

**Why it helps.** Consumers can't read your implementation, so the contract has to be written down:
parameters, return values, thrown errors, units. The boundary matters: on a *published* API this is
essential; on internal, non-public code the same machinery becomes ceremony — a doc block restating an
obvious private method is noise (see §10, mandated). Reserve full API docs for the real boundary.

**Example.**

```text
/**
 * Converts an amount between currencies using the day's reference rate.
 * @param amount  value in the source currency's minor units (e.g. cents)
 * @param from    ISO 4217 code of the source currency
 * @param to      ISO 4217 code of the target currency
 * @return        converted amount in the target currency's minor units
 * @throws UnknownCurrencyError if either code is not recognized
 */
```

---

# Smells — remove or rewrite

## 8. Redundant

**What it is.** A comment that says exactly what the code already says, in more words. It takes longer to
read than the code and adds nothing.

**Why it hurts.** It's pure overhead — more to read, and one more thing that can fall out of sync. The
reader learns nothing they couldn't get from the line below.

**Correction.** Delete it. If the code wasn't actually self-evident, fix the name instead of narrating it.

```text
// Avoid
i++; // increment i
// Increments the counter by one.
void increment() { count++; }

// Prefer: the code already says this — delete the comment
i++;
void increment() { count++; }
```

## 9. Misleading / stale

**What it is.** A comment that no longer matches the code — it described an old behavior, or was never
quite right. The most dangerous smell, because it lies with a straight face.

**Why it hurts.** A reader trusts the comment over the code (that's what comments are for) and acts on
false information. An out-of-date comment is worse than no comment. Comments drift because nothing tests
them; the longer they sit beside changing code, the more suspect they get.

**Correction.** Make it true or delete it. When reviewing a diff, check every comment near a changed line —
stale comments are created exactly when code changes and the comment doesn't.

```text
// Avoid: the comment says one thing, the code does another
// Retries up to 3 times before giving up.
retry(5);

// Prefer: correct it (or delete and let the code speak)
retry(MAX_RETRIES);
```

## 10. Mandated

**What it is.** Comments added only to satisfy a rule that says "every function/variable must be
commented." The rule manufactures redundant and noise comments at scale.

**Why it hurts.** Forced comments restate signatures, clutter every file, and train readers to ignore
comments entirely — so the one comment that *does* matter gets skipped too.

**Correction.** Comment what needs explaining, not what a policy demands. Drop the boilerplate; reserve
doc comments for the public boundary (§7).

```text
// Avoid: a doc block that restates the signature, added only to satisfy a rule
/** @param name the name @return the greeting */
String greet(String name) { return "Hi " + name; }

// Prefer: no comment; the signature is the documentation
String greet(String name) { return "Hi " + name; }
```

## 11. Journal / changelog

**What it is.** A running history log kept inside the source file — "2024-03-01 added X, 2024-04-12 fixed
Y."

**Why it hurts.** It duplicates what version control already records, more reliably and searchably. It
grows forever and pushes the actual code down the file.

**Correction.** Delete it. `git log` / `git blame` is the changelog.

```text
// Avoid
// Changes:
//  2024-03-01 (ab) initial version
//  2024-04-12 (cd) fixed rounding
//  2024-06-30 (ef) added currency arg

// Prefer: nothing — the VCS history holds this
```

## 12. Noise

**What it is.** A comment that states something already obvious from the code or the name. Cousin of
redundant, but often even emptier — it conveys zero information.

**Why it hurts.** It trains the reader to skim past comments. Enough noise and real comments become
invisible.

**Correction.** Delete it.

```text
// Avoid
/** Default constructor. */
Foo() {}
private int day; // the day of the month

// Prefer
Foo() {}
private int dayOfMonth;
```

## 13. Banners and position markers

**What it is.** ASCII-art dividers and section headers shouting in the file
(`/////// ACTIONS ///////`, `// ===== HELPERS =====`).

**Why it hurts.** Occasionally a banner marks a genuinely important grouping, but most are visual clutter
that the eye learns to ignore — and a file that needs internal section banners is usually a file that wants
to be split. Overused, they become background noise and the rare meaningful one is missed.

**Correction.** If a section is distinct enough to need a banner, extract it into its own function, class,
or file. Use them sparingly, if at all.

```text
// Avoid
//////////////////// VALIDATION ////////////////////
... 40 lines ...
//////////////////// PERSISTENCE ////////////////////
... 40 lines ...

// Prefer: extract cohesive sections into named units
validate(request);
persist(request);
```

## 14. Closing-brace

**What it is.** A comment labeling the end of a block — `} // end while`, `} // end if`.

**Why it hurts.** It's a workaround for a block that's grown too long to see at a glance. The label treats
the symptom; the disease is the length.

**Correction.** Shorten or extract the block until its start and end fit on one screen and the label is
unnecessary (see `refactor-over-comment.md` §2).

```text
// Avoid
while (more) {
  ... many lines ...
} // end while

// Prefer: extract, so the block is short enough to need no label
while (more) { processNext(); }
```

## 15. Bylines / attributions

**What it is.** "Added by Jane", "// rcm" — authorship notes embedded in the code.

**Why it hurts.** Version control tracks authorship precisely and forever; an inline byline just goes
stale (the named person left years ago) and adds nothing.

**Correction.** Delete it. `git blame` answers "who wrote this."

## 16. Commented-out code

**What it is.** Lines of real code disabled with comment syntax and left in the file.

**Why it hurts.** It's the worst kind of clutter: nobody dares delete it ("someone must have left it for a
reason"), so it accumulates, rots, and confuses every future reader about whether it matters.

**Correction.** Delete it. Version control remembers every line you ever had; you can always retrieve it.
If it's a real alternative worth keeping, that's a decision to document with an *intent* comment (§1), not
a block of dead code.

```text
// Avoid
total = price * qty;
// total = price * qty * (1 + taxRate);   // old calc, keeping just in case
// applyLegacyDiscount(total);

// Prefer
total = price * qty;
```

## 17. Too much information / nonlocal

**What it is.** Two related over-sharing smells. *Too much information*: a comment dumping irrelevant
historical or encyclopedic detail (the full RFC, the meeting where the format was chosen). *Nonlocal*: a
comment that describes code far away from it, so it goes stale the moment the distant code moves.

**Why it hurts.** The reader has to wade through trivia to find the point, or trusts a comment that's
describing something that no longer exists where the comment claims. A comment should describe the code
right next to it and only what the reader needs here.

**Correction.** Trim to what's relevant at this spot; move information that belongs elsewhere (or to a
linked doc) out of this comment.

```text
// Avoid: nonlocal — documents a default that lives in another module
// The default timeout is 30s (set in config/server.go).
connect(host);

// Prefer: say it where it's true, or not at all
connect(host);
```
