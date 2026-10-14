---
status: executing
created: 2026-10-14
built-on: a5a235079e03
---

# Artifact Fingerprint Implementation Plan

**Goal:** Every chain artifact has a body fingerprint that a Lua library and a shell script
compute identically.

**Architecture:** One new Lua module, `scripts/lib/fingerprint.lua`, owns body extraction and
hashing; the board requires it in plan 02. One new shell script, `scripts/fingerprint.sh`,
computes the same value without `airsl`, for the status skill's fallback. The two share no
code, so a gate in `cargo make plugins-test` pins the shell side to the same literal values the
Lua tests assert, and that gate running on the Ubuntu CI job is what proves the shell pipeline
on Linux.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2 (`airsstack.hash.sha256`, `airsstack.fs`), POSIX
`sh`, `awk`, `shasum` or `sha256sum`, cargo-make.

**Content authority:** spec §2 (definition, the two implementations), §11 (fingerprint tests,
the fingerprint gate), premise P5.

---

## File structure

```
plugins/claudestacks-sdlc/scripts/lib/fingerprint.lua   — [create] body extraction and hashing
plugins/claudestacks-sdlc/scripts/fingerprint_test.lua  — [create] tests for lib/fingerprint
plugins/claudestacks-sdlc/scripts/fingerprint.sh        — [create] shell mirror of the library
Makefile.toml                                           — [modify] fingerprint gate in plugins-test
```

Every path below is relative to the repository root. The gate for every task is
`cargo make plugins-test`, run from the repository root; it needs the `airsl` binary
(`cargo make install-airsl`). No Rust changes, so the Rust Definition of Done does not apply.

Baseline before this plan, measured 2026-10-14:

```
$ cargo make plugins-test
399 passed, 0 failed (20 files)
```

**The fingerprint, stated once.** The first 12 hexadecimal characters of the SHA-256 of an
artifact's body. The body is every line after the line that closes the frontmatter (the first
line equal to `---` after line 1), with one trailing carriage return removed from each line and
each line terminated by exactly one `\n`. A file whose first line is not `---`, or whose
frontmatter is never closed, has no fingerprint.

**The eight cases.** Both implementations are tested on the same eight inputs, built from:

```
FM   = "---\nstatus: approved\ncreated: 2026-10-13\n---\n"
BODY = "# Spec: sample\n\nA line with --- inside it.\n---\nlast line"
```

| Case | Content | Fingerprint | Shell exit |
|---|---|---|---|
| `lf-final-newline.md` | `FM .. BODY .. "\n"` | `db42cc1eff57` | 0 |
| `lf-no-final-newline.md` | `FM .. BODY` | `db42cc1eff57` | 0 |
| `crlf.md` | the first case with every `\n` replaced by `\r\n` | `db42cc1eff57` | 0 |
| `status-flipped.md` | the first case with `approved` replaced by `done` | `db42cc1eff57` | 0 |
| `body-edited.md` | `FM .. BODY .. " changed\n"` | `02746658f17b` | 0 |
| `empty-body.md` | `FM` | `e3b0c44298fc` | 0 |
| `no-frontmatter.md` | `"# just a heading\n"` | none | 2 |
| `unterminated.md` | `"---\nstatus: draft\n"` | none | 2 |

These values were produced on 2026-10-13 and reproduced on 2026-10-14 by a prototype of the
code below, on macOS (Darwin 25.3.0). **Not verified: the shell side on Linux.** Task 4 closes
that.

**Decisions this plan makes where the spec is silent.** Each is reported to the author at the
plan's approval gate:

- `fingerprint.sh` exits 2, printing nothing, for a wrong argument count, an unreadable file,
  or a machine with neither hash tool. The spec names only "the file has no fingerprint".
- The gate runs its eight cases a second time with `shasum` hidden, so both tools the spec
  names are exercised where both exist.
- This plan is not marked `done` until the Ubuntu job has been seen green. The spec holds the
  *chain* to that; holding this plan to it surfaces a Linux failure before plans 02 to 07
  build on the fingerprint.

