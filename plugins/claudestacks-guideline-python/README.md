# claudestacks-guideline-python

Python engineering rules and a Definition of Done for Claude Code, in one skill:
`claudestacks-guideline-python:python-guidelines`. The skill loads when Claude reads or edits a `.py` or
`.pyi` file or `pyproject.toml` in a project with a `pyproject.toml`, and the `coder` and `reviewer`
agents of the `claudestacks` plugin run its Definition of Done. The plugin has no hooks and no
scripts.

## Install

```text
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-guideline-python@claudestacks
```

Install `claudestacks` as well: its dispatcher is what points Claude at this skill, and its agents are
what run the Definition of Done. On its own the skill still loads on request.

## Documentation

The rules and how the plugin fits with the others are described in
[the guidelines chapter](https://airsstack.github.io/claudestacks/ch13-00-guideline-plugins.html)
of the book.

## License

Apache-2.0. See [LICENSE](./LICENSE).
