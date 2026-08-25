#!/bin/sh
# claudestacks-sdlc status launcher. Resolves airsl without relying on PATH
# (hooks and commands are spawned by the CLI, not a login shell, so a
# cargo-installed binary under ~/.cargo/bin can be present but invisible).
# Every path exits 0: when airsl is missing the command's model fallback
# derives the board instead, and deliberately no `exec` — that would hand
# airsl's status back to Claude Code.

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
[ -n "$DIR" ] || exit 0
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
  --allow-read . \
  "$DIR/status.lua" || exit 0

exit 0
