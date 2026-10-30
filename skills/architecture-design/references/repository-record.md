# The repository's decision record

Many repositories keep their own short decision records in one directory: `docs/adr/`, `docs/adrs/`,
`doc/architecture/decisions/`, `docs/decisions/`. Each is a short file in a fixed format (Nygard's
four sections, MADR, or a house template). The full document from this method is several pages and
cannot become one of those files without losing the analysis. So, when the repository keeps records,
the decision leaves as two artifacts: the full document, which holds the analysis, and the record,
written in the repository's format, which states the decision and links the document.

## Contents

1. [When it applies](#when-it-applies)
2. [Detect the format](#detect-the-format)
3. [Number and name the record](#number-and-name-the-record)
4. [Fill the sections](#fill-the-sections)
5. [When to write it](#when-to-write-it)
6. [Where the full document goes](#where-the-full-document-goes)
7. [Superseding an earlier record](#superseding-an-earlier-record)
8. [Two-way doors](#two-way-doors)
9. [Example](#example)

## When it applies

The repository keeps records when it has a records directory with at least one record, or a record
template (`adr-template.md`, `template.md`, `0000-template.md`), or a README or contributor guide that
names one. Look before writing; never invent a records directory for a repository that has none. A
retrospective technical document gets a record too when it documents a decision the records directory
does not hold yet.

## Detect the format

Read, in this order, and stop at the first that settles it:

1. A template file in the records directory or the docs tooling (`adr-template.md`, a `.adr-dir`
   file from adr-tools, a log4brains or MADR config).
2. A README, index or map in the records directory, or the contributor guide's section on records.
3. The two or three most recent records: their headings, front matter, status values, and how they
   link to each other.

Write the sections the format has, in its order, with its heading names and in the language the
records use. **Never add a section the format lacks**: the full document holds requirements, the
tradeoff table, residual risks and confirmation, and the link reaches them. A format with front
matter (status, date, deciders) gets it filled the same way the latest records fill it.

## Number and name the record

Follow the repository's rule, read from the existing file names: zero-padded sequence
(`0007-keep-sessions-in-a-shared-store.md`), date prefix, or plain slug. The next number is one above
the highest in the directory, counting superseded records. If the directory keeps an index or table of
records, add the new row there too.

The title is the decision taken, as a sentence: "Keep sessions in a shared store", not "Session
storage" (the problem) and not "Redis" (the product).

## Fill the sections

| Record section (Nygard / MADR minimal) | Filled from the full document |
| --- | --- |
| Title | The decision taken, as a sentence |
| Context / Context and Problem Statement | Context's problem, plus the decision drivers from step 4, in priority order |
| Options / Considered Options | One line per row of the tradeoff table, the baseline included: what the option offers, then the driver it fails |
| Decision / Decision Outcome | The chosen alternative, the drivers that carried it, and the link to the full document |
| Consequences | Step 5's consequences: what becomes easier, what becomes harder, what the team now maintains |
| Status (only if the format has it) | Step 5's status |

Each sentence in the record is still true on its own, with its number and its source where the
document had them: the record summarizes and points, it never says "see the RFC" in place of a fact.
State each rejected option at its best here too; one line is enough to name what it offers before the
driver it fails. A format with sections beyond these (Decision Drivers, Pros and Cons, Confirmation,
More Information in full MADR) gets them filled from the matching part of the document.

## When to write it

If the format has a status field, write the record with the document, at step 5's status, and update
it when the status changes. If it has none, a record there reads as decided, so write it only once the
decision is accepted; until then, the record is a task in step 6's tasks list.

## Where the full document goes

Prefer the repository. If it has a place for design documents (`docs/rfcs/`, `docs/design/`, a
directory beside the records), put the document there and link it by relative path. Otherwise the
document lives in the issue or pull request that carries the decision, and the record links that URL.
An issue body can be edited after the record merges, so the document's version history is what tells
a later reader which version the record summarized. Either way, the document links back to its record
once the record exists, in its Sources or version history.

## Superseding an earlier record

When the prior decisions table lists an earlier record and this decision reverses it, do what the
repository does when one record replaces another: in Nygard and MADR, the old record's status becomes
"Superseded by [N](link)" and the new record names the one it replaces in its Context. Change nothing
else in the old record; it stays the account of what was decided then. In a format with no status
field and no supersession practice, the new record names the old one in its Context, and the old one
is left as it is.

## Two-way doors

The light shape for a two-way door is already about the size of a record, so it *is* the record: write
it directly in the repository's format, with no separate document and no link. The Y-statement
becomes the Context and Decision, the one-line options become Options, and the confirmation goes
where the format keeps it, or into Consequences.

## Example

The full document *Session storage for the web tier*, an RFC in the issue that carries it, compares
sticky sessions, signed cookies and a shared store against three drivers. The record it produces in a
repository using Nygard's format, with the last record numbered 6:

```markdown
# 7. Keep sessions in a shared store

## Status

Accepted

## Context

Four web replicas sit behind a round-robin balancer; a login held in one replica's memory is lost
when the next request reaches another. Drivers, in order: a deploy must log no one out; logout must
end a session at once; a session holds up to 20 KB.

## Decision

Sessions live in one store every replica reads, with a 30-minute expiry each request renews. It is
the one option that survives a deploy and ends a session by deleting its key. Sticky sessions need no
new service, but a deploy's restart logs out that replica's users. Signed cookies keep no server
state, but a cookie cannot be ended before it expires, and 20 KB exceeds the 4 KB a browser keeps per
cookie. Full analysis, requirements and confirmation:
[RFC: session storage](https://github.com/acme/web/issues/123).

## Consequences

Any replica serves any request. The store joins the services a deploy depends on.
```

Nygard's format has no Options section, so the rejected options ride in the Decision as one sentence
each. In a format that has one, such as MADR's Considered Options, they go there instead.
