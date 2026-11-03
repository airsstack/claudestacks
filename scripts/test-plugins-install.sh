#!/bin/sh
# Offline test lane for how the plugin hooks find the airsl runtime.
#
#   sh scripts/test-plugins-install.sh        (or: cargo make plugins-install)
#
# Every case runs under its own temporary HOME with CARGO_HOME and AIRSL_BIN unset and a PATH
# that holds only the system directories, so the machine's real airsl installs cannot answer for
# the code under test. The install-airsl.sh cases go further: their PATH holds stub downloaders
# and a stub cargo plus links to the few system tools the script needs, so a real curl or cargo
# cannot answer either. Nothing here touches the network. The script exits non-zero if any case
# fails and names each one that did.
#
# This lives outside plugins/ on purpose: it is a repository check, not part of what a plugin
# user installs.

set -u

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 1

unset CARGO_HOME AIRSL_BIN

SAFE_PATH=/usr/bin:/bin

# The lookup line every hook wrapper and script carries, kept character for character apart from
# its two-space indent, which the check adds. It is matched as literal text, so the single quotes
# are deliberate.
# shellcheck disable=SC2016
NEW_LINE='for candidate in "$HOME/.local/bin/airsl" "${CARGO_HOME:-$HOME/.cargo}/bin/airsl" "$HOME/.cargo/bin/airsl"; do'

# The ten files that carry it, relative to the repository root.
LOOKUP_FILES='plugins/claudestacks-journal/scripts/session-start.sh
plugins/claudestacks-sdlc/scripts/attention.sh
plugins/claudestacks-sdlc/scripts/status.sh
plugins/claudestacks/hooks/comm-check.sh
plugins/claudestacks/hooks/enforce.sh
plugins/claudestacks/hooks/handoff-check.sh
plugins/claudestacks/hooks/preflight.sh
plugins/claudestacks/hooks/rearm.sh
plugins/claudestacks/hooks/style.sh
plugins/claudestacks/scripts/install-airsl.sh'

PREFLIGHT="$ROOT/plugins/claudestacks/hooks/preflight.sh"
INSTALL="$ROOT/plugins/claudestacks/scripts/install-airsl.sh"

# The system tools install-airsl.sh calls besides the stubs. Each case links just these, so a
# case that leaves out a stub really has no such program on PATH.
TOOLS="sh mktemp dirname rm mkdir chmod cat"

# The messages install-airsl.sh prints, character for character.
MSG_NO_DOWNLOADER='airsl could not be installed: neither curl nor wget is available. Install one and re-run this script, or install Rust from https://rustup.rs and re-run it.'
MSG_PREBUILT_FAILED='airsl could not be installed: the prebuilt install did not complete (see the error above). Re-run this script, or install Rust from https://rustup.rs and re-run it.'
FALLBACK_PREBUILT_FAILED='the prebuilt install did not complete; building airsl with cargo instead'
FALLBACK_NO_DOWNLOADER='neither curl nor wget is available; building airsl with cargo instead'
MSG_NOT_RESOLVABLE="the install reported success, but airsl is still not resolvable. Set AIRSL_BIN to the binary's full path."
POINTER_URL='https://airsstack.github.io/airsl/install.sh'

# Creates an executable airsl stub at the given path.
make_stub() {
  mkdir -p "$(dirname -- "$1")"
  printf '#!/bin/sh\nexit 0\n' >"$1"
  chmod +x "$1"
}

# Runs the given preflight script with HOME set to the first argument and the restricted PATH;
# its output and exit status land in $out and $rc.
run_preflight() {
  out=$(HOME="$1" PATH="$SAFE_PATH" sh "$2" 2>&1)
  rc=$?
}

lookup_line_is_identical() {
  cd "$ROOT" || return 1

  # -x makes it a whole-line match, so a commented-out, re-indented or trailing-comment copy of the
  # line does not count; every file nests the loop two spaces deep.
  carrying=$(grep -rlxF -- "  $NEW_LINE" plugins | sort)
  expected=$(printf '%s\n' "$LOOKUP_FILES" | sort)
  if [ "$carrying" != "$expected" ]; then
    echo "files carrying the new lookup line differ from the ten expected."
    echo "carrying:"
    echo "$carrying"
    echo "expected:"
    echo "$expected"
    return 1
  fi

  # No file may keep a candidate loop of any other shape, the old two-entry form included.
  stale=$(grep -rn 'for candidate in .*bin/airsl' plugins | grep -vF -- "$NEW_LINE")
  if [ -n "$stale" ]; then
    echo "a lookup line other than the new one remains:"
    echo "$stale"
    return 1
  fi
  return 0
}

