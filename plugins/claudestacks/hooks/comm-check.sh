#!/bin/sh
# claudestacks communication-protocol report conformance launcher.
#
# Same exit rules as `handoff-check.sh`: exit 2 only when the Lua wrote violations to stdout
# on a gate event; any other failure (airsl missing, script error, unreadable file) exits 0,
# because a broken checker must never hold a correct report.

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
[ -n "$DIR" ] || exit 0

# Resolve airsl without relying on PATH. Hooks are spawned by the CLI rather than a login
# shell, so a cargo-installed binary under ~/.cargo/bin can be present but invisible.
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

# `--allow-read /` because the report path is handed in by the call being inspected and may be
# anywhere, including TMPDIR.
VIOLATIONS=$("$AIRSL" run --fail-open --policy confined \
  --allow-env HOME --allow-env TMPDIR \
  --allow-read / \
  "$DIR/../scripts/comm_check_hook.lua" 2>/dev/null) || exit 0

[ -n "$VIOLATIONS" ] || exit 0

# PostToolUse emits a JSON object on stdout and blocks nothing; pass it through untouched.
case "$VIOLATIONS" in
  '{'*) printf '%s\n' "$VIOLATIONS"; exit 0 ;;
esac

printf '%s\n' "$VIOLATIONS" >&2
exit 2
