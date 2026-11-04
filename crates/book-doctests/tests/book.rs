//! Link checks over the real repository: the book's pages, every README and every skill.

#![expect(clippy::unwrap_used, reason = "tests unwrap known-valid paths")]

use std::fs;
use std::path::{Path, PathBuf};

use book_doctests::links::{Finding, orphan_pages, scan_page};

const SITE_URL: &str = "https://airsstack.github.io/claudestacks/";

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
