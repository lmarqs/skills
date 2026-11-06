# Spec: Scheduled CSV exports for the reporting module

**Status:** Draft
**Readers:** Support leads (what changes for support, and when); backend engineers (data volume and delivery constraints)

## Summary

Account admins on the Business plan can schedule a CSV export of their usage report to run daily, weekly or monthly.
Each run emails a list of addresses a signed download link that stays valid for 7 days. The file itself is not
attached, because large accounts produce more than 2M rows a month.

## Problem

Business-plan customers get their monthly usage report by asking support to email it to them.

- Support handled 212 of these requests in October. At about 10 minutes each, that is roughly 35 hours of support
  time in one month.
- Lumen Logistics churned in September and named "no automated reports" in its exit survey.

Customers wait on a manual step for data they want on a schedule, and support spends time on a task the product
could do.

## Goals

- Business-plan account admins can create, change and remove a schedule (daily, weekly or monthly) that sends a CSV
  export of the usage report to a list of email addresses.
- Every export reaches recipients reliably whatever the account's size, including accounts with 2M+ rows a month.
- Requests to support for emailed usage reports fall once customers can schedule their own.

## Non-goals

- PDF exports.
- Custom column selection: every export uses the report's standard columns.
- Exports for the Starter plan.

## What changes for support

- Customers who ask for a usage report by email can be pointed to the scheduling setting, which an account admin
  sets up once.
- Recipients get a download link, not an attachment. Links expire after 7 days, so expect questions about expired
  links; the fix is to download the file from a later run or ask an admin to adjust the schedule.
- Starter-plan customers do not get this feature. Requests from them continue as today.
- Release date: not set yet. It belongs here once engineering has an estimate, so support leads can plan the switch.

## Constraints for engineering

- **Volume:** large accounts exceed 2M rows a month. A monthly export for these accounts must be generated without
  blocking other reporting work and without loading the full result into memory at once.
- **Delivery:** emails carry a signed link, never the file. Links expire 7 days after the email is sent.
- **Frequency:** daily, weekly and monthly schedules, each sending to a list of addresses.
- **Access:** only account admins on the Business plan can create or edit schedules.

## Open questions

- When does this ship, and is there a staged rollout support should know about?
- Who may be on the recipient list: any email address, or only users of the account?
- What happens when a run fails, and who is told?
- Can a recipient get a fresh link after the 7 days, or only through the next scheduled run?
