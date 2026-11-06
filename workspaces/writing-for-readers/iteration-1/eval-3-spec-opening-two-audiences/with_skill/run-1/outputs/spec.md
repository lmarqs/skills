---
description: Spec for letting Business-plan account admins schedule CSV exports from the reporting module, delivered by email.
audience: >-
  Two groups. Support leads, who know the manual report requests well but not the reporting
  module's internals, read "What changes for support". Backend engineers who will build the
  feature, who know the reporting module but not the support workload behind it, read
  "Constraints for the build". Both read the opening sections.
---

# Scheduled CSV exports

Account admins on the Business plan will schedule a CSV export of their reports to run daily,
weekly or monthly, and each run emails a download link to a list of addresses. Support then stops emailing usage reports by hand. This opening covers the problem,
the goal, what is out of scope, and what each reader group needs before the detailed design.
The detailed design, including scheduling, link signing and email delivery, follows in its own
sections.

## Manual report requests cost support about 35 hours a month

Business-plan customers who want their monthly usage report ask support to email it. Support
handled 212 of these requests in October, at about 10 minutes each, which is about 35 hours of
support time in one month. The cost is also commercial: Lumen Logistics churned in September
and named "no automated reports" in its exit survey.

## The goal is reports that arrive without anyone asking

An account admin sets up an export once, choosing the frequency and the recipients, and every
recipient receives each report on schedule with no request to support.

- **Who schedules:** account admins on the Business plan.
- **Frequency:** daily, weekly or monthly.
- **Recipients:** a list of email addresses.
- **Delivery:** an email with a download link to the CSV, as "Constraints for the build"
  describes.

## Out of scope

- PDF exports. The export is CSV only.
- Choosing which columns the CSV contains.
- Exports for the Starter plan.

## What changes for support

Once the feature ships, Business-plan customers who ask support for their usage report can set
up a scheduled export themselves, so support points them to it instead of sending the report.
Starter-plan customers cannot schedule exports, because the Starter plan is out of scope.

The ship date is not set yet. This spec gives it once engineering has estimated the detailed
design.

## Constraints for the build

Large accounts produce more than 2 million rows a month, and an email attachment of that size
fails, so each run stores the CSV and emails a signed download link instead. The link stays
valid for 7 days. The detailed design confirms both the link approach and the 7-day validity,
which the PM thread proposed but did not settle.

## Open questions

- Which reports in the reporting module can be exported, beyond the monthly usage report that
  customers ask for today.
- How support handles usage-report requests from Starter-plan customers after launch.
- The ship date, which support needs to plan the change.
