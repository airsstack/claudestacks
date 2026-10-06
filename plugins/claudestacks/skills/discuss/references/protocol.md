# Communication Protocol

How the main thread, and the agents it briefs under `/claudestacks:discuss`, talk to the
author. It sits on top of the Context Handoff protocol and changes nothing in it.

**It inherits.** Every rule in the `claudestacks` plugin's
`skills/context-handoff/references/protocol.md` applies unchanged: report paths, tiers, the
session lifecycle, the `<summary>`/`<detail>` file schema, the return contract, error
handling, and its validator. This file only adds. If the two ever seem to disagree, Context
Handoff wins and this file has a defect.

## Reply rules

1. Reduce agent verbosity output.
2. Do not over-explain everything; only explain what matters.
3. Use ASCII visualizations to replace long narratives or text.
4. Be concise but precise; only tell what matters and is important.

Applied as:

- The outcome comes first.
- Anything that would run past a short paragraph becomes an ASCII diagram, table or tree.
- While a discussion is open, a reply ends with its topic list.

## Brief

A `/claudestacks:discuss` brief carries the two Context Handoff fields plus one:

```
handoff: <write-path>
handoff-protocol: <context-handoff protocol path>
comm-protocol: <this file's path>
```

## Report additions

A report written under this protocol is a valid Context Handoff report with three additions:

```
---
agent: reviewer
task: …
protocol: discuss/1            ← required
---
<summary>
at most 6 non-empty lines, outcome first
</summary>
<topics>
1. <title>
2. <title>
</topics>
<detail>
## 1. <title>                  ← one heading per topic, same number and title
…
## 2. <title>
…
</detail>
```

A report with no `<detail>` carries no `<topics>`.

## Return contract

The agent returns its `<summary>`, its `<topics>` lines verbatim, and the report path. It does
not return `<detail>`.

## Main-thread reports

During an open discussion, a main-thread answer that would exceed about 15 lines is written as
a report under this protocol with `agent: main`, at the path
`scripts/discuss.lua report-path <slug>` prints, then added with `scripts/discuss.lua add`.

## What enforces this

`scripts/lib/comm_report.lua` checks the additions. The plugin's hooks run it on the same three
events as the Context Handoff validator, and it acts only on a report carrying `protocol:`, so
reports from every other agent are untouched. `scripts/discuss.lua add` runs it too, with
`protocol:` required.

| id | fails when |
|---|---|
| `protocol-unknown` | `protocol:` is not `discuss/1` |
| `summary-too-long` | more than 6 non-empty lines inside `<summary>` |
| `topics-missing` | `<detail>` present and no `<topics>` pair |
| `topics-malformed` | a non-blank line inside `<topics>` is not `N. <title>` |
| `topics-numbering` | topic numbers are not `1..n` in order |
| `topic-heading-missing` | no line `## N. <title>` inside `<detail>` for topic `N` |
| `topics-without-detail` | `<topics>` present and no `<detail>` pair |
| `protocol-missing` | no `protocol:` key — raised only by `discuss.lua add` |
