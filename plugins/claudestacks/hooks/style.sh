#!/bin/sh
# claudestacks reply-rules launcher.
#
# Prints the communication protocol's reply rules as context. Always exits 0: a hook on
# SessionStart or UserPromptSubmit must never block the session or the prompt. Deliberately
# no `exec`, which would hand airsl's status straight back to Claude Code.

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
[ -n "$DIR" ] || exit 0
PLUGIN=$(CDPATH= cd -- "$DIR/.." 2>/dev/null && pwd) || exit 0

# Resolve airsl without relying on PATH. Hooks are spawned by the CLI rather than a login shell,
# so a cargo-installed binary under ~/.cargo/bin can be present but invisible.
AIRSL=""
if [ -n "${AIRSL_BIN:-}" ] && [ -x "${AIRSL_BIN:-}" ]; then
  AIRSL="$AIRSL_BIN"
elif command -v airsl >/dev/null 2>&1; then
  AIRSL=airsl
else
  for candidate in "${CARGO_HOME:-$HOME/.cargo}/bin/airsl" "$HOME/.cargo/bin/airsl"; do
    if [ -x "$candidate" ]; then
      AIRSL="$candidate"
      break
    fi
  done
fi
[ -n "$AIRSL" ] || exit 0

"$AIRSL" run --fail-open --policy confined \
  --allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT \
  --allow-read "$PLUGIN" \
  "$PLUGIN/scripts/style.lua" "$PLUGIN/skills/discuss/references/protocol.md" "$@" || exit 0

exit 0