preflight_finds_local_bin_off_path() {
  make_stub "$h/.local/bin/airsl"
  run_preflight "$h" "$PREFLIGHT"
  case "$out" in
    *STATUS:*)
      echo "preflight warned although airsl is in \$HOME/.local/bin:"
      echo "$out"
      return 1
      ;;
  esac
  return 0
}

preflight_prefers_local_bin_over_cargo() {
  make_stub "$h/.local/bin/airsl"
  make_stub "$h/.cargo/bin/airsl"
  # preflight.sh neither runs nor prints what it resolved, so a copy gets one line that prints it.
  probe="$h/preflight-probe.sh"
  awk '/^if \[ -z "\$AIRSL" \]/ { print "echo \"AIRSL=$AIRSL\"" } { print }' "$PREFLIGHT" >"$probe"
  run_preflight "$h" "$probe"
  case "$out" in
    *"AIRSL=$h/.local/bin/airsl"*) return 0 ;;
  esac
  echo "expected AIRSL=$h/.local/bin/airsl, got:"
  echo "$out"
  return 1
}

preflight_warns_with_neither() {
  run_preflight "$h" "$PREFLIGHT"
  if [ "$rc" != 0 ]; then
    echo "preflight exited $rc, expected 0"
    return 1
  fi
  case "$out" in
    *"STATUS: the airsl runtime was not found"*) return 0 ;;
  esac
  echo "no STATUS line printed:"
  echo "$out"
  return 1
}

# Writes an executable file at the first argument, one line per remaining argument.
write_exec() {
  mkdir -p "$(dirname -- "$1")"
  _target=$1
  shift
  printf '%s\n' "$@" >"$_target"
  chmod +x "$_target"
}

# Builds the PATH for an install-airsl.sh case: a directory of stubs first, then a directory of
# links to $TOOLS. Also writes the airsl binary the stubs install, and a served installer that
# does nothing. $stubs, $tools and $script_path stay set for the rest of the case.
setup_install_env() {
  stubs="$h/stubs"
  tools="$h/tools"
  mkdir -p "$stubs" "$tools"
  for _tool in $TOOLS; do
    ln -s "$(PATH="$SAFE_PATH" command -v "$_tool")" "$tools/$_tool"
  done
  script_path="$stubs:$tools"
  make_stub "$h/airsl-template"
  serve_nothing
}

# What the stub downloaders hand to `sh`: an installer that puts airsl in ~/.local/bin, one that
# fails, and one that succeeds without installing anything.
# The single quotes are deliberate: $HOME must expand when the served script runs, not here.
# shellcheck disable=SC2016
serve_installing() {
  write_exec "$h/served.sh" '#!/bin/sh' \
    'mkdir -p "$HOME/.local/bin"' \
    'cat "'"$h"'/airsl-template" >"$HOME/.local/bin/airsl"' \
    'chmod +x "$HOME/.local/bin/airsl"'
}

serve_failing() {
  write_exec "$h/served.sh" '#!/bin/sh' 'exit 1'
}

serve_nothing() {
  write_exec "$h/served.sh" '#!/bin/sh' 'exit 0'
}

# A stub downloader named $1 that records its arguments in $h/$1.calls and then either serves
# $h/served.sh (second argument "serve") or fails like an HTTP error (anything else).
stub_downloader() {
  if [ "$2" = serve ]; then
    _outcome='cat "'"$h"'/served.sh"'
  else
    _outcome='exit 22'
  fi
  write_exec "$stubs/$1" '#!/bin/sh' \
    'printf "%s\n" "$*" >>"'"$h"'/'"$1"'.calls"' \
    "$_outcome"
}

# A stub cargo that records its arguments in $h/cargo.calls, exits with the status given as the
# first argument, and installs airsl into the cargo bin directory when it succeeds or when the
# second argument is "installs". The second form is a cargo that fails after leaving a binary
# behind, so a script that ignored the failure would still find airsl and exit 0.
# The single quotes are deliberate: $HOME must expand when the stub runs, not here.
# shellcheck disable=SC2016
stub_cargo() {
  write_exec "$stubs/cargo" '#!/bin/sh' \
    'printf "%s\n" "$*" >>"'"$h"'/cargo.calls"' \
    'if [ '"$1"' -eq 0 ] || [ "'"${2:-}"'" = installs ]; then' \
    '  mkdir -p "$HOME/.cargo/bin"' \
    '  cat "'"$h"'/airsl-template" >"$HOME/.cargo/bin/airsl"' \
    '  chmod +x "$HOME/.cargo/bin/airsl"' \
    'fi' \
    'exit '"$1"
}

