# Under the Hood

The earlier chapters show how to use `airsclaude`. This one explains why it is built the way it is.
You do not need any of it to write a program. It helps when a type looks odd, when you want to know
what a call costs, or when you are deciding how to structure your own code around the crate.

| Page | What it explains |
|---|---|
| [Three Pillars](ch04-01-three-pillars.md) | What the crate bundles, and the few places the parts touch |
| [How the Messages Client Is Built](ch04-02-messages-design.md) | Why the HTTP client is generic, type-state and lossless |
| [How the Agent SDK Is Built](ch04-03-agent-layers.md) | Why the subprocess client is four layers, and how your code runs inside it |

The pages describe the design. Three appendices hold the detailed records they point to:

- [Appendix B](appendix-02-messages-parity.md) lists what the Messages client covers against the
  official SDKs.
- [Appendix C](appendix-03-agent-parity.md) does the same for the Agent SDK.
- [Appendix D](appendix-04-divergences.md) records the places where `airsclaude` deliberately differs
  from the official SDKs, and why.
