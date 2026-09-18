#!/bin/sh
# Refuses edits to .env files and asks before touching anything under secrets/.
# Every other path passes silently.
payload=$(cat)
case "$payload" in
  *'"file_path":"'*'.env"'*)
    echo "protect-env: refusing to edit a .env file" >&2
    exit 1
    ;;
  *'"file_path":"secrets/'*|*'/secrets/'*)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"protect-env: files under secrets/ need confirmation"}}'
    ;;
esac
exit 0