# Runs install-airsl.sh with the arguments given, under HOME=$h and the stub PATH; its output
# and exit status land in $out and $rc.
run_install() {
  out=$(HOME="$h" PATH="$script_path" sh "$INSTALL" "$@" 2>&1)
  rc=$?
}

expect_rc() {
  if [ "$rc" != "$1" ]; then
    echo "exit status $rc, expected $1; output:"
    echo "$out"
    return 1
  fi
}

expect_out_has() {
  case "$out" in
    *"$1"*) return 0 ;;
  esac
  echo "output lacks: $1"
  echo "output:"
  echo "$out"
  return 1
}

expect_out_lacks() {
  case "$out" in
    *"$1"*)
      echo "output holds: $1"
      echo "output:"
      echo "$out"
      return 1
      ;;
  esac
  return 0
}

# A stub records its calls in $h/<name>.calls. A stub that was meant to run must have left the
# file; one that was not must not have.
expect_called() {
  if [ ! -f "$h/$1.calls" ]; then
    echo "$1 was never called"
    return 1
  fi
}

expect_not_called() {
  if [ -f "$h/$1.calls" ]; then
    echo "$1 was called with:"
    cat "$h/$1.calls"
    return 1
  fi
}

expect_calls_equal() {
  expect_called "$1" || return 1
  _recorded=$(cat "$h/$1.calls")
  if [ "$_recorded" != "$2" ]; then
    echo "$1 received: $_recorded"
    echo "expected:    $2"
    return 1
  fi
}

off_path_text() {
  printf '%s' "WARNING: $1 is not on this shell's PATH. Plugin hooks still find airsl there, but skills that run airsl directly need it on PATH. Open a new shell, or add $1 to PATH."
}

shadowed_text() {
  printf '%s' "WARNING: this install went to $1, but $2 is what hooks will run. Remove $2, or put $1 first."
}

prebuilt_route_installs() {
  setup_install_env
  stub_downloader curl serve
  stub_cargo 0
  serve_installing
  run_install
  expect_rc 0 || return 1
  expect_calls_equal curl "--proto =https --tlsv1.2 -sSfL $POINTER_URL" || return 1
  expect_not_called cargo || return 1
  expect_out_has "airsl: $h/.local/bin/airsl" || return 1
  # The binary it found is the one it installed, so nothing is shadowed.
  expect_out_lacks "is what hooks will run" || return 1
}

wget_is_used_without_curl() {
  setup_install_env
  stub_downloader wget serve
  stub_cargo 0
  serve_installing
  run_install
  expect_rc 0 || return 1
  expect_calls_equal wget "-qO- $POINTER_URL" || return 1
  expect_not_called cargo || return 1
  expect_out_has "airsl: $h/.local/bin/airsl" || return 1
}

fetch_failure_falls_back_to_cargo() {
  setup_install_env
  stub_downloader curl fail
  stub_cargo 0
  run_install
  expect_rc 0 || return 1
  expect_called curl || return 1
  expect_calls_equal cargo "install airsl-cli --locked" || return 1
  expect_out_has "$FALLBACK_PREBUILT_FAILED" || return 1
  expect_out_has "builds ~79 crates" || return 1
  expect_out_has "airsl: $h/.cargo/bin/airsl" || return 1
}

installer_failure_falls_back_to_cargo() {
  setup_install_env
  stub_downloader curl serve
  stub_cargo 0
  serve_failing
  run_install
  expect_rc 0 || return 1
  expect_called curl || return 1
  expect_calls_equal cargo "install airsl-cli --locked" || return 1
  expect_out_has "$FALLBACK_PREBUILT_FAILED" || return 1
}

no_downloader_falls_back_to_cargo() {
  setup_install_env
  stub_cargo 0
  run_install
  expect_rc 0 || return 1
  expect_calls_equal cargo "install airsl-cli --locked" || return 1
  expect_out_has "$FALLBACK_NO_DOWNLOADER" || return 1
}

no_downloader_no_cargo_exits_1() {
  setup_install_env
  run_install
  expect_rc 1 || return 1
  expect_out_has "$MSG_NO_DOWNLOADER" || return 1
}

failed_install_no_cargo_exits_1() {
  setup_install_env
  stub_downloader curl fail
  run_install
  expect_rc 1 || return 1
  expect_called curl || return 1
  expect_out_has "$MSG_PREBUILT_FAILED" || return 1
  expect_out_lacks "Install one" || return 1
}

unresolved_after_install_exits_1() {
  setup_install_env
  stub_downloader curl serve
  serve_nothing
  run_install
  expect_rc 1 || return 1
  expect_called curl || return 1
  expect_out_has "$MSG_NOT_RESOLVABLE" || return 1
}

