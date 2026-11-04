# Refactor over comment

The single most useful move in this whole skill: **when you feel the urge to write a comment, first ask
whether the code could say it instead.** Most comments are explaining something the code *could* have made
obvious. A comment is inert text that nothing keeps in sync; the same meaning expressed in code is checked
by the compiler, exercised by tests, and refactored along with everything else. So a thought moved out of
a comment and into the code doesn't just remove a comment — it makes the meaning durable.

This file lists the concrete moves, each as a comment you might have written and the code that makes it
unnecessary. Examples use generic identifiers and a C-family pseudosyntax; the moves apply in any language.

## Table of contents

1. [Replace the comment with a better name](#1-replace-the-comment-with-a-better-name)
2. [Extract a function whose name is the comment](#2-extract-a-function-whose-name-is-the-comment)
3. [Introduce a named constant for a magic value](#3-introduce-a-named-constant-for-a-magic-value)
4. [Introduce an explanatory variable](#4-introduce-an-explanatory-variable)
5. [Make the structure carry the intent](#5-make-the-structure-carry-the-intent)
6. [When the move doesn't exist, the comment earns its place](#6-when-the-move-doesnt-exist-the-comment-earns-its-place)

---

## 1. Replace the comment with a better name

If a comment exists to explain what a variable, function, or parameter *is*, the name is doing too little
work. Put the explanation in the name and delete the comment.

```text
// Avoid: the comment compensates for a vague name
int d; // elapsed time in days

// Prefer: the name says it; no comment needed
int elapsedTimeInDays;
```

This is the cheapest and most common fix. A redundant or noise comment is very often just a naming
problem.

## 2. Extract a function whose name is the comment

A comment that introduces a block ("// now validate the request and load the user") is usually marking a
step that wants to be its own function. Extract it; let the function name be the sentence.

```text
// Avoid: a comment narrates a block inside a long function
// Check if the employee is eligible for full benefits
if (employee.flags & HOURLY && employee.age > 65) { ... }

// Prefer: the condition becomes a named function that reads like the comment
if (employee.isEligibleForFullBenefits()) { ... }
```

This also tends to dissolve closing-brace comments (`} // end if`): if a block is long enough to need its
end labeled, it's long enough to extract.

## 3. Introduce a named constant for a magic value

A comment explaining what a literal means is a constant waiting to be named.

```text
// Avoid
if (status == 7) { ... } // 7 = archived

// Prefer
const int ARCHIVED = 7;
if (status == ARCHIVED) { ... }
```

## 4. Introduce an explanatory variable

When a condition or expression needs a comment to be read, assign its parts to well-named variables. The
variable names become the explanation, and they stay attached to the logic.

```text
// Avoid: a comment explains an opaque regex match
// does the line look like "key=value"?
if (match(line, "...")) { ... }

// Prefer: a named variable carries the meaning
bool isKeyValuePair = matches(line, KEY_VALUE_PATTERN);
if (isKeyValuePair) { ... }
```

## 5. Make the structure carry the intent

Sometimes the comment is compensating for control flow that hides intent. A guard clause, an early return,
or splitting a function can make the comment redundant.

```text
// Avoid
// if the cache is cold we have to skip the fast path
if (!cache.isWarm) { ... } else { ... }

// Prefer: a guard clause states the same thing structurally
if (!cache.isWarm) return slowPath();
return fastPath();
```

## 6. When the move doesn't exist, the comment earns its place

The point of refactoring-over-commenting is not to ban comments — it's to make sure the comments that
remain are the ones code genuinely can't replace. After trying the moves above, some thoughts still won't
fit into a name or a function:

- **Why** a non-obvious decision was made (the alternative was tried and failed; a workaround for a known
  upstream bug). Code shows *what*; it cannot show *why this and not that*.
- A **warning** about a consequence the reader can't see (this call is expensive, this method isn't
  thread-safe).
- A **constraint from outside** your code (an API returns a magic value you don't control; a regulation
  dictates the rule).

When you hit one of these, stop trying to refactor it away and write a clear comment — that's exactly what
comments are *for*. See `comment-catalog.md` for the full set of comment types that earn their place.
