#!/usr/bin/env bash
# Builds a project with two task sources and no ralph-tui config to choose
# between them: the base project's beads epic plus a committed tasks/prd.json
# for an unrelated feature.
# Usage: make-both-sources-project.sh <empty-dir>
# Prints: <epic-id> <prd-path>
set -euo pipefail
dir="${1:?usage: make-both-sources-project.sh <empty-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
epic=$("$here/make-eval-project.sh" "$dir")
cd "$dir"
mkdir -p tasks
cat > tasks/prd.json <<'JSON'
{
  "name": "Invoice PDF rendering",
  "branchName": "ralph/invoice-pdf",
  "description": "Render invoices as PDF for customer download.",
  "userStories": [
    { "id": "US-001", "title": "PDF template for invoices", "acceptanceCriteria": ["Template renders all invoice fields", "npm run typecheck passes"], "priority": 1, "passes": false, "notes": "", "dependsOn": [] },
    { "id": "US-002", "title": "GET /invoices/:id/pdf endpoint", "acceptanceCriteria": ["Returns application/pdf for an existing invoice", "npm run typecheck passes"], "priority": 2, "passes": false, "notes": "", "dependsOn": ["US-001"] },
    { "id": "US-003", "title": "Download button on invoice page", "acceptanceCriteria": ["Button downloads the PDF", "npm run typecheck passes"], "priority": 3, "passes": false, "notes": "", "dependsOn": ["US-002"] }
  ]
}
JSON
git add -A && git commit -q -m "chore: add prd.json"
echo "$epic $dir/tasks/prd.json"