off_path_warning_names_skills() {
  setup_install_env
  stub_downloader curl serve
  serve_installing
  run_install
  expect_rc 0 || return 1
  expect_out_has "$(off_path_text "$h/.local/bin")" || return 1
  expect_out_lacks "may still see nothing" || return 1
}

shadowed_binary_warns() {
  setup_install_env
  stub_downloader curl serve
  serve_installing
  # An older airsl earlier on PATH than the one just installed.
  make_stub "$h/older/airsl"
  script_path="$h/older:$script_path"
  run_install
  expect_rc 0 || return 1
  expect_out_has "$(shadowed_text "$h/.local/bin/airsl" "$h/older/airsl")" || return 1
}

preflight_fallback_names_the_pointer() {
  if ! grep -qxF "    echo '  curl -LsSf $POINTER_URL | sh'" "$PREFLIGHT"; then
    echo "preflight.sh does not print the curl line for $POINTER_URL"
    return 1
  fi
  if grep -qF 'cargo install airsl-cli' "$PREFLIGHT"; then
    echo "preflight.sh still prints a cargo install airsl-cli line:"
    grep -nF 'cargo install airsl-cli' "$PREFLIGHT"
    return 1
  fi
}

failed_curl_does_not_try_wget() {
  setup_install_env
  stub_downloader curl fail
  stub_downloader wget serve
  stub_cargo 0
  serve_installing
  run_install
  expect_rc 0 || return 1
  expect_called curl || return 1
  expect_not_called wget || return 1
  expect_called cargo || return 1
}

force_reaches_cargo() {
  setup_install_env
  stub_downloader curl fail
  stub_cargo 0
  run_install --force
  expect_rc 0 || return 1
  expect_calls_equal cargo "install airsl-cli --locked --force" || return 1
}

cargo_failure_exits_1() {
  setup_install_env
  stub_downloader curl fail
  stub_cargo 1 installs
  run_install
  expect_called cargo || return 1
  expect_rc 1 || return 1
}

# A variable that says where airsl goes means the user chose the location, so a different airsl
# earlier on PATH is not the script's to warn about. Each of the four is tried on its own, with
# an airsl on PATH that differs from the one just installed.
chosen_location_skips_shadow_warning() {
  setup_install_env
  stub_downloader curl serve
  serve_installing
  make_stub "$h/older/airsl"
  script_path="$h/older:$script_path"
  for _variable in AIRSL_BIN AIRSL_CLI_INSTALL_DIR CARGO_DIST_FORCE_INSTALL_DIR AIRSL_CLI_UNMANAGED_INSTALL; do
    (
      export "$_variable=$h/older/airsl"
      run_install
      expect_rc 0 || exit 1
      expect_out_has "airsl: $h/older/airsl" || exit 1
      expect_out_lacks "is what hooks will run" || exit 1
    ) || {
      echo "(with $_variable set)"
      return 1
    }
  done
}

failed=0

run_case() {
  h=$(mktemp -d "${TMPDIR:-/tmp}/plugins-install.XXXXXX") || {
    echo "FAIL $1: mktemp failed"
    failed=1
    return
  }
  # A subshell keeps one case's cd and variables from leaking into the next.
  if result=$("$1" 2>&1); then
    echo "ok   $1"
  else
    echo "FAIL $1"
    echo "$result" | sed 's/^/     /'
    failed=1
  fi
  rm -rf "$h"
}

# A real airsl on the restricted PATH would answer for the code under test and hide every failure.
if (PATH="$SAFE_PATH"; command -v airsl >/dev/null 2>&1); then
  echo "airsl is present on $SAFE_PATH; these cases need it absent" >&2
  exit 1
fi

run_case lookup_line_is_identical
run_case preflight_finds_local_bin_off_path
run_case preflight_prefers_local_bin_over_cargo
run_case preflight_warns_with_neither
run_case prebuilt_route_installs
run_case wget_is_used_without_curl
run_case fetch_failure_falls_back_to_cargo
run_case installer_failure_falls_back_to_cargo
run_case no_downloader_falls_back_to_cargo
run_case no_downloader_no_cargo_exits_1
run_case failed_install_no_cargo_exits_1
run_case unresolved_after_install_exits_1
run_case off_path_warning_names_skills
run_case shadowed_binary_warns
run_case preflight_fallback_names_the_pointer
run_case failed_curl_does_not_try_wget
run_case force_reaches_cargo
run_case cargo_failure_exits_1
run_case chosen_location_skips_shadow_warning

if [ "$failed" != 0 ]; then
  echo "plugins-install: FAILED" >&2
  exit 1
fi
echo "plugins-install: all cases passed"
