# Spec: Scheduled CSV exports for the reporting module

**Status:** Draft
**Readers:** Support leads; backend engineers building the feature

## Summary

Account admins on the Business plan will be able to schedule a CSV export of their usage report to run daily, weekly or monthly. Each run emails a list of recipients a signed download link to the CSV, valid for 7 days. The file is not attached to the email.

- **Support leads:** once this ships, customers set up their own recurring reports, and support stops sending monthly usage reports by hand. The release date is not set yet; see [Open questions](#open-questions).
- **Backend engineers:** large accounts produce more than 2 million rows a month, so exports are generated as files and delivered by link, not as email attachments. See [Constraints](#constraints).

## Problem

Business-plan customers have no way to receive reports automatically, so they ask support to email them.

- Support handled 212 monthly-usage-report requests in October. At about 10 minutes each, that is roughly 35 hours of support time a month.
- Lumen Logistics churned in September and named "no automated reports" in its exit survey.

## Goals

- Account admins on the Business plan can create a scheduled CSV export with a daily, weekly or monthly frequency.
- Each scheduled export is emailed to a list of addresses the admin chooses.
- Exports of any account size, including accounts with 2M+ rows a month, are delivered.
- Manual report requests to support fall as customers move to scheduled exports.

## Non-goals

- PDF exports.
- Custom column selection; exports contain a fixed set of columns.
- Scheduled exports for the Starter plan.

## What changes for support

- Business-plan customers who ask for their usage report can be pointed to the scheduling setting, which an account admin configures once.
- Customers will ask new questions: expired links (after 7 days), recipients who did not get the email, and requests from Starter-plan customers, who do not have the feature.
- Timeline, rollout and any help-center or macro updates are not decided yet.

## Constraints

- **Volume:** large accounts exceed 2 million rows per month. A monthly export for such an account is too large for an email attachment.
- **Delivery:** the email carries a signed download link that expires after 7 days. The CSV is stored where the link can serve it for that period.
- **Access:** only account admins create and edit schedules. Recipients can be any email address on the list, and anyone holding the link can download the file until it expires.

## Open questions

1. **Release date and rollout:** when does this ship, and to all Business accounts at once or in stages? Support leads need this to plan.
2. **Recipients:** can recipients be outside the customer's organization, and is there a limit on list size?
3. **Link security:** is a signed link that anyone can open for 7 days acceptable for usage data, or must the downloader sign in?
4. **Failures:** who is notified when an export fails or exceeds a size limit, and does support see it?
5. **Report contents:** is the export exactly the existing monthly usage report, and what time range does a daily or weekly export cover?
