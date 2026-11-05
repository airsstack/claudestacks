# Appendix

The appendix holds the reference material that sits behind the chapters.

- [A. claudevs CLI Reference](appendix-01-claudevs-cli.md) lists every `claudevs` command and flag.
- [B. Messages API Parity](appendix-02-messages-parity.md) records, feature by feature, what the
  `airsclaude` Messages API matches in Anthropic's official SDKs and what it does not.
- [C. Agent SDK Parity](appendix-03-agent-parity.md) does the same for the Agent SDK.
- [D. Deliberate Divergences](appendix-04-divergences.md) lists the places where `airsclaude` behaves
  differently on purpose, with the reasoning.

Appendices B, C and D are records you check claims against. Each row says where the behaviour lives in
the `airsclaude` source and where it comes from in the official Python and TypeScript SDKs, as a file
name and a line number such as `models/capabilities.rs`. You can open that line and see for yourself
whether a row is true. The citations are plain text, not links, because they point into the source
of the SDKs and not at pages of this book.

The chapters do not carry citations. They teach you how to use the software, and a line number would
only get in the way of reading. When you want proof for a claim a chapter makes, look it up in B, C or D.
