#!/bin/sh
# claudestacks-sdlc body fingerprint: the first 12 hex characters of the
# SHA-256 of an artifact's body (every line after the line that closes the
# frontmatter, carriage returns stripped, each line ending in one newline).
#
#   sh fingerprint.sh <file>
#
# Prints the fingerprint and exits 0. Prints nothing and exits 2 when the
# file has no fingerprint: unreadable, first line not `---`, or frontmatter
# never closed. Shell mirror of `lib/fingerprint.lua`; the two MUST agree.

[ $# -eq 1 ] || exit 2
[ -r "$1" ] || exit 2

if command -v shasum >/dev/null 2>&1; then
  sum() { shasum -a 256; }
elif command -v sha256sum >/dev/null 2>&1; then
  sum() { sha256sum; }
else
  exit 2
fi

# Pass 1: does the file have closed frontmatter at all?
awk '
  { sub(/\r$/, "") }
  NR == 1 && $0 != "---" { exit }
  NR > 1 && $0 == "---" { closed = 1; exit }
  END { exit closed ? 0 : 2 }
' "$1" || exit 2

# Pass 2: hash the body.
awk '{ sub(/\r$/, "") } f { print } !f && NR > 1 && $0 == "---" { f = 1 }' "$1" \
  | sum | cut -c1-12