### Task 1 — Add the fingerprint library

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/fingerprint_test.lua`
- Create `plugins/claudestacks-sdlc/scripts/lib/fingerprint.lua`

**Steps:**

1. Write the failing tests in `plugins/claudestacks-sdlc/scripts/fingerprint_test.lua`:

   ```lua
   -- Tests for lib/fingerprint — body extraction and hashing. The literal
   -- values are the ones `scripts/fingerprint.sh` must print for the same
   -- files; the fingerprint gate in `cargo make plugins-test` checks that side.
   --
   --   airsl test --policy confined --allow-read / \
   --     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
   --     plugins/claudestacks-sdlc/scripts

   local fingerprint = require("lib.fingerprint")

   local fs = airsstack.fs
   local path = airsstack.path

   local FM = "---\nstatus: approved\ncreated: 2026-10-13\n---\n"
   local BODY = "# Spec: sample\n\nA line with --- inside it.\n---\nlast line"

   local function expect(text, want)
     local got, reason = fingerprint.of_text(text)
     assert(got == want, "want " .. tostring(want) .. ", got " .. tostring(got) .. " / " .. tostring(reason))
   end

   return {
     a_body_with_a_final_newline_has_the_recorded_fingerprint = function()
       expect(FM .. BODY .. "\n", "db42cc1eff57")
     end,

     a_missing_final_newline_does_not_change_the_fingerprint = function()
       expect(FM .. BODY, "db42cc1eff57")
     end,

     crlf_line_endings_do_not_change_the_fingerprint = function()
       expect((FM .. BODY .. "\n"):gsub("\n", "\r\n"), "db42cc1eff57")
     end,

     a_status_flip_does_not_change_the_fingerprint = function()
       expect(FM:gsub("approved", "done") .. BODY .. "\n", "db42cc1eff57")
     end,

     an_edited_body_changes_the_fingerprint = function()
       expect(FM .. BODY .. " changed\n", "02746658f17b")
     end,

     an_empty_body_has_the_fingerprint_of_the_empty_string = function()
       expect(FM, "e3b0c44298fc")
     end,

     missing_frontmatter_has_no_fingerprint = function()
       local got, reason = fingerprint.of_text("# just a heading\n")
       assert(got == nil and reason == "missing frontmatter", tostring(got) .. " / " .. tostring(reason))
     end,

     unterminated_frontmatter_has_no_fingerprint = function()
       local got, reason = fingerprint.of_text("---\nstatus: draft\n")
       assert(got == nil and reason == "unterminated frontmatter", tostring(got) .. " / " .. tostring(reason))
     end,

     a_file_is_fingerprinted_by_its_text = function()
       local file = path.join(fs.tempdir(), "spec.md")
       fs.write(file, FM .. BODY .. "\n")
       assert(fingerprint.of_file(file) == "db42cc1eff57", tostring(fingerprint.of_file(file)))
     end,

     an_unreadable_file_has_no_fingerprint = function()
       local got, reason = fingerprint.of_file(path.join(fs.tempdir(), "absent.md"))
       assert(got == nil and reason == "unreadable", tostring(got) .. " / " .. tostring(reason))
     end,
   }
   ```

   The two `:gsub` calls are wrapped so only the string reaches `expect`: `expect((…):gsub(…),
   "…")` passes `gsub`'s first result because the call is not the last argument.

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: the task fails. The summary line reads `399 passed, 1 failed (21 files)` and the
   failure is the test file not loading. `airsl` prints the scripts directory as an absolute
   path, shown here as `<repo>`:

   ```
   <repo>/plugins/claudestacks-sdlc/scripts/fingerprint_test.lua: lua error in <repo>/plugins/claudestacks-sdlc/scripts/fingerprint_test.lua: module `lib.fingerprint` not found under `<repo>/plugins/claudestacks-sdlc/scripts`
   ```

3. Write the implementation in `plugins/claudestacks-sdlc/scripts/lib/fingerprint.lua`:

   ```lua
   -- Body fingerprints for claudestacks-sdlc artifacts: the first 12 hex
   -- characters of the SHA-256 of an artifact's body.
   --
   -- Code side of the definition whose prose mirror is the "Fingerprints"
   -- section of `references/artifact-chain.md`, and whose shell mirror is
   -- `scripts/fingerprint.sh`; the three MUST agree.

   local fs = airsstack.fs
   local hash = airsstack.hash

   local M = {}

   -- Hex characters kept from the digest.
   M.LENGTH = 12

   -- The body of an artifact: every line after the line that closes the
   -- frontmatter, each stripped of one trailing carriage return and terminated
   -- by exactly one "\n". Returns the body, or nil and a reason.
   function M.body(text)
     local lines = {}
     for line in (text .. "\n"):gmatch("(.-)\r?\n") do
       lines[#lines + 1] = line
     end
     -- `text .. "\n"` yields one spurious empty last line when the text
     -- already ends with a newline.
     if text:sub(-1) == "\n" then
       lines[#lines] = nil
     end
     if lines[1] ~= "---" then
       return nil, "missing frontmatter"
     end
     local close
     for i = 2, #lines do
       if lines[i] == "---" then
         close = i
         break
       end
     end
     if not close then
       return nil, "unterminated frontmatter"
     end
     local body = {}
     for i = close + 1, #lines do
       body[#body + 1] = lines[i] .. "\n"
     end
     return table.concat(body)
   end

   -- The fingerprint of an artifact's text, or nil and a reason.
   function M.of_text(text)
     local body, reason = M.body(text)
     if not body then
       return nil, reason
     end
     return hash.sha256(body):sub(1, M.LENGTH)
   end

   -- The fingerprint of an artifact file, or nil and a reason.
   function M.of_file(file)
     local ok, text = pcall(fs.read, file)
     if not ok then
       return nil, "unreadable"
     end
     return M.of_text(text)
   end

   return M
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
   409 passed, 0 failed (21 files)
   ```

5. Confirm the new file compiles on its own, since nothing but the test loads it yet:

   ```
   $ cargo make plugins-check
   ```

   Expected: exit 0, and the count of compiled files is one higher than before this task for
   each of the two new Lua files.

6. Commit `feat(repo): add the sdlc artifact fingerprint library`.

### Task 2 — Add the shell fingerprint script

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/fingerprint.sh`

**Steps:**

1. Build one fixture and confirm the script does not exist yet. Run from the repository root:

   ```
   $ printf '%b' '---\nstatus: draft\n---\n# body\n' > "${TMPDIR:-/tmp}/fp-one.md"
   $ sh plugins/claudestacks-sdlc/scripts/fingerprint.sh "${TMPDIR:-/tmp}/fp-one.md"; echo "exit=$?"
   sh: plugins/claudestacks-sdlc/scripts/fingerprint.sh: No such file or directory
   exit=127
   ```

2. Write `plugins/claudestacks-sdlc/scripts/fingerprint.sh`:

   ```sh
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
   ```

   Two passes because POSIX `sh` has no `pipefail`: the first decides whether there is a
   fingerprint at all, so the second's pipeline can never print a hash for a file that has
   none.

3. Run it and confirm the three outcomes — a fingerprint, a missing file, and no argument:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/fingerprint.sh "${TMPDIR:-/tmp}/fp-one.md"; echo "exit=$?"
   7df83709971b
   exit=0
   $ sh plugins/claudestacks-sdlc/scripts/fingerprint.sh "${TMPDIR:-/tmp}/fp-absent.md"; echo "exit=$?"
   exit=2
   $ sh plugins/claudestacks-sdlc/scripts/fingerprint.sh; echo "exit=$?"
   exit=2
   ```

   `7df83709971b` is the fingerprint of the body `# body\n`; plan 02's test fixtures all carry
   that body.

4. Confirm it agrees with the committed artifacts of this chain:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/fingerprint.sh .claudestacks/sdlc/2026-10-13-sdlc-roadmaps-milestones/spec.md
   ```

   Expected: the value of `built-on:` in this plan's own frontmatter. If the spec has been
   amended since this plan was approved the two differ; stop and report it rather than
   continuing, because every plan in this chain was written against the recorded text.

5. Remove the fixture (`rm "${TMPDIR:-/tmp}/fp-one.md"`) and commit
   `feat(repo): add the sdlc shell fingerprint script`.

### Task 3 — Gate the shell script in `plugins-test`

**Files:**
- Modify `Makefile.toml`

**Steps:**

1. In `Makefile.toml`, the `plugins-test` task ends with this script
   (`Makefile.toml:150-163`):

   ```toml
   script_runner = "@shell"
   script = '''
   set -e
   if ! command -v airsl >/dev/null 2>&1; then
       echo "airsl is not installed: cargo make install-airsl" >&2
       exit 1
   fi
   set -x
   airsl test --policy confined \
     --allow-read / \
     --allow-write "${TMPDIR:-/tmp}" \
     --allow-exec git \
     plugins
   '''
   ```

   Replace it with the following. The first lines are unchanged; everything from `set +x` on
   is new:

   ```toml
   script_runner = "@shell"
   script = '''
   set -e
   if ! command -v airsl >/dev/null 2>&1; then
       echo "airsl is not installed: cargo make install-airsl" >&2
       exit 1
   fi
   set -x
   airsl test --policy confined \
     --allow-read / \
     --allow-write "${TMPDIR:-/tmp}" \
     --allow-exec git \
     plugins
   set +x

   # The fingerprint gate. `scripts/fingerprint.sh` is the one piece of the
   # claudestacks-sdlc board with no Lua test: it exists for machines without
   # airsl. It must print exactly what `lib/fingerprint.lua` computes, and
   # fingerprint_test.lua asserts these same literals on the Lua side. Run
   # here so the Ubuntu job proves the pipeline on Linux.
   FP_SH=plugins/claudestacks-sdlc/scripts/fingerprint.sh
   FP_DIR=$(mktemp -d)
   trap 'rm -rf "$FP_DIR"' EXIT
   FM='---\nstatus: approved\ncreated: 2026-10-13\n---\n'
   BODY='# Spec: sample\n\nA line with --- inside it.\n---\nlast line'
   printf '%b' "${FM}${BODY}\n" > "$FP_DIR/lf-final-newline.md"
   printf '%b' "${FM}${BODY}" > "$FP_DIR/lf-no-final-newline.md"
   printf '%b' "${FM}${BODY}\n" | awk '{ printf "%s\r\n", $0 }' > "$FP_DIR/crlf.md"
   printf '%b' "${FM}${BODY}\n" | sed '2s/approved/done/' > "$FP_DIR/status-flipped.md"
   printf '%b' "${FM}${BODY} changed\n" > "$FP_DIR/body-edited.md"
   printf '%b' "${FM}" > "$FP_DIR/empty-body.md"
   printf '%s\n' '# just a heading' > "$FP_DIR/no-frontmatter.md"
   printf '%s\n' '---' 'status: draft' > "$FP_DIR/unterminated.md"
   fail=0
   FP_PATH=$PATH
   check() {
     got=$(PATH="$FP_PATH" /bin/sh "$FP_SH" "$FP_DIR/$1") && code=0 || code=$?
     if [ "$got" != "$2" ] || [ "$code" != "$3" ]; then
       echo "fingerprint gate: $1: want '$2' exit $3, got '$got' exit $code" >&2
       fail=1
     fi
   }
   cases() {
     check lf-final-newline.md    db42cc1eff57 0
     check lf-no-final-newline.md db42cc1eff57 0
     check crlf.md                db42cc1eff57 0
     check status-flipped.md      db42cc1eff57 0
     check body-edited.md         02746658f17b 0
     check empty-body.md          e3b0c44298fc 0
     check no-frontmatter.md      ""           2
     check unterminated.md        ""           2
   }
   cases
   [ "$fail" = 0 ] || exit 1
   echo "fingerprint gate: 8 cases passed"
   # fingerprint.sh prefers shasum, so where both tools exist the sha256sum
   # branch never runs above. Run the cases again with a PATH holding only what
   # the script needs and no shasum.
   if command -v shasum >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
     mkdir "$FP_DIR/bin"
     for tool in awk cut sha256sum; do
       ln -s "$(command -v "$tool")" "$FP_DIR/bin/$tool"
     done
     FP_PATH="$FP_DIR/bin"
     cases
     [ "$fail" = 0 ] || exit 1
     echo "fingerprint gate: 8 cases passed with sha256sum"
   fi
   '''
   ```

   Fixtures are written with `printf '%b'` and `printf '%s\n'` rather than a format string
   that starts with `---`: a format beginning with `-` is taken for an option by `printf`
   (observed on macOS: `printf: --: invalid option`).

   The script picks `shasum` when it is on the path, so one pass would leave its `sha256sum`
   branch unrun on any machine that has both. The second pass hides `shasum` by giving the
   script a `PATH` that holds only `awk`, `cut` and `sha256sum`. On a machine with one of the
   two tools the second pass is skipped and only the first line is printed.

2. See the gate fail before trusting it. Temporarily change the fifth `check` line to expect a
   wrong value:

   ```
   check body-edited.md         ffffffffffff 0
   ```

   Run it:

   ```
   $ cargo make plugins-test
   ```

   Expected: the task fails after the Lua tests pass, with exactly one gate line:

   ```
   fingerprint gate: body-edited.md: want 'ffffffffffff' exit 0, got '02746658f17b' exit 0
   ```

3. Restore the line to `check body-edited.md         02746658f17b 0` and confirm green:

   ```
   $ cargo make plugins-test
   ```

   Expected: `409 passed, 0 failed (21 files)` followed by
   `fingerprint gate: 8 cases passed` and, on a machine with both hash tools (this one has
   `/usr/bin/shasum` and `/sbin/sha256sum`),
   `fingerprint gate: 8 cases passed with sha256sum`; exit 0.

4. Commit `build(workspace): gate the sdlc shell fingerprint in plugins-test`. The scope is
   `workspace` because the only file changed is `Makefile.toml`, top-level configuration.

### Task 4 — Prove the shell fingerprint on Linux

**Steps:**

1. **Checkpoint — stop here and hand to the author.** The spec makes the Linux result a gate,
   not an assumption (§11): nothing in this plan has run on Linux, and the three commits above
   must reach GitHub for the Ubuntu job to run. Pushing is the author's act. Report the three
   commits and ask the author to push the branch and open or update its pull request.

2. Once pushed, read the result of the `airsl test` job of the `lua.yml` workflow
   (`.github/workflows/lua.yml:89-116`, `runs-on: ubuntu-latest`):

   ```
   $ gh run list --workflow lua.yml --branch "$(git branch --show-current)" --limit 1
   $ gh run view <run id> --log | grep -n 'fingerprint gate'
   ```

   Expected: the log holds `fingerprint gate: 8 cases passed`. Whether it also holds
   `fingerprint gate: 8 cases passed with sha256sum` depends on whether the runner has
   `shasum`; that is not verified. Record which lines appear: with only the first line, the
   log shows which single tool Linux exercised only by the absence of the second.

3. If the job fails on a `fingerprint gate:` line, the pipeline differs on Linux. Do not
   adjust the expected values: the Lua side is the definition. Fix `fingerprint.sh`, re-run
   Task 3 step 3 locally, and repeat this task. Record what differed in this plan's
   `## Deviations`.

4. Record the run's URL and the gate line in this plan's `## Probe results`. Plans 02 to 07
   build on a fingerprint the shell side can reproduce; do not mark this plan `done` before
   the job is green.

---

## Verification summary (plan-level)

- `cargo make plugins-check` exits 0 with `lib/fingerprint.lua` and `fingerprint_test.lua`
  compiled.
- `cargo make plugins-test` prints `409 passed, 0 failed (21 files)` and
  `fingerprint gate: 8 cases passed`.
- The gate has been seen failing (Task 3 step 2) and seen green on `ubuntu-latest` (Task 4).
- `sh plugins/claudestacks-sdlc/scripts/fingerprint.sh` over this chain's `spec.md` prints the
  `built-on` value this plan carries.

## Review findings

One `claudestacks:reviewer` round over Tasks 1–3 (report
`.airsstack/cc/plugins/claudestacks/handoff/20261014-094648-c59e/10-reviewer-plan01.md`, git-ignored).
Verdict: all four files byte-identical to this plan's code blocks; DoD green on re-run; code
0🔴 3🟡 7🔵, spec 0🔴 1🟡; blocking set empty. No fix round: every fix changes text this plan
gives verbatim, and two change the pipeline spec §2 quotes (`spec.md:179-180`), so they wait for
the author.

- correctness — pass 2's `awk` can die mid-file under a UTF-8 locale and the pipeline still exits 0, printing the hash of a truncated body — `scripts/fingerprint.sh:32` — open, author's call. Reproduced (Probe results).
- mirror disagreement — the shell and Lua sides disagree on a UTF-8 byte-order mark, a non-UTF-8 byte and a NUL; `LC_ALL=C` on both `awk` calls closes the first two in Lua's direction — `fingerprint.sh:26` — open, author's call. BOM row reproduced (Probe results).
- test teeth — deleting the first-line check (`fingerprint.sh:26`) or the argument guards (`:12-13`) leaves the gate green on both passes; a file with no frontmatter but a `---` rule then gets a fingerprint — `Makefile.toml:192` — open, author's call.
- claim disproven — "the second's pipeline can never print a hash for a file that has none" — this plan, lines 327-329 — open, see the first finding.
- nit — an operand shaped `name=value` is read by `awk` as an assignment — `fingerprint.sh:32` — not fixed; unreachable from the documented call.
- nit — `fingerprint.sh` is mode 0644 beside the 0755 `status.sh` — not fixed; it is always run as `sh fingerprint.sh`.
- nit — header says "carriage returns stripped"; only one trailing CR per line is — `fingerprint.sh:4` — not fixed.
- nit — header lists three exit-2 causes; there are five — `fingerprint.sh:8` — not fixed.
- nit — cites a "Fingerprints" section of `references/artifact-chain.md` that plan 02 adds — `lib/fingerprint.lua:4` — resolved by plan 02 Task 7 (`### 10.1`).
- nit — "the one piece … with no Lua test": `status.sh` has none either — `Makefile.toml:166` — not fixed.
- nit — task description still says only `airsl test` — `Makefile.toml:145` — not fixed.
- nit — `mktemp -d` is outside POSIX.1-2017 — `Makefile.toml:171` — not fixed; present on macOS and Ubuntu.

## Probe results

- Baseline before Task 1: `cargo make plugins-test` → `399 passed, 0 failed (20 files)`.
- Task 1 red: `399 passed, 1 failed (21 files)`, module `lib.fingerprint` not found under the absolute scripts path; green: `409 passed, 0 failed (21 files)`; `plugins-check`: `69 file(s) compiled, 0 failed`.
- Task 2: before the script existed `exit=127`; fixture `7df83709971b` exit 0; missing file and no argument exit 2 with no output; this chain's `spec.md` → `a5a235079e03`, equal to `built-on`.
- Task 3 red (`ffffffffffff` expected for `body-edited.md`): `fingerprint gate: body-edited.md: want 'ffffffffffff' exit 0, got '02746658f17b' exit 0`, task exits 1, printed once (the first pass fails before the second runs); green: `fingerprint gate: 8 cases passed` and `fingerprint gate: 8 cases passed with sha256sum`.
- Tools on this machine: `/usr/bin/shasum`, `/sbin/sha256sum`, `/usr/bin/awk`, `/usr/bin/cut`.
- **Against this plan** — reviewer finding 1, re-run by the orchestrator on macOS (`LANG=en_US.UTF-8`, `LC_ALL` unset), body `good one\ngood two\nbad \377\nafter\n`: the delivered script prints `6c7aaaf52995` exit 0, which is the hash of `good one\ngood two\n` alone; the raw body hashes to `73de1d2ccb91`; a copy with `LC_ALL=C` before both `awk` calls prints `73de1d2ccb91`.
- Reviewer finding 2, BOM row, same run: a file starting `\357\273\277---` prints `9e2ec912af5d` exit 0 from the delivered script (Lua: missing frontmatter); with `LC_ALL=C` it prints nothing, exit 2.
- Linux (Task 4): not run yet.

## Deviations

- **2026-10-14 — one review over Tasks 1–3** instead of one per batch (Tasks 1–2 ran in
  parallel, Task 3 after them).
- **2026-10-14 — no per-task commits yet.** Committing is the author's act; Task 4 waits on
  the three commits and the author's push.
