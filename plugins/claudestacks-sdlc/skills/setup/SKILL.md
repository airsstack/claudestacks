---
name: setup
description: Provision the committed .claudestacks/sdlc/ chain root (prds/, rfcs/, REVIEW.md). Idempotent, never overwrites. Use when the user says "/claudestacks-sdlc:setup" or asks to set up the SDLC chain in this repository.
disable-model-invocation: true
---

Provision the claudestacks-sdlc artifact chain in the current repository.
Every step is idempotent: create only what is missing, never overwrite
anything that exists, and report each item as "created" or "already present".

1. Create the directories `.claudestacks/sdlc/prds/` and
   `.claudestacks/sdlc/rfcs/` if missing.
2. In each of the two, create an empty `.gitkeep` file if the directory has
   no committed content (committed-empty directories need the keep file).
3. If `.claudestacks/sdlc/REVIEW.md` does not exist, create it from the
   template in the fenced block of
   `${CLAUDE_PLUGIN_ROOT}/references/review-policy.md` (the template body
   only, without the fence). If it exists, leave it untouched and report
   "already present".
4. Do NOT write or modify any `.gitignore` — everything under
   `.claudestacks/` is meant for git.
5. Report what was created versus found, then stop. Committing is the
   user's call.
