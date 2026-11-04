#!/usr/bin/env bash
# Eval 1 project: the base project with epic bd-42, a local bare remote (no
# forge to query) and uncommitted changes in the working tree.
# Usage: make-dirty-tree-project.sh <empty-dir>
set -euo pipefail
dir="${1:?usage: make-dirty-tree-project.sh <empty-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
"$here/make-eval-project.sh" "$dir" bd-42 >/dev/null
git init -q --bare "$dir.remote.git"
cd "$dir"
git remote add origin "$dir.remote.git"
git push -q -u origin main
echo "export const exportEnabled = true; // WIP, not ready" >> src/index.ts
echo "scratch notes for the S3 bucket naming" > notes.txt
echo bd-42
