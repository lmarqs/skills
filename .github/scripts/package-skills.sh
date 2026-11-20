#!/bin/sh
# Writes one <name>.zip per shipped skill into the output directory, for upload to claude.ai.
set -eu

out=$(mkdir -p "${1:-dist}" && cd "${1:-dist}" && pwd)
root=$(cd "$(dirname "$0")/../.." && pwd)
# quick_validate.py rejects scaffold's disable-model-invocation key (see AGENTS.md Gotchas).
excluded="scaffold"

for dir in "$root"/skills/*/; do
  name=$(basename "$dir")
  # skill-creator's eval scratch, kept out of git by .gitignore.
  case "$name" in *-workspace) continue ;; esac
  case " $excluded " in *" $name "*) echo "skip $name"; continue ;; esac
  # package_skill.py imports scripts.quick_validate, so it runs as a module from skill-creator.
  if ! log=$(cd "$root/.agents/skills/skill-creator" && python3 -m scripts.package_skill "$dir" "$out" 2>&1); then
    printf '%s\nfailed to package %s\n' "$log" "$name" >&2
    exit 1
  fi
  mv "$out/$name.skill" "$out/$name.zip"
  echo "packaged $name"
done
