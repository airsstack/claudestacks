#!/bin/sh
# Speaks only when the payload names a file that exists inside a project that
# has a manifest. A bare temp directory takes the silent branch — which is
# what a default payload and a default project have to prevent, or a case
# passes whether this hook works or not.
set -eu
payload=$(cat)
target=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$target" ] || exit 0
[ -f "$target" ] || exit 0
[ -f "$(dirname "$target")/Cargo.toml" ] || exit 0
echo "guard-saw-a-real-project"
