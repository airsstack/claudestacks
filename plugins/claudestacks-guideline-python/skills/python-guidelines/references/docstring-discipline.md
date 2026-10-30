# Python — Docstring & Comment Discipline (Present, Accurate, and No Internal-Artifact Leakage)

Docstrings and `#` comments address **engineers reading or consuming this package** — its public
surface, invariants, constraints and behaviour. They do NOT address the project's internal
development process. Anything that exists only because of how the repository is *managed* (AI
policies, plan documents, phase or task identifiers, internal review cycles) stays out of source
files.

A docstring or comment has three duties, and they are independent. It must **exist** where a caller
needs it: every public module, class and function carries a Google-convention docstring. It must be
**true** of the code beside it. And it must be **about the code** rather than about the process that
produced it. A comment can satisfy any one while failing the others, so all three are checked.

The accuracy and leakage rules are carried over from the sibling Rust guideline's doc-comment
discipline and restated for docstrings and `#` comments. This file reinforces the
suppression-reason rule in `strict-quality.md`, and complements
`init-export-only.md` (what a package's `__init__.py` holds, including its docstring). Docstring
conventions for exception classes meet the hierarchy rules in `errors.md`.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each observation was made on a
copy of a project carrying the baseline of `strict-quality.md`, on which all five gate commands
exited `0` first. Where a copy held several defects, each sat in its own function or module and the
rule code was attributed by the `file:line` in `ruff check --no-fix --output-format concise`. Claims
about what a document says give its line and the words quoted, fetched on 2026-10-30 with
`curl -sS -L` from URLs that track the default branch, so the live text can have moved since:
`pyguide.md` is `https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`;
`pep-0257.rst` is `https://raw.githubusercontent.com/python/peps/main/peps/pep-0257.rst`. Claims about
a Ruff rule or setting quote the output of `uvx ruff@0.17.3 rule <CODE>` and `uvx ruff@0.17.3 config
lint.pydocstyle.convention`.

## Every public module, class and function has a docstring

A docstring is "a string literal that occurs as the first statement in a module, function, class, or
method definition" and becomes `__doc__` (`pep-0257.rst:46-48`); "All modules should normally have
docstrings, and all functions and classes exported by a module should also have docstrings. Public
methods (including the ``__init__`` constructor) should also have docstrings. A package may be
documented in the module docstring of the ``__init__.py`` file in the package directory"
(`pep-0257.rst:50-54`). Google adds that a docstring is mandatory for any function that is "part of
the public API", of "nontrivial size", or has "non-obvious logic" (`pyguide.md:2200-2205`), and
that files "should start with a docstring describing the contents and usage of the module"
(`pyguide.md:2127-2128`). The baseline's `convention = "google"` makes Ruff apply that style.

**Gate-enforced.** `D100`–`D107` fail the `ruff check --no-fix` step (*observed*, exit `1` each):

| Missing docstring on | Rule code |
|---|---|
| a public function | `D103` — the only defect in its copy: `Missing docstring in public function` |
| a public module | `D100` |
| a public class | `D101` |
| a public method | `D102` |
| a package's `__init__.py` | `D104` |
| a magic method such as `__repr__` | `D105` |
| a public nested class | `D106` |
| `__init__` | `D107` |

Only the `ruff check` step failed in the `D103` copy; `ruff format --check`, `mypy --strict .` and
`pytest` exited `0`. The gate demands a docstring on every public name whatever its size. Google's
"nontrivial size" and "non-obvious logic" qualifiers reach functions outside the public API, which
the gate does not check; review holds those (**held by review**).

**What counts as public** is Ruff's reading, *observed* in one project:

- A leading underscore makes a function, method or module private. A class and function in
  `_private.py` with no docstrings, a `_helper` function holding a nested function, and a
  `_private_method` drew no report.
- In a module with `__all__ = ["listed"]`, a public-named function absent from `__all__` drew no
  report. Privacy comes from a leading underscore or from `__all__`.
- A method decorated `@override` with no docstring drew no report. That matches Google: a method
  that overrides "does not need a docstring if it is explicitly decorated with ``@override``,
  unless the overriding method's behavior materially refines the base method's contract"
  (`pyguide.md:2380-2386`). Whether a refinement is "material" is **held by review**: when it is, the
  override carries a docstring stating the difference. `@override` itself is enforced
  (`strict-quality.md`).
- A bare `"""See base class."""` on an `@override` method is trivial and carries no information
  (`pyguide.md:2412-2417`); omit it. Held by review: no rule reports it.

**Tests are exempt from the gate, not from clarity.** The baseline's
`"tests/**" = [..., "D"]` turns the `D` family off there, and Google agrees: "Test modules do not
require module level docstrings", and a docstring "that only repeats class or method name should be
omitted" (`pyguide.md:2153-2156`). A docstring in a test earns its place when it gives specifics on
"how the test should be run or explaining an unusual setup pattern or external dependency"
(`pyguide.md:2158-2160`); "Docstrings that do not provide any new information should not be used"
(`pyguide.md:2173`). The leakage rule below applies to tests in full.

## Google-convention shape

Use `"""` for every docstring (`pyguide.md:2106-2108`; `pep-0257.rst:72-74`). The docstring opens
with a summary line, "one physical line not exceeding 80 characters", ended by "a period, question
mark, or exclamation point"; more text follows after a blank line (`pyguide.md:2108-2113`).

**Gate-enforced** (*observed*, `ruff check --no-fix` exit `1`; the `ruff format --check` step
also exited `1` where marked):

| Defect | Rule code |
|---|---|
| summary line with no final period | `D415` |
| no blank line between summary and description | `D205` (and `D411` for an `Args:` section that follows directly) |
| summary starting on the second line | `D212` |
| a one-line docstring spread over three lines | `D200`, `D212` |
| `'''` quotes | `D300`; the formatter step also failed (it rewrites to `"""`) |
| leading or trailing space inside the quotes | `D210`; the formatter step also failed |
| a backslash in a non-raw docstring | `D301`, with `W605` for the invalid escape |
| an empty docstring | `D419` |
| an `Args:` section missing a parameter | `D417` — ``Missing argument description in the docstring for `scale`: `b` `` |

Ruff's text for `D417`: "Note that this rule only checks docstrings with an arguments (e.g.
`Args`) section." Accordingly a multi-line docstring with no `Args:` section for a two-parameter
function passed both Ruff steps (*observed*). Google allows omitting the sections only "where the
function's name and signature are informative enough that it can be aptly described using a
one-line docstring" (`pyguide.md:2227-2229`), so review holds the rest: a function whose parameters
are not self-evident from name and signature documents each one.

