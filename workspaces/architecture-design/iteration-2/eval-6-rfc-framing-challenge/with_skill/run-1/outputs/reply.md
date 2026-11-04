# Reply

**Rust, with Typst, for the renderer — and don't act on that pick yet.** The RFC is in
`document.md`. Two things in it are not what you asked for, and both are deliberate.

## I challenged the framing, once, with evidence

"Rust or Go, pick one" narrows the option space before the bottleneck is located. The checkable part:
an independent benchmark (speedata, 2026-02-10; `hyperfine`, MacBook Air M4) put WeasyPrint — the most
common Python HTML-to-PDF path — at **17.3 ms per page** over 500 pages, so 40 pages of layout is
about **0.7 s**. You are seeing 12 s. Roughly **94% of the time is unexplained by page layout at
benchmark rates**, and a language rewrite only pays on the layout part. Either your template hits
WeasyPrint's global-pagination pathology (its issue tracker has repeated long-document reports), or the
11 s is database queries, per-page image fetches, template and font parsing — in which case a Go or
Rust rewrite carries that same 11 s into a new codebase and finance keeps complaining.

I also narrowed the **unit of work**. "Rewrite the service" fuses the renderer (the part that might be
slow, one function boundary wide, swappable behind a flag in days) to data assembly, templating, auth,
storage and the API (the ~95% nothing has implicated). Rewriting the service is a one-way door;
replacing the renderer is a two-way door. The RFC recommends the two-way doors first, because a
two-way door that works makes the one-way door unnecessary.

If you read this and still want the service rewritten, that's your call to make — but then it goes into
the document as a prior decision with you as its author, not as an architectural conclusion.

## The pick, since you asked for one

**Rust + Typst**, for the renderer only, conditional on the profile. Not because of the language:
because nobody should hand-code invoice pagination, so the deciding factor is whether a maintained,
permissively licensed layout engine exists.

- **Rust has one.** Typst: Apache-2.0, embeddable as a crate, stable 0.15.1 (2026-07-17), fastest of
  six engines benchmarked (0.3 ms/page at 500 pages).
- **Go does not.** `jung-kurt/gofpdf` was archived read-only on 2021-11-13. UniDoc's `unipdf` is
  AGPL-3.0-or-commercial and watermarks every page until you buy a licence. The newer pure-Go
  HTML-to-PDF engines are young and thinly maintained (I did not evaluate them).
- Go's real advantages — shorter ramp from Python, easier hiring, better batch concurrency — apply
  least to this component: it is small, its interface is one function, and rendering parallelises
  across processes, not goroutines.

**Two named conditions flip it to Go**, and they're in the document so it isn't an argument later: if
your templates can't be ported to Typst markup while still matching the invoices customers already
hold, the native path becomes a small service driving a browser engine and Go wins on ramp; and if the
real problem is month-end batch throughput rather than one analyst's wait, the lever changes to
parallel fan-out, where Go's concurrency is worth more than Typst's speed.

## Questions I would have asked (you said one-shot, so they're assumptions in the document)

Three are **blocking** — the RFC's status stays *proposed* until they're answered, and each one can
change the decision:

1. **Where do the 12 seconds actually go?** My recommendation: a 3-day profile (sampling profiler +
   per-query timing + read the dependency manifest to see which PDF library you're on), attributing at
   least 90% of wall clock to named phases. If layout is the minority, no rewrite in any language is
   justified and the pick I gave you goes on the shelf.
2. **Is the invoice PDF statutory or contractual — must a re-rendered invoice match the one already
   sent?** My recommended answer: assume yes. If it is, output fidelity becomes a veto criterion and
   the cost of any engine change rises sharply, which is why I put a 200-invoice regression suite in CI
   as the gate.
3. **Does a month-end batch exist, and what's the volume and close window?** My recommended answer:
   assume it does. If it does, the requirement is throughput, not per-document latency, and that's one
   of the two conditions that flips the language pick.

One more, non-blocking on the decision but it kills an option: **may invoice contents be sent to a
third-party rendering service?** If no, that row is excluded by clause.

## Assumptions, labelled

Every current-state figure in the document is labelled ***assumed*** with you as its origin, because
there was no codebase, dashboard, schema or ticket to read. Specifically:

- **The 12 s itself.** No instrument was cited. First task in phase 0 is timing the twenty largest
  invoices of last quarter. If the true figure is 3 s, storing rendered invoices may already meet the
  goal on its own.
- **What the complaint is.** I assumed it's the wait. It could be a batch overrunning the close window
  or requests timing out, and those want different fixes. Ten minutes with the finance lead settles it.
- **Which PDF pipeline you're on.** I laid out the three candidates and what a rewrite buys in each.
  If it's headless Chromium, the host language buys close to nothing and both rewrite options are
  mostly wasted effort.
- **N1's 2 s target.** Derived from your 12 s plus the attention band (~1 s stays in flow, ~10 s is
  where users switch tasks; Nielsen 1993 after Miller 1968). The exact number is mine, not finance's.
  Renegotiate it with them first — the confirmation section commits to measuring it before defending it.
- **All the usage rows and every role.** Invented from "the finance team complains", each with what
  would confirm it.

## What was reclassified

- **"In Rust" / "in Go"** → design choices. They are rows in the tradeoff table, not requirements.
- **"Rewrite the service"** → also a design choice, about the unit of work. It gets its own row and
  loses on reversibility.
- **"Rust or Go, pick one"** → a prior decision with you as its author and a reversal cost of nothing.
  Under this method a prior decision never excludes an option, so the five options your framing left
  out (store rendered invoices, deliver asynchronously, fix data access, swap the engine while staying
  in Python, buy it) all got rows.
- **"The finance team complains constantly"** → the problem statement, in Context.
- **"12 seconds"** → a current-state measurement, so it's N1's derivation rather than a requirement.

Three requirements I deliberately did **not** write, because inventing a target is worse than naming
the gap: batch throughput (blocked on question 3), retention and reproducibility (blocked on question
2), and cost of ownership (no cost figures available). Each is named in the blocking-question table
with what it would change.

## Caveats on my own evidence

- The benchmark I lean on used a **mail-merge template**, not an invoice with tables spanning pages.
  Your real template could be far slower per page. That cuts both ways and is exactly why question 1
  blocks: 12 s sits between the benchmark floor (~0.7 s) and the pathological reports (tens of seconds
  for 50-100 pages), and which side you're on decides everything.
- The "~84 s for a 52-page document" figure came from a search summary of the WeasyPrint issue tracker
  and I did not verify it against the thread. It's labelled as such in the document.
- I did not evaluate the newer pure-Go and pure-Rust HTML-to-PDF engines (papyrus, gpdf, fulgur and
  similar). I assumed they're too young for a document with legal weight. Half a day on their issue
  trackers and release cadence would settle it, and it's part of the phase 3 spike.
- I skipped both interactive checkpoints (after requirements, after the tradeoff table) because you
  asked for the document in one go. The one I'd most want back is the requirements: everything
  downstream is judged against F1, F2, N1 and N2, and you haven't seen them yet.

## What I'd do Monday

Phase 0 is 3 engineer-days and can end the whole project. Phase 1 (render an issued invoice once, store
the bytes, move rendering off the request path) is about two weeks, helps under every branch, and is
where finance first feels relief. The Rust decision is phase 3, and only if N1 is still missed after
that.
