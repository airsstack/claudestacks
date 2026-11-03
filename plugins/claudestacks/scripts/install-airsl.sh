#!/bin/sh
# Installs the airsl runtime that every claudestacks plugin hook runs on.
#
# User-invoked, never automatic. It first runs airsl's own prebuilt-binary installer, which
# downloads a binary. If that cannot run or does not complete, it builds airsl from source with
# cargo, which takes minutes — a session-start hook that silently triggered either would be worse
# than the problem it solves. The SessionStart preflight names this script instead of running it.
#
# Pure POSIX sh with no airsl dependency, because the situation it exists for is "airsl is missing".
#
#   sh plugins/claudestacks/scripts/install-airsl.sh [--force]
#
# --force applies to the cargo route only; the prebuilt installer takes no such flag.

set -u

# Where the prebuilt installer is published, from https://github.com/airsstack/airsl, which is a
# separate repository from this one. It resolves to the latest release.
POINTER="https://airsstack.github.io/airsl/install.sh"

# The cargo route installs this crate from crates.io rather than --git, so no clone is needed and
# the release is the one its author actually published.
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
  for candidate in "$HOME/.local/bin/airsl" "${CARGO_HOME:-$HOME/.cargo}/bin/airsl" "$HOME/.cargo/bin/airsl"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Whether `directory` is on PATH. Hooks find airsl in ~/.local/bin and ~/.cargo/bin without it, but
# the skills that run `airsl` directly are spawned by a shell, and a shell that never sourced a
# profile cannot see either directory.
on_path() {
  case ":${PATH:-}:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Whether the user chose where airsl goes. Each of these names a binary or an install location, so
# a different airsl on PATH is then the user's own doing and not worth a warning.
location_chosen() {
  [ -n "${AIRSL_BIN:-}" ] ||
    [ -n "${AIRSL_CLI_INSTALL_DIR:-}" ] ||
    [ -n "${CARGO_DIST_FORCE_INSTALL_DIR:-}" ] ||
    [ -n "${AIRSL_CLI_UNMANAGED_INSTALL:-}" ]
}

# `found` is the binary the hooks will run; `installed` is where this run put airsl.
report() {
  found="$1"
  installed="$2"
  directory=$(dirname "$found")
  echo "airsl: $found"
  "$found" doctor 2>/dev/null || true
  if ! on_path "$directory"; then
    echo
    echo "WARNING: $directory is not on this shell's PATH. Plugin hooks still find airsl there, but skills that run airsl directly need it on PATH. Open a new shell, or add $directory to PATH."
  fi
  if [ "$found" != "$installed" ] && ! location_chosen; then
    echo
    echo "WARNING: this install went to $installed, but $found is what hooks will run. Remove $found, or put $installed first."
  fi
}

# Runs the prebuilt installer. Returns 0 only when it ran to completion. On failure it sets
# `reason` to "downloader" when neither curl nor wget exists, else to "prebuilt", which the
# fallback reports.
reason=""
tmp=""
install_prebuilt() {
  if command -v curl >/dev/null 2>&1; then
    downloader=curl
  elif command -v wget >/dev/null 2>&1; then
    downloader=wget
  else
    reason=downloader
    return 1
  fi
  reason=prebuilt

  # The pointer is held whole before anything runs, so a failed fetch runs nothing. A mktemp
  # failure counts as a failed fetch.
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' EXIT
  trap 'exit 1' HUP INT TERM

  # A failing curl goes to the fallback, not to wget, which is only for machines without curl.
  # -f keeps an HTTP error page from being saved and run.
  if [ "$downloader" = curl ]; then
    curl --proto '=https' --tlsv1.2 -sSfL "$POINTER" >"$tmp/install.sh" || return 1
  else
    wget -qO- "$POINTER" >"$tmp/install.sh" || return 1
  fi
  sh "$tmp/install.sh" || return 1
  return 0
}

# Deliberately no "already installed, skipping" short-circuit on either route. The prebuilt
# installer has none, and `cargo install` performs that check itself, and correctly: it reinstalls
# when the published version differs from the installed one and reports "already up to date"
# otherwise. Short-circuiting on the mere presence of a binary would strand every machine on
# whichever airsl it first installed — the runtime is still moving, so that is the common case
# rather than the rare one.
if install_prebuilt; then
  installed="$HOME/.local/bin/airsl"
else
  installed="${CARGO_HOME:-$HOME/.cargo}/bin/airsl"
  if ! command -v cargo >/dev/null 2>&1; then
    if [ "$reason" = downloader ]; then
      echo "airsl could not be installed: neither curl nor wget is available. Install one and re-run this script, or install Rust from https://rustup.rs and re-run it." >&2
    else
      echo "airsl could not be installed: the prebuilt install did not complete (see the error above). Re-run this script, or install Rust from https://rustup.rs and re-run it." >&2
    fi
    exit 1
  fi

  if [ "$reason" = downloader ]; then
    echo "neither curl nor wget is available; building airsl with cargo instead"
  else
    echo "the prebuilt install did not complete; building airsl with cargo instead"
  fi
  echo "Installing $CRATE from crates.io"
  echo "(builds ~79 crates from source, Lua itself among them; expect a few minutes)"
  echo

  # No --version: the latest published airsl-cli is what this suite wants, and cargo skips the
  # build when that is already what is installed.
  #
  # --locked builds it against the Cargo.lock that release shipped with. Without it cargo
  # re-resolves every dependency to the newest semver-compatible version available today, which
  # for `mlua`'s `vendored` feature means the C sources of the Lua interpreter itself can change
  # between two installs of the same airsl-cli. That is not a difference the plugin tests would
  # attribute correctly.
  if [ "$force" -eq 1 ]; then
    cargo install "$CRATE" --locked --force || exit 1
  else
    cargo install "$CRATE" --locked || exit 1
  fi
fi

echo
if found=$(find_airsl); then
  report "$found" "$installed"
  exit 0
fi

echo "the install reported success, but airsl is still not resolvable. Set AIRSL_BIN to the binary's full path." >&2
exit 1
