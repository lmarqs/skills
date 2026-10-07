#!/usr/bin/env bash
# Builds the disposable project the evals run against: a TypeScript service
# with a 12-bead linear epic, no git remote and no installed toolchain.
# Usage: make-eval-project.sh <empty-dir>
set -euo pipefail
dir="${1:?usage: make-eval-project.sh <empty-dir>}"
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
mkdir -p src && echo "export const version = '0.1.0';" > src/index.ts
git add -A && git commit -q -m "chore: init"
bd init --quiet >/dev/null 2>&1
epic=$(bd create --type=epic --title="Billing export" --description="Export invoices to CSV and S3 for finance." --silent)
prev=""
i=0
for title in "Add export_jobs table migration" "Add ExportJob repository" "CSV serializer for invoices" \
  "S3 upload client" "Export service orchestrator" "POST /exports endpoint" "GET /exports/:id status endpoint" \
  "Retry failed uploads" "Export audit log" "Admin export list UI" "Admin export detail UI" "Docs for finance export"; do
  i=$((i + 1))
  args=(--parent="$epic" --title="US-$(printf %03d "$i"): $title" --description="$title." \
    --acceptance="- [ ] $title works
- [ ] npm run typecheck passes
- [ ] npm run lint passes" --priority=2 --silent)
  [ -n "$prev" ] && args+=(--deps="$prev")
  prev=$(bd create "${args[@]}")
done
git add -A && git commit -q -m "chore: add beads" || true
echo "$epic"
