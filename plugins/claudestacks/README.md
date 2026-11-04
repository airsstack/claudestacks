# claudestacks

The core plugin of the claudestacks suite for Claude Code. It gives Claude three agents (`coder`,
`reviewer`, `explorer`) and an `orchestrate` skill that runs them in order, so a task is coded,
checked and reviewed before it reaches you. It also holds the suite's hooks: reply rules, project
snapshots and the dispatcher that points Claude at the right guideline.

## Install

Its hooks run on `airsl` and exit silently when it is missing, so install that first:

```sh
curl -LsSf https://airsstack.github.io/airsl/install.sh | sh
```

Then, in Claude Code:

```text
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks@claudestacks
```

Every skill is namespaced `claudestacks:`, so `discuss` runs as `/claudestacks:discuss`.

## Documentation

The agents, skills, hooks, options, snapshots and the enforcement dispatcher are described in
[the claudestacks chapter](https://airsstack.github.io/claudestacks/ch11-00-claudestacks-plugin.html)
of the book.

## Attribution

The reply rules in the `discuss` skill's communication protocol replace an earlier terseness
mode that was inspired by the [caveman](https://github.com/juliusbrussee/caveman) plugin.
That earlier mode kept its state in `~/.airsstack/cc/concise.json`. Nothing reads that file any
more; it can be deleted.

## License

Apache-2.0. See [LICENSE](./LICENSE).
