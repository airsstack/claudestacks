-- Data cases generated from a table, then scripted cases that drive the
-- harness through `t`.
local cases = {}

for name, command in pairs({
  long_flag = "git push --force origin main",
  short_flag = "git push -f origin main",
}) do
  cases["blocks_force_push_" .. name] = {
    event = "PreToolUse",
    payload = { tool_name = "Bash", tool_input = { command = command } },
    expect = { decision = "deny", stderr_contains = "force pushes are not allowed" },
  }
end

cases.plain_push_emits_nothing = function(t)
  local reply = t.hook("PreToolUse", {
    tool_name = "Bash",
    tool_input = { command = "git push origin main" },
  })
  assert(reply.exit == 0, "expected exit 0, got " .. tostring(reply.exit))
  assert(not reply.emitted, "a plain push should emit nothing")
end

cases.release_skill_prints_the_manifest_version = function(t)
  local command = t.skill_command("release", 1)
  local run = t.script({ "sh", "-c", command })
  assert(run.exit == 0, "release command failed: " .. run.stderr)

  local root = t.script({ "sh", "-c", 'printf %s "$CLAUDE_PLUGIN_ROOT"' }).stdout
  local manifest = t.json(root .. "/.claude-plugin/plugin.json")
  local printed = run.stdout:gsub("%s+$", "")
  assert(printed == manifest.version, "printed " .. printed .. ", manifest says " .. manifest.version)
end

return cases
