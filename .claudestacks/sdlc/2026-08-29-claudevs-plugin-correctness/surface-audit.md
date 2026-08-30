# Surface audit — `claudevs` public enums and structs against the five-bullet rule

Written for `06-closing.md` Task 1. No source file was touched to produce this table.

## 1. Enumeration, done twice, independently

**Method A — `grep`, exactly the command the plan names:**

```
$ grep -rn '^pub struct \|^pub enum ' crates/claudevs/src/ | wc -l
51
```

Sanity check that the pattern actually finds things (not just an empty match): it returns
`crates/claudevs/src/error.rs:14:pub enum Error {`, which is the one type everybody already
expects to be there. A second pass without the `^` anchor
(`grep -rn 'pub struct \|pub enum ' crates/claudevs/src/ | wc -l`) also returns 51 and
`grep -rEn '^\s+pub (struct|enum) ' crates/claudevs/src/` returns nothing, so there is no
indented (nested-module) declaration the anchored pattern is missing.

**Method B — `cargo +nightly rustdoc --output-format json`, a different tool entirely:**

```
$ cargo +nightly rustdoc -p claudevs --lib -- -Z unstable-options --output-format json
$ python3 -c "
import json
data = json.load(open('target/doc/claudevs.json'))
names = set()
for id_, item in data['index'].items():
    inner = item.get('inner')
    if not isinstance(inner, dict):
        continue
    if 'struct' not in inner and 'enum' not in inner:
        continue
    if item.get('visibility') != 'public':
        continue
    if data['paths'].get(id_, {}).get('crate_id') != 0:
        continue
    names.add(item['name'])
print(len(names))
"
51
```

**Result: both methods agree at 51, and the 51 names are identical sets** (checked by hand,
not just the count — see the full list in §2/§3). 51 = 44 baseline + the 7 types plans 01, 02
and 04 added (`DocumentedEvent`, `MatcherSupport`, `DecisionMechanism`, `MatcherRule`,
`HookCommand`, `Strictness`, `Mismatch`). **The plan's count is confirmed, not merely copied**:
removing exactly those 7 names from the 51-name set leaves a set that matches the plan's
44-row baseline table name-for-name.

One nuance surfaced by method B, not method A: `case/model.rs`'s `model` submodule is
private (`case/mod.rs` has `mod model;`, not `pub mod model;`), and `ProjectField` is not in
`case/mod.rs`'s `pub use model::{...}` re-export list — yet rustdoc still lists it as a public
item, because it appears in a public field's type (`RawCase.project: Option<ProjectField>`,
`case/model.rs:171`). It cannot be named as a path from outside the crate
(`claudevs::case::model::ProjectField` does not compile — `model` is private, and there is no
alias), but a value of that type is reachable through `RawCase.project`, and downstream code
could still write `match raw_case.project { Some(ProjectField::Bare(_)) => ... }` **if** it
could name the type — which it cannot, so in practice no downstream `match` on this enum's
variants is currently possible from outside the crate at all. Recorded here because it bears
on whether `ProjectField`'s bullet-3 classification (below) is actually load-bearing; not
re-derived as a fourth "unclassified" type because the plan named exactly three and I was
told to raise, not add to that list unilaterally — flagging it as an open question instead.

`#[non_exhaustive]` currently present in the tree (`grep -rn '#\[non_exhaustive\]'
crates/claudevs/src/`, filtered to the lines immediately preceding an item, not to prose that
merely mentions the attribute):

```
error.rs:13              → Error (baseline; "already carries it" per the plan)
contract/handler.rs:17   → HookCommand (chain addition; plan 01)
contract/event.rs:41     → DecisionMechanism (chain addition; plan 01)
contract/event.rs:71     → DocumentedEvent (chain addition; plan 01)
harness/verdict.rs:39    → Mismatch (chain addition; plan 04)
```

Five, not one. The plan's architecture line ("carries exactly one `#[non_exhaustive]`, on
`Error`") describes the code **before this chain**, per Task 1 step 3's own preamble ("the
classification as the code stood before this chain") — it is accurate about the pre-chain
baseline and not about the tree as it stands today, which already carries four of this
chain's additions. Not a defect in the plan; recorded so the number "one" is not read as a
live fact about the current tree.

## 2. Baseline 44 — classification as the code stands now

Every `File:line` below was opened in this session; a line number that has drifted from the
plan's own table (plan 05 touched several of these files) is corrected here to the current
line, not copied.