**Sections** (`pyguide.md:2224-2268`, **held by review**):

- `Args:` lists each parameter by name, with `*foo` and `**bar` written that way
  (`pyguide.md:2233-2240`). A name that is not a parameter is a defect; an `Args:` section that
  listed a nonexistent `bogus` drew no Ruff report (*observed*).
- `Returns:` (or `Yields:` for a generator) describes the return value beyond what the annotation
  states, and may be omitted when the docstring opens with "Return"/"Returns" and that sentence
  suffices, or the function returns only `None` (`pyguide.md:2244-2259`). For a generator,
  `Yields:` documents what `next()` returns, not the generator object.
- `Raises:` lists "all exceptions that are relevant to the interface", but "not ... exceptions that
  get raised if the API specified in the docstring is violated" (`pyguide.md:2263-2268`). A function
  that raised a project exception with no `Raises:` section drew no report from any of the five
  gate commands (*observed*): the baseline selects no rule that compares the section with the code.
- A class docstring documents public attributes, excluding properties, in an `Attributes:` section
  (`pyguide.md:2428-2431`). A class with an undocumented public attribute drew no Ruff report
  (*observed*).
- A `@property` docstring reads like an attribute, `"""The Bigtable path."""`, not
  `"""Returns the Bigtable path."""` (`pyguide.md:2219-2222`).
- A class docstring's summary says what an instance represents, and an exception docstring says
  "what the exception represents, and not the context in which it might occur":
  `"""No more cheese is available."""`, not `"""Raised when no more cheese is available."""`
  (`pyguide.md:2461-2465`, `:2477-2492`).
- A decorated function or class documents "the function's behavior after the decorator has been
  applied" (`pyguide.md:2350-2352`, `:2495-2496`).
- A docstring describes calling syntax and semantics, "but generally not its implementation
  details, unless those details are relevant to how the function is to be used"; implementation
  detail goes in `#` comments beside the code (`pyguide.md:2207-2215`).

