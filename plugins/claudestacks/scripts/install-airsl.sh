#!/bin/sh
# Installs the airsl runtime that every claudestacks plugin hook runs on.
#
# User-invoked, never automatic. It compiles from source, which takes minutes — a session-start
# hook that silently triggered that would be worse than the problem it solves. The SessionStart
# preflight names this script instead of running it.
#
# Pure POSIX sh with no airsl dependency, because the situation it exists for is "airsl is missing".
#
#   sh plugins/claudestacks/scripts/install-airsl.sh [--force]

set -u

# Published from https://github.com/airsstack/airsl, which is a separate repository from this one.
# Installed from crates.io rather than --git so no clone is needed and the release is the one its
# author actually published.
CRATE="airsl-cli"

force=0
if [ "${1:-}" = "--force" ]; then
  force=1
fi

# The resolution order the hook wrappers use, kept identical on purpose: if this script and the
# wrappers disagreed about whether airsl is present, the warning and the remedy would contradict
# each other.
find_airsl() {
  if [ -n "${AIRSL_BIN:-}" ] && [ -x "${AIRSL_BIN:-}" ]; then
    echo "$AIRSL_BIN"
    return 0
  fi
  if command -v airsl >/dev/null 2>&1; then
    command -v airsl
    return 0
  fi
  for candidate in "${CARGO_HOME:-$HOME/.cargo}/bin/airsl" "$HOME/.cargo/bin/airsl"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Whether `directory` is on PATH. The failure this catches is the quiet one: airsl installed to
# ~/.cargo/bin, but hooks spawned by a shell that never sourced a profile cannot see it, so every
# hook no-ops and nothing says why.
on_path() {
  case ":${PATH:-}:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

report() {
  found="$1"
  directory=$(dirname "$found")
  echo "airsl: $found"
  "$found" doctor 2>/dev/null || true
  if ! on_path "$directory"; then
    echo
    echo "WARNING: $directory is not on this shell's PATH."
    echo "The binary exists but plugin hooks resolve it by PATH first, so they may still"
    echo "see nothing. Add it to PATH, or set AIRSL_BIN=$found in your environment."
  fi
}

# Deliberately no "already installed, skipping" short-circuit. `cargo install` performs that check
# itself, and correctly: it reinstalls when the published version differs from the installed one and
# reports "already up to date" otherwise. Short-circuiting on the mere presence of a binary would
# strand every machine on whichever airsl it first installed — the runtime is still moving, so that
# is the common case rather than the rare one.
if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. airsl is built from source, so a Rust toolchain is required." >&2
  echo "Install one from https://rustup.rs, then re-run this script." >&2
  exit 1
fi

echo "Installing $CRATE from crates.io"
echo "(builds ~79 crates from source, Lua itself among them; expect a few minutes)"
echo

# No --version: the latest published airsl-cli is what this suite wants, and cargo skips the build
# when that is already what is installed.
#
# --locked builds it against the Cargo.lock that release shipped with. Without it cargo re-resolves
# every dependency to the newest semver-compatible version available today, which for `mlua`'s
# `vendored` feature means the C sources of the Lua interpreter itself can change between two
# installs of the same airsl-cli. That is not a difference the plugin tests would attribute
# correctly.
if [ "$force" -eq 1 ]; then
  cargo install "$CRATE" --locked --force || exit 1
else
  cargo install "$CRATE" --locked || exit 1
fi

echo
if installed=$(find_airsl); then
  report "$installed"
  exit 0
fi

echo "cargo install reported success, but airsl is still not resolvable." >&2
echo "Check that cargo's bin directory exists and is readable." >&2
exit 1