| Type | File:line | Bullet | Note |
|---|---|---|---|
| `Error` | `error.rs:14` | 3 | Already `#[non_exhaustive]` (`error.rs:13`). |
| `SuiteOptions` | `suite.rs:24` | 4 | `derive(..., Default)`, no other traits. `crates/claudevs-cli/src/cli.rs:101` constructs it as a literal today (`claudevs::SuiteOptions { case_filter: case }`) — this is the exact site Task 2 step 1 says to expect. |
| `CaseOutcome` | `suite.rs:31` | 2 | All-public fields, no `Default`. |
| `SuiteReport` | `suite.rs:50` | 2 | Plan gave `suite.rs:40`; current line is 50 (plan 05 shifted the file). All-public fields. |
| `StageStatus` | `check.rs:24` | 3 | Plan gave `check.rs:25`; current is 24. No `Default`. |
| `Stage` | `check.rs:35` | 2 | Plan gave `check.rs:36`; current is 35. All-public fields. |
| `CheckReport` | `check.rs:46` | 2 | Plan gave `check.rs:47`; current is 46. **Derives `Default`** despite being bullet 2, not 4 — it is a report struct (`stages: Vec<Stage>`), not caller-constructed; `Default` here is a convenience (e.g. for building an empty report), not a construction contract. Worth a footnote precisely because bullet 4's own wording leads with "implements `Default`" — the discriminator is "caller-constructed", not the derive. |
| `Validation` | `validate.rs:20` | 3 | Plan gave `validate.rs:19`; current is 20. No `Default`; produced only by `validate::run`. |
| `ProbeStatus` | `doctor.rs:36` | 3 | No `Default`. |
| `Probe` | `doctor.rs:48` | 2 | All-public fields. |
| `Diagnosis` | `doctor.rs:59` | 2 | All-public fields. |
| `HookEvent` | `types/hook_event.rs:15` | 1 | Plan gave `types/hook_event.rs:10`; current is 15. Enum, Claude-Code-decided event-name set. **Lives in `types/mod.rs`, the module Task 3 will document as "validating newtypes... none of these carries `#[non_exhaustive]`"** — but `HookEvent` is bullet 1, not 5, and per this table it does get `#[non_exhaustive]` in Task 2. Task 3's module doc (not written yet) needs to describe `HookEvent` correctly alongside the four true newtype/error pairs, or say something false about the one type in that file that isn't exempt. Raising for Task 3, not fixing here. |
| `InvalidHookEvent` | `types/hook_event.rs:33` | 5 | Plan gave `types/hook_event.rs:28`; current is 33. Error struct for the newtype above it in the same bullet-5 family. |
| `PluginVersion` | `types/plugin_version.rs:12` | 5 | Newtype, one validated field (checked: `is_segment` validation via `crate::types::ident`). |
| `InvalidPluginVersion` | `types/plugin_version.rs:17` | 5 | Error struct. |
| `PluginName` | `types/plugin_name.rs:11` | 5 | Newtype, validated. |
| `InvalidPluginName` | `types/plugin_name.rs:16` | 5 | Error struct. |
| `MarketplaceName` | `types/marketplace_name.rs:12` | 5 | Newtype, validated. |
| `InvalidMarketplaceName` | `types/marketplace_name.rs:17` | 5 | Error struct. |
| `CaseName` | `types/case_name.rs:8` | 5 | Newtype, validated. |
| `InvalidCaseName` | `types/case_name.rs:13` | 5 | Error struct. |
| `NativeOutcome` | `native/declared.rs:24` | 2 | All-public fields, no `Default`. |
| `PluginManifest` | `layout/manifest.rs:22` | 2 | All-public fields, no `Default`. Only ever produced by `layout::manifest::read`; no literal construction found anywhere in the tree. |
| `Installed` | `layout/installed.rs:26` | 2 | **All three fields private** (`root`, `plugin_root`, `registry`); constructed only via `Installed::materialize`. External literal construction is already impossible without the attribute — see §4. |
| `Severity` | `wiring/finding.rs:11` | 3 | No `Default`. |
| `Finding` | `wiring/finding.rs:20` | 2 | All-public fields. |
| `WiringReport` | `wiring/finding.rs:35` | 2 | **Derives `Default`** (used by Task 6's `claudevs::wiring::run(root).unwrap_or_default()`), same "report struct, not caller-constructed" situation as `CheckReport`. |
| `FencedCommand` | `wiring/invocations.rs:40` | 2 | Plan gave `wiring/invocations.rs:33`; current is 40. All-public fields. |
| `Observed` | `harness/semantics.rs:30` | 2 | Plan gave `harness/semantics.rs:19`; current is 30. **Derives `Default`**, same "report struct with a convenience `Default`, not caller-constructed" situation as `CheckReport`/`WiringReport`. |
| `Captured` | `harness/spawn.rs:19` | 2 | All-public fields, no `Default`. |
| `Project` | `harness/project.rs:44` | 2 | Plan gave `harness/project.rs:13`; current is 44 (plan 05 shifted this file substantially). **One field, private** (`dir: tempfile::TempDir`); constructed only via `Project::empty()` / `Project::from_fixture(...)`. Same already-privacy-closed situation as `Installed` — see §4. |
| `Verdict` | `harness/verdict.rs:15` | 3 | Plan gave `harness/verdict.rs:13`; current is 15. No `#[non_exhaustive]` yet (unlike its sibling `Mismatch`, which already has it). |
| `TModule` | `harness/t_module.rs:59` | **unclassified — raised, see §4** | Plan gave `harness/t_module.rs:58`; current is 59. |
| `LuaFile` | `case/lua.rs:19` | 2 | Two public fields (`cases`, `scripted`), two `pub(crate)` fields (`engine`, `table`). Same already-privacy-closed situation as `Installed`/`Project` — see §4. |
| `CaseFile` | `case/discover.rs:14` | 3 | No `Default`; produced only by `discover()`. |
| `FixtureRef` | `case/model.rs:16` | **unclassified — raised, see §4** | |
| `Invocation` | `case/model.rs:21` | **unclassified — raised, see §4** | |
| `Decision` | `case/model.rs:32` | 3 | `#[derive(..., serde::Deserialize, serde::Serialize)]`, no `Default`. Deserialized as part of a case file's `expect:` block, never literal-constructed outside the crate in this tree. |
| `Expectations` | `case/model.rs:48` | 4 | **Derives `Default`.** `#[cfg(test)]` code elsewhere in the crate already relies on `Expectations { exit: Some(0), ..Expectations::default() }` (matches Task 2 step 1's example), so this one is genuinely caller-constructed, unlike `CheckReport`/`WiringReport`/`Observed` above. |
| `Step` | `case/model.rs:91` | 2 | All-public fields, no `Default`. |
| `CaseKind` | `case/model.rs:105` | 3 | No `Default`. |
| `Case` | `case/model.rs:131` | 2 | All-public fields but constructed only via the fallible `Case::from_raw(name, raw)` (`case/model.rs:201`) — no `pub fn new`, no literal construction found in the tree. |
| `RawCase` | `case/model.rs:150` | 2 | All-public fields, `#[serde(deny_unknown_fields)]`. No literal `RawCase { ... }` construction anywhere in the tree (`grep -rn 'RawCase {' crates/`) — always deserialized from a case file. |
| `ProjectField` | `case/model.rs:180` | 3 | See the reachability nuance in §1 — classification kept as the plan has it; flagging that its practical effect is unclear given the type is not path-nameable outside the crate. |

Count: 44 rows, matching §1's derived baseline.

## 3. Chain additions (7) — plans 01, 02, 04

| Type | File:line | Bullet | Already `#[non_exhaustive]`? |
|---|---|---|---|
| `DocumentedEvent` | `contract/event.rs:73` | 2 | Yes (`contract/event.rs:71`). Confirmed. |
| `MatcherSupport` | `contract/event.rs:17` | 1 | **No** — confirmed absent by reading the file; Task 2 needs to add it. |
| `DecisionMechanism` | `contract/event.rs:43` | 1 | Yes (`contract/event.rs:41`). Confirmed. |
| `MatcherRule` | `contract/matcher.rs:52` | 3 | **No** — confirmed absent; Task 2 needs to add it. |
| `HookCommand` | `contract/handler.rs:18` | 1 | Yes (`contract/handler.rs:17`). Confirmed. |
| `Strictness` | `validate.rs:50` | 4, with the plan's own caveat | **No** — confirmed absent. Derives `Copy` + `Default` (`#[default]` on `Lenient`); `crates/claudevs-cli/src/cli.rs:91-95` constructs both variants by name (`claudevs::Strictness::Strict` / `::Lenient`), never a literal struct (it's a fieldless enum, so there is nothing to construct as a literal) — matches the plan's own note that bullet 4 is a stretch for a fieldless enum. Not re-deciding here; the plan already flagged this as a possible fourth unclassified type and left the call to Task 2. |
| `Mismatch` | `harness/verdict.rs:40` | 3 | Yes (`harness/verdict.rs:39`). Confirmed. |

Count: 7 rows, matching §1.

## 4. The three unclassified types — raised, not decided

**`FixtureRef` (`case/model.rs:16`)** — `pub struct FixtureRef(pub String)`. Confirmed by
reading the file and grepping for any validating `impl` (`grep -n 'FixtureRef'
case/model.rs`): there is none. The field is `pub`, not private, and nothing rejects a bad
value before construction. It is used at three sites (`case/model.rs:100`, `:137`, `:184`) as
a plain name carrier. So it is either (a) a newtype that should gain validation, after which
bullet 5 applies, or (b) not really a newtype at all — just a transparent wrapper — in which
case bullet 2 (callers only read the resolved fixture name) fits. I have not picked between
these; both are consistent with what is in the tree today.

**`Invocation` (`case/model.rs:21`)** — confirmed **does not** derive `Default`
(`#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]`, `case/model.rs`
around line 21, contrasted against `Expectations` at line 48, which is otherwise structurally
similar and does derive `Default`). Per the plan's own logic, bullet 4 requires `Default`, so
by the letter of the rule `Invocation` does not qualify for bullet 4 as written. That leaves
the spec's own escape hatch — "a config struct without one would be left open and given a
builder instead" — which is a design decision (add a builder, or add `Default`, or leave it
open with no attribute at all) that Task 1 is not the place to make.