**Mood and length are not gated.** `PEP 257` says the summary "prescribes the function or method's
effect as a command ("Do this", "Return that")" (`pep-0257.rst:102-104`); Google allows
"descriptive-style" or "imperative-style" but "the style should be consistent within a file"
(`pyguide.md:2217-2219`). Ruff's `D401` (non-imperative mood) is "disabled when using the `google`
conventions" (`uvx ruff@0.17.3 rule D401`), and a summary beginning `Returns the value ...` drew no
Ruff report (*observed*). A summary line of 87 columns drew none either, across all five gate
commands: Google's 80 is not Ruff's default `E501` limit of 88 (*observed*; `E501 Line too long
(90 > 88)` on a longer line). So review holds consistency of mood within a file and the 80-column
summary.

## The leakage rule

Docstrings and `#` comments MUST explain code, behaviour, or external context. They MUST NOT name or
describe internal project artifacts. A docstring is not only source text: it becomes the object's
`__doc__` (`pep-0257.rst:46-48`), which `pydoc` extracts (`pyguide.md:2103-2106`), so a leaked
docstring is part of what a consumer of the object reads.

### Disallowed in source (docstrings and `#` comments alike)

- Paths or filenames under internal-only directories (out-of-band planning or tooling directories).
  Example: `# see .claudestacks/sdlc/x/plans/02.md` — **rejected**.
- Names of internal rules, rule-numbered exceptions, or shortcodes that only resolve inside the
  local project.
- Plan, spec, phase and task identifiers. Examples: `Added in Phase 3 Task 2`,
  `per the spec section 5`, `# TODO Phase 5` — **rejected**.
- Workflow vocabulary from the development process: `subagent`, `implementer`, `reviewer`,
  `the plan`, `the spec`, `the brainstorm`. Exception: where the word names a runtime concept the
  documented code actually interacts with, rather than a role in how the code was produced (a
  package that models subagent definitions documents them as such). Judge by whether removing the
  word would make the documentation less precise about the code's behaviour.
- AI, agent and model names: `Claude`, `Opus`, `Sonnet`, `the assistant`. Exception: when the
  package is itself about LLM APIs and the name appears as a literal model identifier in a public
  name, constant or documented value.
- Pull-request, issue and commit references (`see PR #12`). They belong in git history; line
  numbers and SHAs rot and the next reader has no tracker open.
- Narration of past or future work in this codebase: `added later`, `as discussed`, `previously
  called`, `we decided to`. The diff explains what changed; the comment explains what the code does.

### Allowed (and encouraged)

- What the code does, the invariants it relies on, the contract it offers callers.
- Constraints and trade-offs the reader cannot derive from the code: hidden coupling, performance
  characteristics, ordering requirements. "If you're going to have to explain it at the next code
  review, you should comment it now" (`pyguide.md:2507-2511`).
- References to publicly published standards and documentation: PEP numbers, RFCs, library
  documentation URLs, Google Python Style Guide section numbers.
- Tool directives that name a code (`# noqa: <CODE>`, `# type: ignore[<code>]`) with a reason
  comment that stands alone. The directive is fine; do not chase it with a path into an internal
  file. Blanket forms and the reason requirement are in `strict-quality.md`.
- `TODO: <what is missing>` states a gap in the code. A `TODO` naming a phase does not. No `TODO`
  rule is selected by the baseline: `# TODO Phase 5: ...` drew no report (*observed*).

### Where the rule bites

The forbidden zone is the project's shipped and published text: `src/`, `tests/`, `examples/`, the
file that `[project] readme` names, and `[project] description`. Commit
messages, pull-request descriptions, planning notes and project-rule files are where artifact
references belong.

**Held by review; the gate cannot see it.** Docstrings and comments naming a planning path, a phase
and task, "the plan", a model name, a subagent, and a pull-request number, in `src/` and in
`tests/`, passed all five gate commands with exit `0` (*observed*). Review therefore runs this
screen from the project root and reads each hit. `ls -d` hands `grep` only the paths that exist,
because a missing `README.md` operand made `grep` exit `2` even when it had printed hits:

```bash
grep -rnE '\.claudestacks|\.airsstack|docs/(specs|plans)|(Phase|Task|Step) [0-9]|subagent|implementer|brainstorm|the (plan|spec)\b|(Claude|Opus|Sonnet|Haiku)|(PR|issue) #[0-9]+' \
  --include='*.py' --include='*.pyi' --include='*.toml' --include='README.md' \
  $(ls -d src tests pyproject.toml README.md 2>/dev/null)
```

