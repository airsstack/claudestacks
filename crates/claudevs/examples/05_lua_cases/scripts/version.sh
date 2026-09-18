#!/bin/sh
# Prints the version field of this plugin's manifest.
sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"