**`TModule` (`harness/t_module.rs:59`)** — read in full. All four fields are private (`name`,
`plugin_dir`, `fixtures_root`, `projects`); the only way to build one is the public constructor
`TModule::new(plugin_dir, fixtures_root)` (`harness/t_module.rs:70`), and the only two call
sites in the tree are internal (`case/lua.rs:107`, `t_module.rs:663`, its own test). So it is
caller-constructible (via `new`, not a literal) but not read-only, which is why it does not
fit bullet 2. It also has no `Default` and no natural one (both constructor arguments are
required paths), so it does not fit bullet 4 either. **Because every field is already private,
`#[non_exhaustive]` on this struct would have no observable effect**: external literal
construction is already rejected by the compiler today regardless of the attribute, and a
future private field can already be added without breaking any downstream code, attribute or
not (the only pattern downstream code can write against an all-private-field struct is
`TModule { .. }`, which stays valid either way). This looks like the rule's missing sixth
category — an opaque, constructor-gated handle type, not a report and not a config struct —
and I have not silently assigned it a bullet.

## 5. Additional finding — the "no observable effect" property is not unique to `TModule`

Checking every bullet-2 row's field visibility (not asked for by name, but necessary to
actually evaluate whether "callers only read" is true) turned up the same structural property
in three baseline rows the plan places in bullet 2 without comment:

