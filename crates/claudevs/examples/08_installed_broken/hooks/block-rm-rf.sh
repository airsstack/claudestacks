#!/bin/sh
# Blocks recursive deletes. Its message is read from one directory above the
# plugin root, which exists in this checkout and not in an installed copy.
payload=$(cat)
message=$(cat "$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt")
case "$payload" in
  *'rm -rf'*)
    echo "$message" >&2
    exit 2
    ;;
esac
exit 0
