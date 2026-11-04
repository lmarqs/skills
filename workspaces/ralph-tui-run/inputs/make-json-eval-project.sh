#!/usr/bin/env bash
# Builds the JSON-source eval project: the same TypeScript service as
# make-eval-project.sh, with the 12 stories as a linear chain in a committed
# tasks/prd.json instead of beads. No beads, no git remote, no toolchain.
# Usage: make-json-eval-project.sh <empty-dir>
set -euo pipefail
dir="${1:?usage: make-json-eval-project.sh <empty-dir>}"
mkdir -p "$dir" && cd "$dir"
git init -q -b main
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "billing-export", "version": "0.1.0", "scripts": { "typecheck": "tsc --noEmit", "lint": "eslint .", "test": "vitest run" } }
JSON
cat > CLAUDE.md <<'MD'
# billing-export
- TypeScript service. Quality gates: `npm run typecheck`, `npm run lint`, `npm test`.
- Branches: `feat/<topic>`. Commits: Conventional Commits.
- Never commit directly to main.
MD
mkdir -p src tasks && echo "export const version = '0.1.0';" > src/index.ts
git add -A && git commit -q -m "chore: init"
python3 - tasks/prd.json <<'PY'
import json, sys
titles = ["Add export_jobs table migration", "Add ExportJob repository", "CSV serializer for invoices",
          "S3 upload client", "Export service orchestrator", "POST /exports endpoint", "GET /exports/:id status endpoint",
          "Retry failed uploads", "Export audit log", "Admin export list UI", "Admin export detail UI", "Docs for finance export"]
stories = []
for n, title in enumerate(titles, start=1):
    stories.append({"id": f"US-{n:03d}", "title": title, "description": f"{title}.",
                    "acceptanceCriteria": [f"{title} works", "npm run typecheck passes", "npm run lint passes"],
                    "priority": n, "passes": False, "notes": "",
                    "dependsOn": [f"US-{n - 1:03d}"] if n > 1 else []})
prd = {"name": "Billing export", "branchName": "ralph/billing-export",
       "description": "Export invoices to CSV and S3 for finance.", "userStories": stories}
json.dump(prd, open(sys.argv[1], "w"), indent=2)
PY
git add -A && git commit -q -m "chore: add prd.json"
echo "$dir/tasks/prd.json"
