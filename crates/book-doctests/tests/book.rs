//! Link checks over the real repository: the book's pages, every README and every skill.

#![expect(clippy::unwrap_used, reason = "tests unwrap known-valid paths")]

use std::fs;
use std::path::{Path, PathBuf};

use book_doctests::links::{Finding, orphan_pages, scan_page};

const SITE_URL: &str = "https://airsstack.github.io/claudestacks/";

/// The one sentence of a stub, followed by its link.
const STUB_SENTENCE: &str = "This content is in the claudestacks book:";

/// The crates whose `docs/` trees hold the stubs.
const STUB_CRATES: [&str; 2] = ["airsclaude", "claudevs"];

/// Every stub, with the page it points to. READMEs already on crates.io link to
/// these paths, so a stub stays even though the book holds its content.
const STUBS: [(&str, &str); 20] = [
    (
        "crates/airsclaude/docs/README.md",
        "ch01-00-airsclaude-getting-started",
    ),
    (
        "crates/airsclaude/docs/architecture.md",
        "ch04-01-three-pillars",
    ),
    (
        "crates/airsclaude/docs/divergences.md",
        "appendix-04-divergences",
    ),
    (
        "crates/airsclaude/docs/messages-sdk/tutorial.md",
        "ch02-01-first-call",
    ),
    (
        "crates/airsclaude/docs/messages-sdk/how-to.md",
        "ch02-00-messages-api",
    ),
    (
        "crates/airsclaude/docs/messages-sdk/explanation.md",
        "ch04-02-messages-design",
    ),
    (
        "crates/airsclaude/docs/messages-sdk/feature-parity.md",
        "appendix-02-messages-parity",
    ),
    (
        "crates/airsclaude/docs/agent-sdk/tutorial.md",
        "ch03-01-first-session",
    ),
    (
        "crates/airsclaude/docs/agent-sdk/how-to.md",
        "ch03-00-agent-sdk",
    ),
    (
        "crates/airsclaude/docs/agent-sdk/explanation.md",
        "ch04-03-agent-layers",
    ),
    (
        "crates/airsclaude/docs/agent-sdk/feature-parity.md",
        "appendix-03-agent-parity",
    ),
    (
        "crates/claudevs/docs/README.md",
        "ch05-00-claudevs-getting-started",
    ),
    ("crates/claudevs/docs/architecture.md", "ch09-02-engine"),
    (
        "crates/claudevs/docs/cli/tutorial.md",
        "ch05-01-installation",
    ),
    (
        "crates/claudevs/docs/cli/how-to.md",
        "ch06-00-writing-cases",
    ),
    (
        "crates/claudevs/docs/cli/reference.md",
        "appendix-01-claudevs-cli",
    ),
    ("crates/claudevs/docs/cli/explanation.md", "ch09-01-design"),
    (
        "crates/claudevs/docs/engine/tutorial.md",
        "ch08-01-first-suite",
    ),
    ("crates/claudevs/docs/engine/how-to.md", "ch08-02-recipes"),
    (
        "crates/claudevs/docs/engine/explanation.md",
        "ch09-02-engine",
    ),
];

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .unwrap()
}

fn book_src() -> PathBuf {
    repo_root().join("book/src")
}

/// Every `*.md` file directly inside `dir`, sorted.
fn markdown_files(dir: &Path) -> Vec<PathBuf> {
    let mut files: Vec<PathBuf> = fs::read_dir(dir)
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "md"))
        .collect();
    files.sort();
    files
}

/// `<dir>/<member>/<name>` for every member directory that has one, sorted.
fn member_files(dir: &Path, name: &str) -> Vec<PathBuf> {
    let mut files: Vec<PathBuf> = fs::read_dir(dir)
        .unwrap()
        .map(|entry| entry.unwrap().path().join(name))
        .filter(|path| path.is_file())
        .collect();
    files.sort();
    files
}

/// Adds every file under `dir`, at any depth, to `files`.
fn collect_files(dir: &Path, files: &mut Vec<PathBuf>) {
    for entry in fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            collect_files(&path, files);
        } else {
            files.push(path);
        }
    }
}

