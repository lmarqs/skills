# Reply

I wrote the full decision document and added one ADR to the repository. The ADR is left uncommitted.

**Files created**
- `document.md` is the full decision document. It records the decision as accepted, with Dana as the decider, using one-person sign-off after consulting the team.
- `docs/adrs/0003-keep-login-sessions-in-a-shared-session-store.md` is a short ADR in the repo's own format: Status, Context, Decision, Consequences.

No existing file was modified.

**How I decided what goes into the repository**
The skill does not say where the document should live, so the full document went to the requested `out-11/document.md`. The repository has its own rule, though. ADR-0001 says decisions are recorded as numbered files in `docs/adrs/`, and the user asked for the decision to be "on record". In this repo, being on record means a file in `docs/adrs/`. So I added `0003-keep-login-sessions-in-a-shared-session-store.md`, numbered after the existing two and written in their short four-section shape, rather than dropping the long document into the repo in a different format. It covers:
- what the decision is and the options that were rejected, with one reason each;
- the design points that matter later: an ID-only cookie, deleting the session and waiting for a store replica to confirm before replying to logout, and treating users as logged out when the store is unreachable;
- how the change rolls out and how to roll it back;
- how the decision will be checked, and a review date of 2027-01-30.

It is marked as related to ADR-0002 rather than replacing it. ADR-0002 already noted that replicas don't share memory, and its title called the replicas "stateless". This decision makes that title true. I did not edit ADR-0002 because nothing in it is superseded.

**Key choices in the document, all stated inline**
- **Security's rule is a requirement, not a constraint.** The security team is inside the organisation, so it can't impose a constraint in this method. "Immediately" became something testable: once the logout response is sent, all four replicas reject the session, including a copied cookie.
- **20 KB and all traffic figures are marked as assumed.** Nobody has measured them, and the plan measures them before the store is sized.
- **The one real outside constraint is the browser cookie size limit (RFC 6265 §6.1).** It is the reason signed cookies would need five or more cookies on every request.
- **The team's agreement is recorded as a prior decision, not taken as given.** The shared store was compared against sticky sessions, signed cookies and doing nothing, plus two options nobody had raised: a small signed cookie with a shared list of logged-out sessions, and a bought hosted login service. The logout requirement rules out signed cookies, and the hybrid only works by adding the same shared store. Surviving deploys rules out sticky sessions. The analysis lands on the option the team already agreed.
- **No question is left open that would block "accepted".** The store product (I recommend a managed Redis-compatible store with a copy in a second zone) is left for Dana to confirm, because any store that passes the checks satisfies the decision.
- **The conflict is written down.** If the store goes down, users are logged out, because the logout rule is ranked above staying logged in.

Had this been interactive, I would have asked the security team to confirm my reading of "immediately". I would also have asked for one week of session-size data before treating 20 KB as firm.
