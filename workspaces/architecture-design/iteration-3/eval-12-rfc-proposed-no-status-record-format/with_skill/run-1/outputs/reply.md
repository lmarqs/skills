# Reply

I wrote the design doc as a proposed RFC. I added no files to the repository, because its records format says a record is only written once a decision is taken.

**Files created or modified**
- Created: `document.md`
- Nothing was created or modified in the repository.

**What the document says**
- **Status:** it stays proposed while two blocking questions are open. Q1 asks legal whether files and their backups may go to an outside provider at all. It also asks whether that provider may be one subject to non-EU law (for example a US cloud in an EU region), or must be EU-headquartered. Q2 asks the product owner how many files, how large, and for how long.
- **Leaning:** it recommends an S3-compatible object store with the file details (owner, size, state) kept in Postgres, unless Q2 shows only a small amount of data.
- **Rejected:** local disk on each host is ruled out whatever legal says. The repo's ADR 0001 shows the API runs on several hosts that are replaced routinely, so a file stored on one host is unavailable from the others and is lost when that host goes.
- **Decision table:** it maps each combination of the two answers to an option. When no outside provider is allowed, the answer is a Postgres binary column for small volumes, or a self-hosted object store otherwise.
- **Options added:** a Postgres binary column, a shared network file system, a hosted upload service, and doing nothing. Each was compared against requirement IDs with risks, mitigations and fallbacks, and the shared assumptions are written down.
- **Requirements I added:** deleting a file on request and listing every place a copy is held. Both come from GDPR and are recorded as stakeholder conflicts in case the requester objects.
- **Assumptions:** the repo has no code or metrics, so every number is labelled measured, estimated or assumed, with an owner who can confirm it. For example, about 1.44 TB after three years is estimated from an assumed 20,000 uploads a month at 2 MB each.
- **Diagrams:** four Mermaid diagrams covering components, the upload/download sequence, the new table and deployment.

I skipped the two review checkpoints because you asked for the document in one go. At those points I would have asked:
1. Whether the files can contain personal data.
2. Who makes the final call.
3. Which upload volumes to plan for.

**How I decided what to write into the repository**
The repository keeps decision records in `docs/adrs/`, so I followed its format. The `README.md` there says one file per decision, `NNNN-<slug>.md` built from `template.md`, and "a record is written only for a decision that has been taken". The template has no status field, so a record would read as decided. This decision is still proposed because of the open legal and volume questions, so writing `0002-*.md` now would claim a decision that has not been made. Instead the document lists "write `docs/adrs/0002-<decision-as-slug>.md` from the template, linking this document, once accepted" as a task. The repository also has no folder for design documents (only the records folder), so the full document belongs in the issue or pull request that carries the decision. That is why it went to the output path, not into the repo.
