# Reply

The RFC is in `document.md`. It is **proposed, not decided**: two questions are open whose answers
change the design, so I stopped short of an accepted status. Recommendation, in one line: versioned
object store behind a CDN on a company subdomain, published through a browser upload page authorized by
one publisher group, every version kept 365 days with permanent deletion denied to publishers.

Because this was a one-shot run I could not ask anything, so everything below that would have been a
question is either an assumption labelled in the document or a question listed here.

## What I reclassified, and why

Your list had eight items in it. One survived as a requirement in the form you gave it.

| What you said | Where it went | Why |
| --- | --- | --- |
| Stakeholders: Marketing, Finance, the CTO, Support | Nine usage roles in the stakeholder table | Departments do not use systems. Marketing split into three roles that want different things — authoring, requesting a change to someone else's page, reading. The CTO split into three: domain operator, approver of what carries the company name, and the person who would have to run whatever gets built. Finance became the budget owner approving recurring spend. Support became a role whose relationship to these pages I could not determine, which is why it is the concrete test inside blocking question Q1 |
| "Intuitive" | Stakeholder attributes + requirement N1 | Not measurable as written. The part that is real ("no terminal, no git, no build step") is an attribute of the roles; the part that is checkable became N1: a publisher who did not write the page replaces its content unaided in 10 minutes or less, 4 of 5 people tested |
| "Fast" | Requirements N1 and N2 | Ambiguous, and the ambiguity matters. Your description of the problem is turnaround (chat request → change live), not page speed. N1 is turnaround, N2 is page load at 2,500 ms p75. If only one was meant, it is N1, and N2 can be dropped |
| "Secure" | F4, F5, F6 | A category, not a requirement. It decomposes into attribution (who changed what, when), authorization (only a named publisher group can change what the domain serves), and audience control (who may read a page) — three different owners, three different proofs |
| "Guarantee that nothing is ever lost" | Requirement N3 + decision driver 2 | Nothing is verifiable at "never", and a design does not guarantee. It became a bounded window that can pass or fail: non-current and deleted versions retrievable for at least 365 days, restore in 15 minutes, exercised by a quarterly drill |
| "Publish on a company domain, not a personal one" | Prior decision (yours), plus requirement F1 underneath it | It is a decision you already made, not a requirement. It still gets an alternative beside it in the tradeoff table, and its cost to reverse is recorded: low now, high once URLs are shared |
| "About 30 pages on his own domain" | Context, labelled *assumed* | Your figure, no source. A link inventory of what the team shares confirms it in about an hour |
| "Colleagues ask him over chat" | Context and the problem statement | The one input I took as given, because it is the problem |

## Where I pushed back

- **On "guarantee".** I will not write a requirement nothing can meet. What you get instead is a number
  and a drill: if the drill cannot produce last quarter's version, the requirement failed and you find
  out in a quarter, not in an emergency.
- **On the framing.** "An internal tool that lets Marketing publish HTML pages" describes a build. I put
  three options you did not ask for in the table: point a company subdomain at the analyst's existing
  host (the smallest change that would work), publish the analyses as pages in the company wiki, and buy
  a hosted website product. The wiki option is the strongest case against my recommendation and it loses
  on exactly one thing — hand-authored HTML with charts does not survive a page editor. If the analyses
  become mostly prose and tables, the wiki wins and this document should be reopened.
- **On the baseline.** Doing nothing is in the table with its own risk row, because the real cost of the
  current arrangement is not slowness: it is that 30 published pages disappear if one registration
  lapses or one person leaves, and nobody else can republish them.

## What I added that you did not ask for

F4 (attribution), F5 (a publisher group as the only way to change what the domain serves) and F6 (per-page
audience control). They serve the operator, approver and support roles, not you, and they cost the
analyst one marking per page. The conflict is recorded in the Decision rather than buried in the Design.

I deliberately did **not** add a human review gate before a page goes live, even though "it carries the
company's name" argues for one: it recreates the exact bottleneck this decision exists to remove. You get
attribution and one-click restore instead. If a page ever causes a real problem, the proportionate
response is a review for the pages carrying client-identifying figures, not a gate on all of them.

## Questions I would have asked, in this order, each with my recommended answer

**Blocking — the status stays proposed until these two are answered.**

1. **Are these pages meant for anyone with the link, including customers, or only for people with a
   company account?** The concrete test: does a support agent send these links to customers today, or
   would they want to? *My recommendation: company-account-only as the default, per-page exceptions.*
   Switching a page from closed to open costs nothing; the reverse means it was already public. This is
   the only question whose answer changes the CDN requirement, so it is worth a day.
2. **Do any of the 30 pages, or the analyses planned next, contain personal data or client-identifying
   figures?** *My recommendation: assume yes until someone has actually looked.* If yes, public serving
   without access control is off the table on data-protection grounds, F6 becomes mandatory, and the
   365-day retention needs a real deletion path — which is why the design gives the operator identity one
   and denies it to publishers.

**Non-blocking — I proceeded on an assumption and named it.**

3. **What recurring monthly cost can the budget owner approve once, without a case-by-case
   negotiation?** I assumed USD 50/month at 30 pages (N5). The recommended option is the cheapest on the
   table, so the answer probably does not change the decision — unless the answer is "no recurring line
   at all", in which case it does.
4. **Which directory holds everyone's company account?** I assumed one exists and that the publisher
   group lives in it. If it does not, the publishing path needs its own accounts and the operational load
   rises; the winning option does not change.
5. **Will the head of marketing commit to N1's 10 minutes and N3's 365 days?** Both are my numbers
   standing in for that person's. I would rather have theirs.

## Assumptions you should read as warnings

- **Nothing in the Context is measured.** There was no repository, hosting panel, bill, ticket queue or
  access log available, so every current-state figure is labelled *assumed* with the way to confirm it
  named in the row. The document says this once, at the top, rather than repeating it on every line.
- **N1, N3 and N5's targets were derived from phrases in your request**, not from a baseline. That is the
  weakest part of the document. Phase 1 of the launch strategy exists partly to replace those labels with
  measurements, and the confirmation section measures the assumed targets before trusting them.
- **N2's 2,500 ms is the only number with an external anchor** (the Core Web Vitals "good" threshold for
  largest contentful paint at p75). No current page-load figure exists for comparison.
- **Support's role is the largest gap.** I could not tell from your description whether Support reads
  these pages, sends them to customers, or has nothing to do with them. I put the role in the table with
  the honest label and folded the question into Q1, because the answer decides whether the pages are
  public.

## Caveats on the recommendation itself

- It leaves you owning a small internal tool. Deliberately tiny — upload, list versions, restore, delete
  — but the roadmap has "name an owner" as a task rather than an assumption, because that is what stops
  it rotting into the next bottleneck.
- Any publisher can change any page. That is what makes the colleague-publishes-the-fix case work, and it
  is also the thing the approver role will dislike. Version history is what makes it safe rather than a
  policy document.
- The personal domain stays alive as a redirect source for 90 days after migration, so you depend on it
  slightly longer than today. The difference is that the dependency now ends on a date rather than
  whenever a payment card expires.
