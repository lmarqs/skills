# Reply

I wrote the full decision document and one new decision record in the repository. The analysis reaches the shared store the team agreed on, but for a reason the request didn't state: making logout end a session on the next request at any replica (the security requirement, F3) needs server-side state that every replica can read. That is a shared store under any name, so signed cookies plus a revocation list end up as the same option, with a 20 KB cookie on every request on top.

**Files created**
- `document.md` (the full decision document)
- `docs/adrs/0003-keep-sessions-in-a-shared-store.md` (the repository's record)

No other files were modified. ADR 0002 is untouched.

**Content of the document**
- **Status and decider:** the status is "accepted". No open question would change whether a shared store is chosen. Dana is recorded as the decider; she owns the call after consulting the team.
- **What I reclassified:**
  - The three options moved to the comparison table.
  - The team's agreement became a prior decision, compared against alternatives rather than assumed.
  - "Immediately" was made testable as "the next request after the logout response".
  - The 20 KB figure is a size requirement, marked as assumed until measured.
- **What I added:** a requirement that losing one machine must not take the site down. It protects what ADR 0002 set out to achieve.
- **Options nobody proposed** were added to the comparison: doing nothing, going back to one instance, copying sessions between replicas, a database table as the store, and buying a hosted identity provider.
- **Unverified figures:** the repository has no application code, so session size, peak session count, deploy frequency, timeouts, latency targets and how the balancer routes are all marked assumed. Each has a way to confirm it.

**How I decided what to write into the repository.** The repository already keeps decision records in `docs/adrs/`. They use Nygard's format (Title, Status, Context, Decision, Consequences), with zero-padded numbers, "# N. Title" headings, a Status field, and ADR 0001 stating that format. Because the format has a Status field and the decision is accepted, I wrote the record now, as the next number (0003). It is titled with the decision taken, has only the four sections the format has, and states each rejected option at its best inside the Decision section, since Nygard has no Options section. This change keeps ADR 0002's round-robin routing and actually fulfils its "stateless replicas" premise, so I did not mark 0002 superseded. The repository has no place for design documents, so I kept the full document outside it instead of creating a new docs directory.

**One thing to do:** the record refers to the full document as "carried in the pull request that adds this record" instead of linking it. Once that pull request or issue exists, replace that wording with its URL; this is also listed as a task in the document. I skipped the two review checkpoints because you asked for everything in one go; the assumptions are stated inline instead.
