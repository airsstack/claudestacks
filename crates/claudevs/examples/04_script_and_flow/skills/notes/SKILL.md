---
name: notes
description: Greet the user and keep short notes in the current repository.
---

# Notes

1. Greet the user by name. The script reads the name from `GREETING_NAME`:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/greet.sh"
   ```

2. Create a note in the current git repository:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/new-note.sh" "note title"
   ```
