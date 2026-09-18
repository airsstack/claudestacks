# Runs the four `claudevs doctor` scenarios documented in ../README.md, echoing
# the exact command for each before running it and reporting its real exit
# status. Invoke as: sh simulate.sh <healthy|no-claude|no-marketplace|no-cases|all>
set -eu

usage() {
    cat <<'EOF'
usage: sh simulate.sh <scenario>

scenarios:
  healthy          doctor on this example plugin, unmodified
  no-claude        doctor with PATH stripped down to /usr/bin:/bin
  no-marketplace   doctor on a copy with no marketplace manifest above it
  no-cases         doctor on a copy under a synthetic marketplace with tests/ removed
  all              run all four scenarios in order
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
plugin_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_root=$(CDPATH= cd -- "$plugin_dir/../../../.." && pwd)

# Resolves the claudevs binary: $CLAUDEVS if set, else the workspace debug
# build, else whatever `command -v` finds on PATH. The no-claude scenario
# strips PATH before invoking the binary, so the resolved path must already
# contain a slash or that invocation would fail to find it a second time.
find_claudevs() {
    if [ -n "${CLAUDEVS:-}" ]; then
        printf '%s\n' "$CLAUDEVS"
        return 0
    fi
    if [ -x "$repo_root/target/debug/claudevs" ]; then
        printf '%s\n' "$repo_root/target/debug/claudevs"
        return 0
    fi
    command -v claudevs 2>/dev/null
}

candidate=$(find_claudevs || true)
case "$candidate" in
    */*)
        CLAUDEVS_BIN=$candidate
        ;;
    *)
        printf 'error: could not find the claudevs binary.\n' >&2
        printf '  set CLAUDEVS to its path, or run: cargo build -p claudevs-cli\n' >&2
        exit 1
        ;;
esac

# Removes the current scratch directory, guarding against an empty or unset
# WORKDIR ever reaching rm -rf.
cleanup_workdir() {
    if [ -n "${WORKDIR:-}" ]; then
        rm -rf -- "$WORKDIR"
    fi
    WORKDIR=""
}
WORKDIR=""
trap cleanup_workdir EXIT

scenario_healthy() {
    printf '$ %s doctor %s\n' "$CLAUDEVS_BIN" "$plugin_dir"
    status=0
    "$CLAUDEVS_BIN" doctor "$plugin_dir" || status=$?
    printf 'exit status: %s\n' "$status"
}

scenario_no_claude() {
    printf '$ env PATH=/usr/bin:/bin %s doctor %s\n' "$CLAUDEVS_BIN" "$plugin_dir"
    status=0
    env PATH=/usr/bin:/bin "$CLAUDEVS_BIN" doctor "$plugin_dir" || status=$?
    printf 'exit status: %s\n' "$status"
}

scenario_no_marketplace() {
    WORKDIR=$(mktemp -d)
    dest="$WORKDIR/doctor-gaps"
    cp -R "$plugin_dir" "$dest"
    printf '$ %s doctor %s\n' "$CLAUDEVS_BIN" "$dest"
    status=0
    "$CLAUDEVS_BIN" doctor "$dest" || status=$?
    printf 'exit status: %s\n' "$status"
    cleanup_workdir
}

scenario_no_cases() {
    WORKDIR=$(mktemp -d)
    mkdir -p "$WORKDIR/.claude-plugin"
    printf '{"name":"doctor-gaps-warn-fixtures"}' > "$WORKDIR/.claude-plugin/marketplace.json"
    dest="$WORKDIR/doctor-gaps"
    cp -R "$plugin_dir" "$dest"
    rm -rf -- "$dest/tests"
    printf '$ %s doctor %s\n' "$CLAUDEVS_BIN" "$dest"
    status=0
    "$CLAUDEVS_BIN" doctor "$dest" || status=$?
    printf 'exit status: %s\n' "$status"
    cleanup_workdir
}

scenario_all() {
    scenario_healthy
    printf '\n'
    scenario_no_claude
    printf '\n'
    scenario_no_marketplace
    printf '\n'
    scenario_no_cases
}

if [ "$#" -ne 1 ]; then
    usage >&2
    exit 2
fi

case "$1" in
    healthy)
        scenario_healthy
        exit "$status"
        ;;
    no-claude)
        scenario_no_claude
        exit "$status"
        ;;
    no-marketplace)
        scenario_no_marketplace
        exit "$status"
        ;;
    no-cases)
        scenario_no_cases
        exit "$status"
        ;;
    all)
        scenario_all
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
