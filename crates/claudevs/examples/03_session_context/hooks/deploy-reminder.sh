#!/bin/sh
# Adds a reminder when the prompt mentions a deploy; says nothing otherwise.
payload=$(cat)
case "$payload" in
  *deploy*)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"deploy-reminder: production deploys need a change ticket"}}'
    ;;
esac
exit 0