fn report(findings: &[Finding]) -> String {
    findings
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join("\n")
}

#[test]
fn book_links_resolve() {
    let src = book_src();
    let pages = markdown_files(&src);
    assert!(!pages.is_empty(), "no pages found under {}", src.display());
    let findings: Vec<Finding> = pages
        .iter()
        .flat_map(|page| scan_page(page, &src, &src, SITE_URL))
        .collect();
    assert!(findings.is_empty(), "\n{}", report(&findings));
}

#[test]
fn every_page_is_named_in_summary() {
    let findings = orphan_pages(&book_src());
    assert!(findings.is_empty(), "\n{}", report(&findings));
}

#[test]
fn readme_links_resolve() {
    let root = repo_root();
    let src = book_src();
    let mut readmes = vec![root.join("README.md")];
    readmes.extend(member_files(&root.join("crates"), "README.md"));
    readmes.extend(member_files(&root.join("plugins"), "README.md"));
    let findings: Vec<Finding> = readmes
        .iter()
        .flat_map(|readme| {
            let base = readme.parent().unwrap();
            scan_page(readme, base, &src, SITE_URL)
        })
        .collect();
    assert!(findings.is_empty(), "\n{}", report(&findings));
}

#[test]
fn every_stub_exists_and_links_into_the_book() {
    let root = repo_root();
    let src = book_src();
    let mut problems = Vec::new();
    for (path, page) in STUBS {
        let stub = root.join(path);
        let findings = scan_page(&stub, stub.parent().unwrap(), &src, SITE_URL);
        if !findings.is_empty() {
            problems.push(report(&findings));
            continue;
        }
        let text = fs::read_to_string(&stub).unwrap();
        let heading = text
            .lines()
            .next()
            .filter(|line| line.starts_with("# "))
            .unwrap_or("# <heading>");
        let expected = format!("{heading}\n\n{STUB_SENTENCE} <{SITE_URL}{page}.html>\n");
        if text != expected {
            problems.push(format!("{path}: must read exactly:\n{expected}"));
        }
    }
    assert!(problems.is_empty(), "\n{}", problems.join("\n"));
}

#[test]
fn the_docs_trees_hold_only_the_stubs() {
    let root = repo_root();
    let mut found = Vec::new();
    for name in STUB_CRATES {
        collect_files(&root.join("crates").join(name).join("docs"), &mut found);
    }
    let mut found: Vec<String> = found
        .iter()
        .map(|file| {
            file.strip_prefix(&root)
                .unwrap()
                .to_string_lossy()
                .into_owned()
        })
        .collect();
    found.sort();
    let mut expected: Vec<String> = STUBS.iter().map(|(path, _)| (*path).to_owned()).collect();
    expected.sort();
    assert_eq!(found, expected);
}

#[test]
fn stubs_stay_out_of_the_tarballs() {
    let root = repo_root();
    for name in STUB_CRATES {
        let manifest = root.join("crates").join(name).join("Cargo.toml");
        let text = fs::read_to_string(&manifest).unwrap();
        let excluded = text
            .lines()
            .any(|line| line.starts_with("exclude") && line.contains("\"docs/\""));
        assert!(
            excluded,
            "{} does not exclude \"docs/\"",
            manifest.display()
        );
    }
}

#[test]
fn skill_links_resolve() {
    let root = repo_root();
    let src = book_src();
    let skills: Vec<PathBuf> = fs::read_dir(root.join("plugins"))
        .unwrap()
        .map(|plugin| plugin.unwrap().path().join("skills"))
        .filter(|dir| dir.is_dir())
        .flat_map(|dir| member_files(&dir, "SKILL.md"))
        .collect();
    assert!(!skills.is_empty(), "no skills found under plugins/");
    let findings: Vec<Finding> = skills
        .iter()
        .flat_map(|skill| {
            let base = skill.parent().unwrap();
            scan_page(skill, base, &src, SITE_URL)
        })
        .collect();
    assert!(findings.is_empty(), "\n{}", report(&findings));
}