On the copy with the leaks it printed eight lines across `src/` and `tests/` and exited `0`; on the
clean baseline it printed nothing and exited `1`. With `tests/` and `README.md` both absent it
printed the four lines of a leaky `src/` module and exited `0`, and on a clean `src/` it exited `1`
(*observed*, BSD grep 2.6.0-FreeBSD). The screen is a net, not a verdict: a `subagent` or `Claude` hit is judged against the exceptions above, and a
leak in words it does not list gets past it.

## The accuracy rule

**Comments describe the code. The code is the authority.**

A docstring or comment that describes behaviour is a claim about the code beside it. Where the two
disagree, the code is what runs and the docstring is what is wrong, with one exception below.

1. **When reading or comparing code, check the docstring against the code.** A divergence is a
   finding. Never take a docstring's word for what the code does. A function whose docstring said
   "Return twice the value" and whose body returned `value * 3`, with a `# Multiply by two.` comment
   above the line, drew no report from any of the five gate commands (*observed*).
2. **The default repair is the docstring, never the code.** Rewriting working code to match a stale
   sentence turns a correct implementation into a defect.
3. **The exception is a sentence stating an invariant the code is meant to uphold.** "Callers must
   hold the lock", "must be called once", "the list is never empty". If the code breaks one, that is
   a bug in the code; rewriting the invariant to match the breach launders the defect. Tell them
   apart by asking whether the sentence describes what the code *does* or what it *must guarantee*.
4. **A claim is verified when it is written.** Error text and rule codes, exit statuses, quoted
   command output, counts, version numbers, `file:line` citations, and any "does not exist"
   assertion. If it was not checked in the same change, it does not go in.
