# claudestacks-cmux

Lets Claude Code drive the [cmux](https://cmux.com) terminal. It is four skills (`cmux-control`,
`cmux-workspace`, `cmux-browser` and `cmux-config`), each a guide over the real `cmux` command line
with a small helper script.

## Install

You need cmux on your machine; the skills run the `cmux` binary and do not include it. The helper
scripts run on `airsl`, so install that first:

```sh
curl -LsSf https://airsstack.github.io/airsl/install.sh | sh
```

Then, in Claude Code:

```text
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-cmux@claudestacks
```

## Documentation

What each skill covers and how cmux is laid out are described in
[the claudestacks-cmux chapter](https://airsstack.github.io/claudestacks/ch15-00-cmux-plugin.html)
of the book.

## License

Apache-2.0. See [LICENSE](./LICENSE).
