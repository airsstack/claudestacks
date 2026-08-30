#!/bin/sh
# Clones the pinned third-party plugin corpus into a destination directory.
#
#   ./scripts/corpus-fetch.sh [manifest] [destination]
#
# Both arguments default to the values `cargo make corpus-fetch` uses, so the
# lane invokes this with none and a test can point it at scratch paths.
#
# The only step in this repository that touches the network. It is never a
# dependency of `cargo make dod`, never runs in CI, and is run before a release
# rather than on every commit — the corpus is pinned by commit SHA rather than
# vendored, which keeps repository weight at zero (vendoring measured 19 MB for
# all 156 roots) and keeps the published .crate clear of the crates.io size
# ceiling. The cost of that choice is exactly this: a check nobody is obliged to
# run guards by convention.
#
# A pinned SHA is re-fetchable while the commit stays reachable. A repository
# that is deleted, made private, or force-pushed makes its row a record of what
# was tested rather than something re-runnable. That is expected; report such a
# row as unfetchable rather than repinning it silently.
#
# This body lives in a file rather than inline in `Makefile.toml` so that the
# malformed-record guard below can be pinned by a test. The lane that runs it is
# in neither the gate nor CI, so a guard reachable only through that lane is a
# guard whose removal nothing would notice.

set -eu
manifest="${1:-crates/claudevs/tests/corpus/corpus.toml}"
dest="${2:-target/corpus}"
log="$dest/.fetch-log"
unfetchable="$dest/.unfetchable"
malformed="$dest/.malformed"

# Stale markers from a previous, possibly-interrupted run must not vouch for
# this one. `dest` itself is created lazily below, only once there is something
# to write into it, so a run that clones nothing leaves no directory behind for
# `corpus_root()` (crates/claudevs/tests/corpus.rs) to find.
rm -f "$log" "$unfetchable" "$malformed"

# There is no TOML parser in the shell, and the manifest does not need one:
# every [[repo]] block carries name, url and sha on their own lines, in that
# order, because the generator that wrote the file emits exactly that shape.
# awk reduces it to `name<TAB>url<TAB>sha` and the loop below does the rest.
awk -F'"' '
  /^name = "/ { name = $2 }
  /^url = "/  { url  = $2 }
  /^sha = "/  { print name "\t" url "\t" $2 }
' "$manifest" | while IFS="$(printf '\t')" read -r name url sha; do
  mkdir -p "$dest"
  slug=$(printf '%s' "$name" | tr '/' '_')

  # An awk pass is not a TOML parser, and the manifest is hand-editable. A
  # [[repo]] table whose keys are reordered, or one carrying a blank value,
  # yields a record whose fields are shifted or empty — and an empty `slug`
  # makes `repo` the destination root itself, so the `rm -rf` below would take
  # every clone rather than one. A first table whose blank `sha` line sits
  # ahead of `name` and `url` reduces to a record of three empty fields, and
  # without this check that gave `slug=`, `repo="$dest/"`, a removal of the
  # whole destination, and a lane that still exited 0.
  #
  # `slug` cannot hold a path separator — `tr` above turned every `/` into `_`
  # — so the only traversal spellings left to reject are the two relative
  # directory names.
  #
  # This loop is the right-hand side of a pipeline and so runs in a subshell,
  # where `exit` ends only the subshell. Two things make the rejection reach
  # the caller: `set -e` fails the script on the pipeline's non-zero status,
  # and the marker file below is checked after the loop — the same on-disk
  # technique the log uses to carry a count out of the same subshell.
  if [ -z "$name" ] || [ -z "$url" ] || [ -z "$sha" ] || [ -z "$slug" ] \
     || [ "$slug" = "." ] || [ "$slug" = ".." ]; then
    printf 'corpus-fetch: malformed manifest record (name=%s url=%s sha=%s slug=%s) in %s — every [[repo]] table must carry a non-empty name, url and sha, in that order\n' \
      "$name" "$url" "$sha" "$slug" "$manifest" >&2
    : > "$malformed"
    exit 1
  fi

  repo="$dest/$slug"

  if [ -d "$repo/.git" ] && [ "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" = "$sha" ]; then
    printf 'ok    %s @ %s\n' "$name" "$sha"
    printf '%s\n' "$name" >> "$log"
    continue
  fi

  rm -rf "$repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" remote add origin "$url"
  # A pinned SHA is fetchable directly while the commit stays reachable. A
  # repository that was deleted, made private, or force-pushed fails here, and
  # that is the honest outcome: its row records what was tested rather than
  # something re-runnable. Report it; do not repin it.
  if git -C "$repo" fetch -q --depth 1 origin "$sha" 2>/dev/null; then
    git -C "$repo" checkout -q FETCH_HEAD
    printf 'fetched %s @ %s\n' "$name" "$sha"
    printf '%s\n' "$name" >> "$log"
  else
    printf 'UNFETCHABLE %s @ %s (deleted, private, or force-pushed)\n' "$name" "$sha" >&2
    rm -rf "$repo"
    printf '%s\n' "$name" >> "$log"
    printf '%s\n' "$slug" >> "$unfetchable"
  fi
done

# A record the loop rejected is fatal to the whole fetch, and the loop could
# only record that on disk.
if [ -f "$malformed" ]; then
  exit 1
fi

# `read`'s while loop above runs in a pipeline, so a POSIX shell forks it into a
# subshell and any counter set inside it vanishes when the loop ends — the log
# file is what survives. `total` is hardcoded rather than re-derived from the
# same awk pass that fills the log: deriving it from the manifest would let a
# format drift that makes awk match nothing shrink both sides together and pass
# at 0 == 0, hiding the exact failure this check exists to catch. 13 is the
# repository count `crates/claudevs/tests/corpus.rs` already asserts against the
# same manifest; bump both together if the corpus grows.
total=13
logged=0
if [ -f "$log" ]; then
  logged=$(wc -l < "$log" | tr -d ' ')
fi
if [ "$logged" -ne "$total" ]; then
  echo "corpus-fetch: manifest names $total repositories, accounted for $logged — some entry was neither cloned, cached, nor recorded unfetchable" >&2
  exit 1
fi
