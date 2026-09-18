#!/bin/sh
# Blocks force pushes; every other Bash command passes silently.
payload=$(cat)
case "$payload" in
  *'git push'*'--force'*|*'git push'*' -f'*)
    echo "block-force-push: force pushes are not allowed" >&2
    exit 2
    ;;
esac
exit 0
