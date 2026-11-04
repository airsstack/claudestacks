# claudestacks-sdlc

An AI-native software development lifecycle for Claude Code. A change goes from intent to design
to plan to execute, each step leaves its result in a committed Markdown file, and a status board
reads those files and tells you which step is next. It follows Anthropic's
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) at the scale of one
author. Roadmaps, milestones and architecture decision records are optional layers above the chains.

## Install

```text
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-sdlc@claudestacks
```

Skills are namespaced `claudestacks-sdlc:`, so `design` runs as `/claudestacks-sdlc:design`. The
plugin works without `airsl`, but its status board and session-start summary come from it. Some
steps use the agents from the `claudestacks` plugin, so install that too.

The marketplace does not carry an older plugin named `claudestacks-sdd`. If you still have it installed,
remove it with `/plugin uninstall claudestacks-sdd@claudestacks`.

## Documentation

The flow, every skill, the agents and the artifact layout are described in
[the claudestacks-sdlc chapter](https://airsstack.github.io/claudestacks/ch12-00-sdlc-plugin.html)
of the book.

## Attribution

Stage model, artifact shapes and feedback loops follow Anthropic's
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook). The
execution discipline descends from `claudestacks-sdd`, adapted from
[superpowers](https://github.com/obra/superpowers).

## License

Apache-2.0. See [LICENSE](./LICENSE).
