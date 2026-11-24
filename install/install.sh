#!/bin/sh
# Installs the claudevs command-line tool.
#
#   curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh
#   curl -LsSf https://airsstack.github.io/claudestacks/install.sh | CLAUDEVS_VERSION=0.1.0 sh
#   curl -LsSf https://airsstack.github.io/claudestacks/install.sh | CLAUDEVS_CLI_NO_MODIFY_PATH=1 sh
#
# claudevs moved to https://github.com/airsstack/agentstacks, and this script is
# now a forwarder. With no version, or `latest`, it runs agentstacks' claudevs
# installer. With an explicit version it installs that claudestacks release
# (0.1.0 and 0.1.1 exist here), and forwards to agentstacks if there is none.
# Every variable the installers read (CLAUDEVS_VERSION, CLAUDEVS_CLI_INSTALL_DIR,
# CLAUDEVS_CLI_NO_MODIFY_PATH, ...) passes through untouched.
#
# Published to GitHub Pages from install/ by .github/workflows/pages.yml: a
# change merged here is live for everyone who runs the command above.

set -eu

repo="https://github.com/airsstack/claudestacks"
installer="claudevs-cli-installer.sh"
moved_repo="https://github.com/airsstack/agentstacks"
moved_installer="https://airsstack.github.io/agentstacks/claudevs.sh"

say() {
    printf 'claudevs-install: %s\n' "$1" >&2
}

fail() {
    say "error: $1"
    exit 1
}

# curl first, wget otherwise: the same order dist's installer uses, so a machine
# that can run one can run the other. Both write to stdout and the shell writes
# the file, which also keeps a snap-confined curl out of the temp directory.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -sSfL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        fail "neither curl nor wget is installed"
    fi
}

# Runs agentstacks' claudevs installer with the arguments given here.
forward() {
    say "claudevs moved to $moved_repo; running $moved_installer"
    if ! download "$moved_installer" >"$tmp/claudevs.sh"; then
        fail "could not download $moved_installer"
    fi
    sh "$tmp/claudevs.sh" "$@"
}

main() {
    version="${CLAUDEVS_VERSION:-latest}"
    version="${version#v}"

    case "$version" in
        latest)
            ;;
        *[!0-9A-Za-z.+-]* | "")
            fail "CLAUDEVS_VERSION='${CLAUDEVS_VERSION:-}' is not a version (expected something like 0.1.0)"
            ;;
    esac

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    if [ "$version" = latest ]; then
        forward "$@"
        return
    fi

    url="$repo/releases/download/claudevs-cli-v$version/$installer"
    say "fetching the installer for claudevs $version"
    if download "$url" >"$tmp/$installer"; then
        sh "$tmp/$installer" "$@"
    else
        forward "$@"
    fi
}

# Nothing runs until the last line arrives, so a download cut off halfway
# through `curl | sh` defines a function and exits instead of running half a script.
main "$@"
