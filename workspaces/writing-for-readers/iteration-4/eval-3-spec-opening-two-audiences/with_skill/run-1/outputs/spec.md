---
description: Opening of the spec for scheduled CSV exports in the reporting module. States the problem, the goal and the scope before the detailed design, and tells each reader group what it needs from the feature.
audience: >-
  Two groups, each with its own section. Support leads, who handle the monthly usage-report
  requests and want to know what changes for their team and when; they do not know how the
  export is built. Backend engineers who will build the feature, who know the reporting module
  and want the data volume and delivery constraints.
---

# Scheduled CSV exports

Account admins on the Business plan will schedule a CSV export of their usage report to run
daily, weekly or monthly, and each run emails a list of addresses they choose. The proposed
delivery is a signed download link valid for 7 days, because exports from large accounts are
too big to attach to an email. PDF exports, custom column selection and exports for the
Starter plan are out of scope.

**Problem.** Business customers ask support to email them their monthly usage report. Support
handled 212 of these requests in October, at about 10 minutes each: about 35 hours of support
time in one month. Lumen Logistics churned in September and named "no automated reports" in
its exit survey.

**Goal.** A Business account admin sets up an export once, and the usage report reaches the
recipients on schedule without a request to support.

**Out of scope.**

- PDF exports.
- Choosing which columns an export contains.
- Exports for Starter-plan accounts.

## For support leads: requests for the monthly report move to self-service

Once the feature ships, a Business customer who asks for the monthly usage report can have
their account admin schedule it instead. Three kinds of request still reach support:

- Requests from Starter-plan customers, who cannot schedule exports.
- Requests for a PDF or for a different set of columns, which the feature does not offer.
- Recipients whose link has expired. The email carries a signed download link: a link to the
  file that stops working 7 days after the email is sent.

The release date is not set yet; it follows the engineering estimate of the detailed design.

## For backend engineers: 2M+ rows per month rule out email attachments

Large accounts produce more than 2 million usage rows per month, so a monthly export from one of
them cannot travel as an email attachment. Each run therefore stores the CSV and emails a
signed download link to it, valid for 7 days. The feature's inputs are:

- **Who schedules:** account admins on the Business plan.
- **Frequency:** daily, weekly or monthly.
- **Recipients:** a list of email addresses per schedule.

The brief gives no row volume for daily or weekly exports, no file size per row, and no limit
on the number of recipients; the detailed design sets them.

## Decisions needed before the detailed design

- Engineering confirms signed-link delivery and estimates a release date for support leads.
- Support leads decide how support answers a recipient whose link has expired.
