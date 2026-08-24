# Review policy

`REVIEW.md` is the consuming repository's own review policy, living at
`.claudestacks/sdlc/REVIEW.md`. It says what a review of a diff in that repository
looks at, in what order, and what counts as blocking.

It is provisioned once by `/claudestacks-sdlc:setup`, which creates it only when it is
absent — an existing `REVIEW.md` is never overwritten. From that point the file belongs
to the repository, not to this plugin: tune it as the project learns what its reviews
keep missing, and record each change in the Tuning log so the policy's own history is
readable.

The template follows. `setup` writes the body of this fenced block, without the fence.

```markdown
# REVIEW.md — review policy

<!-- Provisioned by claudestacks-sdlc. Versioned: edit deliberately, log changes
     in the Tuning log. Reviewer-agent consumption of this file is a separate
     future chain; until then this policy is documentation you can point any
     reviewer at, including pasting it into a review prompt by hand. -->

## Passes, in order

1. **Bugs and logic errors** — correctness of the diff on its own terms.
2. **Security** — injection, secrets in the diff, unsafe input handling,
   privilege and network boundaries.
3. **Compliance** — the diff against the chain's spec and plan: scope drift,
   silent carry-over, missing or unauthorized requirements.

## Severity

- **Important** — must be addressed before commit.
- **Nit** — batch or ignore; never blocks.

## Exclusions

- Generated paths.
- Anything CI already enforces deterministically.

## Tuning log

<!-- Dated entries when this policy changes. Newest first. -->
```