5. **Prefer a claim that runs.** An `Examples:` section is collected by `--doctest-modules` (the
   baseline's `addopts` and `testpaths = ["tests", "src"]`), and a doctest expecting `5` from
   `double(2)` failed the `pytest` step (*observed*, `strict-quality.md`). Prose claims get no such
   check, so put a claim about a return value in a doctest.
6. **Name a symbol, never a line.** "`parse_header` raises `HeaderError` on a missing colon"
   survives a refactor; "see `parser.py:164`" is wrong once a line moves. A `file:line` citation
   belongs in the commit message or review finding, which is pinned to the tree it describes.
7. **Re-resolve every symbol a docstring names after the edit.** A docstring naming `old_double`,
   which no longer exists, and `:func:` naming `base.core.missing_helper`, which never did, drew no
   report from any of the five gate commands (*observed*): the names exist only in prose. After a
   rename or delete, run `grep -rn '<old name>' src tests README.md` before finishing.
8. **Commented-out code is deleted.** `ERA001` fails the `ruff check --no-fix` step on
   `# result = value * 2` (*observed*): it is a stale claim about what the code does.
9. **Comments never narrate the code.** "[N]ever describe the code. Assume the person reading the
   code knows Python (though not what you're trying to do) better than you do"
   (`pyguide.md:2528-2536`). A comment says why.
10. **Budget the prose.** A comment explains the code. Reasoning, alternatives considered and history
    belong in the commit message, where a wrong sentence is cheap to correct. A comment block longer
    than the code it explains is a signal to move most of it.

All ten are **held by review** except 5's doctest half and 8, which the gate enforces.

## How to translate a leaky or wrong comment

| Leaky or wrong | Clean |
|---|---|
| `# Per .claudestacks/.../plans/02.md, keep this a list.` | `# Order matters: callers index by position.` |
| `"""Added in Phase 3 Task 2, as the plan describes."""` | *(delete; the function either exists or does not)* |
| `# TODO Phase 5: support floats.` | `# TODO: floats are unsupported.` |
| `# Decided in the implementer session to keep this unbounded.` | `# The server enforces the bound; a client-side cap would age badly.` |
| `# See PR #12 for why.` | `# Retries are idempotent because the key is derived from the payload.` |
| `# Multiply by two.` above `value * 3` | *(delete; it narrates the code, and wrongly)* |
| `"""Returns the same as old_double."""` after a rename | *(delete the clause, or name the current symbol and grep for it)* |
| `"""Raised when no more cheese is available."""` | `"""No more cheese is available."""` |

The pattern: replace "where the decision came from" with "what the decision *is* and why it makes
engineering sense", and replace anything remembered with something run.

## What the gate sees and what review holds

| Rule | Held by |
|---|---|
| a docstring on every public module, class, function, method, package and `__init__` | gate: `D100`–`D107` |
| `"""` quoting, summary punctuation and layout, empty docstring, raw docstring for backslashes | gate: `D300`, `D415`, `D205`, `D212`, `D200`, `D210`, `D419`, `D301`; formatter |
| every parameter described when an `Args:` section exists | gate: `D417` |
| an `Args:` section present where parameters are not self-evident | review |
| no nonexistent parameter in `Args:`; `Returns:`, `Yields:`, `Raises:`, `Attributes:` complete | review |
| summary within 80 columns; consistent mood within a file | review |
| docstring on an `@override` method that materially refines the base contract | review |
| doctest examples are true | gate: `pytest` with `--doctest-modules` |
| prose is true of the code; named symbols still resolve | review |
| commented-out code removed | gate: `ERA001` |
| no planning paths, plan identifiers, workflow vocabulary, AI names, PR references | review |

## Things to AVOID

- A docstring or comment that names a planning file, a plan, spec, phase or task, a subagent, a
  model, or a pull request, in `src/`, `tests/`, the shipped README or `pyproject.toml`.
- A `# noqa` or `# type: ignore` reason that points at an internal file instead of standing alone.
- Docstring text that reads like a journal entry ("Originally we wanted X but pivoted to Y").
  Describe the current design.
- Writing an error message, rule code, exit status or command output from memory. Run it in this
  change and paste what it printed.
- Numbers an ordinary edit invalidates: how many modules a package holds, how many members an
  enum has. State the invariant that makes the number what it is, or drop the number.
- Line-number citations into source. Name the function, class or module.
- Naming a test, field or function in prose without re-resolving the symbol after the change that
  touched it.
- Stating what a branch or `except` clause covers without reading the whole clause.
- Rewriting a "callers must hold the lock" sentence, or any guarantee, so it agrees with code that
  breaks it.
- A trivial docstring on an `@override` method, or a docstring that repeats the function name.
- Using `__all__` or a leading underscore to skip a docstring on a name callers use.
- Suppressing a `D` code to pass the gate instead of writing the docstring. A suppression names its
  code and carries a reason (`strict-quality.md`).

## Reviewer checklist

Reject the change if:

- A public module, class, function, method, package or `__init__` has no docstring (the gate
  catches the unsuppressed case; review catches a `# noqa: D1xx`).
- The leakage screen above matches in `src/`, `tests/`, the shipped README or `pyproject.toml` and
  the hit is not one of the named exceptions.
- A docstring or comment disagrees with the code beside it and the change left the comment alone —
  or "fixed" the code to match a comment that was not an invariant.
- A docstring names a symbol that no longer resolves, or a parameter the function does not take.
- `Raises:`, `Returns:`, `Yields:` or `Attributes:` omits something the interface does, or lists an
  exception raised only when the documented API is violated.
- A quoted error text, rule code, exit status, count or version was not produced in this change.
- A line-number citation sits in source instead of a symbol.
- An `@override` method that changes the base contract has no docstring stating the difference.
- Mood differs within a file, or a summary line exceeds 80 columns.
- Commented-out code survives (the gate catches it; review catches a `# noqa: ERA001`).

## Why

- **The docstring is the package's contract.** It is the object's `__doc__`, which `pydoc` extracts.
  A consumer cannot follow an internal path in that output; at best it is noise.
- **Internal artifacts churn.** Plans are superseded and phases re-ordered. Source that names them
  goes stale silently, and the diff cannot show that twenty docstrings now point at a moved file.
- **A wrong comment is more dangerous than none.** A missing explanation sends the reader to the
  code; a confident wrong one stops them. A quoted rule code reads as authority, so it is trusted
  where trust is unearned.
- **Mixing process with product is a smell.** The reader of a module is trying to use it, not to
  learn how the team coordinates work.
- **Generated code leaks workflow vocabulary by habit** ("as the plan describes", "Phase 3 Task 2
  below"). That it comes naturally is the reason the rule must be explicit, and the same habit
  produces plausible error codes and citations that were never run.