- **`Installed`** (`layout/installed.rs:26`) — all three fields (`root`, `plugin_root`,
  `registry`) are private; built only via `Installed::materialize`.
- **`Project`** (`harness/project.rs:44`) — its one field (`dir`) is private; built only via
  `Project::empty()` / `Project::from_fixture(...)`.
- **`LuaFile`** (`case/lua.rs:19`) — two fields public (`cases`, `scripted`), two `pub(crate)`
  (`engine`, `table`); a `pub(crate)` field is invisible outside the crate, so external literal
  construction is already impossible today regardless of the attribute.

For all three, `#[non_exhaustive]` is not wrong to add — it costs nothing and documents intent
— but it will not be *doing* anything an outside caller could observe, for the same reason as
`TModule`: the struct is already closed to external literal construction by field privacy
alone. I have not changed their bullet-2 classification (they are, in every other respect,
read-only report/handle structs that fit the plan's description), but flagging this because
Task 2's own step 4 asks for a throwaway file proving the attribute "bites" — that proof needs
to use a genuinely open struct (e.g. `CheckReport` or `Captured`, both all-public-field), not
one of these four, or the throwaway will compile with or without the attribute and prove
nothing.

## 6. Summary for Task 2

- 44 baseline rows classified above; every file:line re-verified against the current tree, five
  differ from the plan's stated line numbers because plan 05 moved code in those files.
- 7 chain-addition rows classified; 4 already carry `#[non_exhaustive]` (verified by reading
  the source, not by trusting the plan's "verify" label), 3 do not yet (`MatcherSupport`,
  `MatcherRule`, `Strictness`) and are Task 2's work.
- Three types raised as fitting no bullet (`FixtureRef`, `Invocation`, `TModule`), each with the
  reading above; none decided here.
- A related, non-identical finding: `Installed`, `Project` and `LuaFile` are bullet-2 by the
  rule's letter but already privacy-closed, so the attribute would be inert on them — worth
  Task 2's attention when picking a demonstration site for "prove the attribute bites."
- `HookEvent` sits in `types/mod.rs` but is bullet 1 (gets the attribute), not bullet 5 (exempt)
  — Task 3's module-doc paragraph needs to account for it, since that paragraph is currently
  planned to describe every type in the file as exempt and `HookEvent` will not be.
