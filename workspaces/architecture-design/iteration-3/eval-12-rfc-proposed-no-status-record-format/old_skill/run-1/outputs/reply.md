# Reply

I wrote the design doc to the output path and left the repository unchanged. The doc's status is "proposed". It recommends an S3-compatible object store, but which provider can be used depends on legal's answer, so the choice stays open until then.

**Files created or modified:**
- Created: `document.md` (526 lines)
- Nothing created or modified in the repository (`git status` is clean).

**What the document contains:**
- **Sizing:** a one-way door for where the files physically sit, and close to a two-way door for which storage product holds them, as long as the code reaches storage through one internal interface.
- **Context:** built from ADR 0001 in the repo, which says the API ships as one binary copied onto several hosts with no container runtime. Everything the repo can't show (upload volume, file sizes, whether uploads exist today, that the database is Postgres, where the hosts run) is labelled as an assumption, with what would confirm it.
- **Constraints vs open questions:** GDPR Chapter V (transfers outside the EU) and Art. 17/12(3) (erasure within a month) are recorded as constraints. Two blocking questions hold the status at proposed:
  - **B1, legal (proposed date 2026-11-20).** The doc rewrites "may files leave the EU?" because all three named options can keep files inside the EU. What actually separates them is whether a non-EU provider's EU region is acceptable.
  - **B2, operations (proposed date 2026-11-06).** In which country the hosts, the database and its backups run.
- **Requirements:** four functional and five non-functional. Two of them (erasure and a file-location report for legal) are my additions; the doc flags them as not yet reviewed by the requester.
- **Diagrams:** three Mermaid diagrams (components, a sequence, and a view of which country each copy sits in).
- **Options compared:** the three named options, plus a shared network filesystem, a self-hosted S3-compatible store, Postgres `bytea` columns, two ways for bytes to travel (through the API or via direct links), and a do-nothing baseline.
- **Recommendation:** an S3-compatible store with file records in Postgres, bytes passing through the API. A table maps each possible B1 answer to a managed provider, an EU-owned provider, a self-hosted store, or Postgres large objects. The doc spells out the three conditions that together would make Postgres large objects the right choice instead.
- **Decider:** assumed to be the API tech lead, since the request names no one.

Because you asked for it in one go, I skipped the review checkpoints. At the requirements checkpoint I would have asked the requester to confirm the two added requirements and the assumed 4-hour restore target. At the tradeoff checkpoint I would have asked them to confirm the ranking of the decision drivers.

**How I decided what to write into the repository:** The skill doesn't say to put the document in the repo, so it went to the output path. I still checked the repo for a convention that might call for it. `docs/adrs/README.md` says a record is written "only for a decision that has been taken", and the ADR template there has no Status field, so it can't hold a proposed decision. This decision isn't taken: it waits on legal (B1) and on where the hosts run (B2). Adding `docs/adrs/0002-...` now would break the repo's own rule and present an open question as settled. So I left the repo unchanged and added a roadmap task: once the decision is accepted, write ADR 0002 from that directory's template and link it to this document.
