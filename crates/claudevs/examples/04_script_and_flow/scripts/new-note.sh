#!/bin/sh
# Creates notes/<slug>.md in the current git repository.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "new-note: not inside a git repository" >&2
  exit 1
}
title="$1"
slug=$(printf '%s' "$title" | tr ' ' '-')
mkdir -p notes
printf '# %s\n' "$title" > "notes/$slug.md"
echo "created notes/$slug.md"
