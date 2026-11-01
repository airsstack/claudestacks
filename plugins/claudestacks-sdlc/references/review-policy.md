# Review policy

`REVIEW.md` is the consuming repository's review policy, at `.claudestacks/sdlc/REVIEW.md`:
what a review of a diff looks at, in what order, and what blocks.

`/claudestacks-sdlc:setup` creates it only when absent; an existing file is never
overwritten. After that it belongs to the repository: tune it and record each change in the
Tuning log.

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

## What closes a review

Every review names its Important set — a count, or `none`. A round closes when that
set is empty: each Important either fixed or explicitly declined in front of the
author. A non-empty report under `none` Important is a pass and never on its own
justifies another round. Everything found is still reported at both severities.

## Exclusions

- Generated paths.
- Anything CI already enforces deterministically.

## Tuning log

<!-- Dated entries when this policy changes. Newest first. -->
```
