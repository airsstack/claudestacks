//! One doctest-only item per book page, and one per crate README with Rust in it.
//! `SUMMARY.md` is the table of contents and carries no snippets, so it is the one
//! page not wired here.

#[cfg(doctest)]
#[doc = include_str!("../../airsclaude/README.md")]
struct ReadmeAirsclaude;

#[cfg(doctest)]
#[doc = include_str!("../../claudevs/README.md")]
struct ReadmeClaudevs;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/appendix-00.md")]
struct Appendix00;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/appendix-01-claudevs-cli.md")]
struct Appendix01ClaudevsCli;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/appendix-02-messages-parity.md")]
struct Appendix02MessagesParity;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/appendix-03-agent-parity.md")]
struct Appendix03AgentParity;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/appendix-04-divergences.md")]
struct Appendix04Divergences;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch01-00-airsclaude-getting-started.md")]
struct Ch0100AirsclaudeGettingStarted;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-00-messages-api.md")]
struct Ch0200MessagesApi;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-01-first-call.md")]
struct Ch0201FirstCall;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-02-streaming.md")]
struct Ch0202Streaming;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-03-tools.md")]
struct Ch0203Tools;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-04-cost-and-latency.md")]
struct Ch0204CostAndLatency;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-05-richer-input.md")]
struct Ch0205RicherInput;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-06-structured-results.md")]
struct Ch0206StructuredResults;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-07-models.md")]
struct Ch0207Models;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch02-08-building-larger.md")]
struct Ch0208BuildingLarger;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-00-agent-sdk.md")]
struct Ch0300AgentSdk;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-01-first-session.md")]
struct Ch0301FirstSession;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-02-conversations.md")]
struct Ch0302Conversations;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-03-controlling-the-agent.md")]
struct Ch0303ControllingTheAgent;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-04-your-code-in-the-loop.md")]
struct Ch0304YourCodeInTheLoop;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-05-sessions.md")]
struct Ch0305Sessions;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch03-06-interactive.md")]
struct Ch0306Interactive;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch04-00-airsclaude-under-the-hood.md")]
struct Ch0400AirsclaudeUnderTheHood;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch04-01-three-pillars.md")]
struct Ch0401ThreePillars;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch04-02-messages-design.md")]
struct Ch0402MessagesDesign;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch04-03-agent-layers.md")]
struct Ch0403AgentLayers;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch05-00-claudevs-getting-started.md")]
struct Ch0500ClaudevsGettingStarted;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch05-01-installation.md")]
struct Ch0501Installation;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch05-02-first-plugin.md")]
struct Ch0502FirstPlugin;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch05-03-first-case.md")]
struct Ch0503FirstCase;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch05-04-running-the-gate.md")]
struct Ch0504RunningTheGate;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-00-writing-cases.md")]
struct Ch0600WritingCases;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-01-hook-decisions.md")]
struct Ch0601HookDecisions;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-02-scripts-and-flows.md")]
struct Ch0602ScriptsAndFlows;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-03-cases-in-lua.md")]
struct Ch0603CasesInLua;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-04-native-suites.md")]
struct Ch0604NativeSuites;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch06-05-selecting-and-skips.md")]
struct Ch0605SelectingAndSkips;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch07-00-check-gate.md")]
struct Ch0700CheckGate;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch07-01-stages.md")]
struct Ch0701Stages;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch07-02-wiring.md")]
struct Ch0702Wiring;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch07-03-ci.md")]
struct Ch0703Ci;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch08-00-embedding.md")]
struct Ch0800Embedding;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch08-01-first-suite.md")]
struct Ch0801FirstSuite;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch08-02-recipes.md")]
struct Ch0802Recipes;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch09-00-claudevs-under-the-hood.md")]
struct Ch0900ClaudevsUnderTheHood;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch09-01-design.md")]
struct Ch0901Design;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch09-02-engine.md")]
struct Ch0902Engine;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch10-00-plugins-getting-started.md")]
struct Ch1000PluginsGettingStarted;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch11-00-claudestacks-plugin.md")]
struct Ch1100ClaudestacksPlugin;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch12-00-sdlc-plugin.md")]
struct Ch1200SdlcPlugin;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch13-00-guideline-plugins.md")]
struct Ch1300GuidelinePlugins;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch14-00-journal-plugin.md")]
struct Ch1400JournalPlugin;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/ch15-00-cmux-plugin.md")]
struct Ch1500CmuxPlugin;

#[cfg(doctest)]
#[doc = include_str!("../../../book/src/introduction.md")]
struct Introduction;

#[cfg(test)]
mod tests {
    #![expect(
        clippy::unwrap_used,
        reason = "tests unwrap a directory the repository ships"
    )]

    #[test]
    fn every_page_is_compiled_as_a_doctest() {
        let source = include_str!("pages.rs");
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../book/src");
        let mut pages: Vec<String> = std::fs::read_dir(dir)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .filter(|name| {
                std::path::Path::new(name)
                    .extension()
                    .is_some_and(|ext| ext == "md")
            })
            .filter(|name| name != "SUMMARY.md")
            .collect();
        pages.sort();
        assert!(!pages.is_empty(), "book/src holds no markdown");
        for name in pages {
            let wired = format!("include_str!(\"../../../book/src/{name}\")");
            assert!(
                source.contains(&wired),
                "book/src/{name} is not compiled as a doctest"
            );
        }
    }
}
