//! Link rules for the book's Markdown pages.
//!
//! A page is parsed as `CommonMark`, so a link is whatever the parser reads as
//! one: links in code (fenced, indented or inline), in HTML comments and in
//! other non-link text are ignored, and a link whose destination wraps onto
//! another line is still seen. Anchor-only links and URLs that point outside
//! the book are skipped. Every other link must resolve to something that exists.

use std::collections::HashSet;
use std::fmt;
use std::fs;
use std::io;
use std::path::{Component, Path, PathBuf};

use pulldown_cmark::{Event, LinkType, Options, Parser, Tag};

/// The Markdown extensions the book is rendered with.
const OPTIONS: Options = Options::ENABLE_TABLES
    .union(Options::ENABLE_FOOTNOTES)
    .union(Options::ENABLE_STRIKETHROUGH)
    .union(Options::ENABLE_TASKLISTS)
    .union(Options::ENABLE_HEADING_ATTRIBUTES);

/// One broken link, forbidden construct, or unreadable input.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    /// The file the finding belongs to.
    pub file: PathBuf,
    /// The 1-based line number, or `0` when the finding is about the whole file.
    pub line: usize,
    /// The link destination or tag text blamed, or empty when none is to blame.
    pub target: String,
    /// Why the finding was reported.
    pub reason: String,
}

impl fmt::Display for Finding {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}:{}: ", self.file.display(), self.line)?;
        if self.target.is_empty() {
            write!(f, "{}", self.reason)
        } else {
            write!(f, "{} ({})", self.reason, self.target)
        }
    }
}

/// Checks every link in one Markdown file.
///
/// A relative link resolves against `base_dir`. A link starting with
/// `site_url` (which should end in `/`) names a published page: the part after
/// it, minus any anchor, is `<page>.html` and `<book_src>/<page>.md` must exist.
/// The site root and any book URL that does not end in `.html` pass.
/// A link with an empty destination is reported. Reference-style link
/// definitions, used or not, and raw `<a>` tags with an `href` are reported
/// because the book does not use them.
///
/// A file that cannot be read yields a finding rather than an empty result.
#[must_use]
pub fn scan_page(file: &Path, base_dir: &Path, book_src: &Path, site_url: &str) -> Vec<Finding> {
    let text = match fs::read_to_string(file) {
        Ok(text) => text,
        Err(err) => return vec![whole_file(file, format!("cannot read file: {err}"))],
    };
    let lines = LineStarts::new(&text);
    let mut findings = Vec::new();
    for item in parse(&text) {
        let reason = match item.kind {
            Kind::Link if item.target.is_empty() => Some("link has an empty target".to_owned()),
            Kind::Link => broken(&item.target, base_dir, book_src, site_url),
            Kind::Definition => Some(
                "reference-style link definitions are not allowed; use an inline link".to_owned(),
            ),
            Kind::RawAnchor => {
                Some("raw anchor tags are not allowed; use a Markdown link".to_owned())
            }
        };
        if let Some(reason) = reason {
            findings.push(Finding {
                file: file.to_path_buf(),
                line: lines.line_of(item.offset),
                target: item.target,
                reason,
            });
        }
    }
    findings
}

/// Reports every page under `book_src` that `SUMMARY.md` does not name.
///
/// A page is named by a link the Markdown parser reads in `SUMMARY.md`; an
/// entry inside a comment or a code block names nothing. `SUMMARY.md` itself
/// is not a page. A missing or unreadable `SUMMARY.md` is a finding rather
/// than an empty result.
#[must_use]
pub fn orphan_pages(book_src: &Path) -> Vec<Finding> {
    let summary = book_src.join("SUMMARY.md");
    let text = match fs::read_to_string(&summary) {
        Ok(text) => text,
        Err(err) => return vec![whole_file(&summary, format!("cannot read file: {err}"))],
    };
    let named: HashSet<PathBuf> = parse(&text)
        .into_iter()
        .filter(|item| item.kind == Kind::Link)
        .map(|item| normalize(Path::new(drop_anchor(&item.target))))
        .collect();

    let mut pages = Vec::new();
    if let Err(err) = collect_pages(book_src, &mut pages) {
        return vec![whole_file(book_src, format!("cannot list pages: {err}"))];
    }
    pages.sort();
    pages
        .into_iter()
        .filter(|page| {
            let relative = page.strip_prefix(book_src).unwrap_or(page);
            relative != Path::new("SUMMARY.md") && !named.contains(&normalize(relative))
        })
        .map(|page| whole_file(&page, "page is not listed in SUMMARY.md".to_owned()))
        .collect()
}

fn whole_file(file: &Path, reason: String) -> Finding {
    Finding {
        file: file.to_path_buf(),
        line: 0,
        target: String::new(),
        reason,
    }
}

/// Collects every `.md` file under `dir`, descending into subdirectories.
fn collect_pages(dir: &Path, pages: &mut Vec<PathBuf>) -> io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            collect_pages(&path, pages)?;
        } else if path.extension().is_some_and(|ext| ext == "md") {
            pages.push(path);
        }
    }
    Ok(())
}

/// Drops `.` components so `./a.md` and `a.md` compare equal.
fn normalize(path: &Path) -> PathBuf {
    path.components()
        .filter(|c| !matches!(c, Component::CurDir))
        .collect()
}

/// What a parsed construct is.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Kind {
    /// An inline link, image or autolink, with its destination.
    Link,
    /// A reference-style definition, `[label]: destination`.
    Definition,
    /// A raw `<a>` tag carrying an `href`.
    RawAnchor,
}

/// A link-bearing construct found in a page, with where it starts.
#[derive(Debug)]
struct Item {
    kind: Kind,
    /// The destination for a link or definition, the tag text for a raw anchor.
    target: String,
    /// Byte offset of the construct in the page.
    offset: usize,
}

/// Parses `text` and returns every link, reference definition and raw anchor in source order.
///
/// Links that exist only because a definition supplies their destination
/// (`[x][ref]`, `[ref]`) and email autolinks are left out: the definition is
/// reported on its own, and an address is not a path.
fn parse(text: &str) -> Vec<Item> {
    let mut events = Parser::new_ext(text, OPTIONS).into_offset_iter();
    let mut items = Vec::new();
    // Consecutive block-HTML lines arrive as separate events; a tag can span them.
    let mut block_html = String::new();
    let mut block_html_at = 0;
    for (event, range) in events.by_ref() {
        if !matches!(event, Event::Html(_)) {
            flush_html(&mut block_html, block_html_at, &mut items);
        }
        match event {
            Event::Start(
                Tag::Link {
                    link_type,
                    dest_url,
                    ..
                }
                | Tag::Image {
                    link_type,
                    dest_url,
                    ..
                },
            ) if matches!(link_type, LinkType::Inline | LinkType::Autolink) => {
                items.push(Item {
                    kind: Kind::Link,
                    target: dest_url.into_string(),
                    offset: range.start,
                });
            }
            Event::Html(html) => {
                if block_html.is_empty() {
                    block_html_at = range.start;
                }
                block_html.push_str(&html);
            }
            Event::Text(_) => {
                if let Some(target) = definition_lookalike(text, range.start) {
                    items.push(Item {
                        kind: Kind::Definition,
                        target: target.to_owned(),
                        offset: range.start,
                    });
                }
            }
            Event::InlineHtml(html) => raw_anchors(&html, range.start, &mut items),
            _ => {}
        }
    }
    flush_html(&mut block_html, block_html_at, &mut items);
    items.extend(events.reference_definitions().iter().map(|(_, def)| Item {
        kind: Kind::Definition,
        target: def.dest.to_string(),
        offset: def.span.start,
    }));
    items.sort_by_key(|item| item.offset);
    items
}

/// The destination of a `[label]: destination` line that the parser left as text, if the text at `at` is one.
///
/// A definition cannot interrupt a paragraph, so `[label]: url` on the line
/// after prose stays text and renders literally; it would become a real
/// definition the moment a blank line is added above it. Only a line that
/// starts with the `[` at `at` (after indentation and quote markers) counts,
/// and a footnote label (`[^1]:`) does not.
fn definition_lookalike(text: &str, at: usize) -> Option<&str> {
    let line_start = text[..at].rfind('\n').map_or(0, |newline| newline + 1);
    if !text[line_start..at]
        .chars()
        .all(|c| c.is_whitespace() || c == '>')
    {
        return None;
    }
    let line = text[at..].lines().next()?;
    let rest = line.strip_prefix('[')?;
    if rest.starts_with('^') {
        return None;
    }
    let end = rest.find(']')?;
    let destination = rest[end + 1..].strip_prefix(':')?;
    Some(destination.split_whitespace().next().unwrap_or(""))
}

/// Scans the buffered block HTML for raw anchors and empties the buffer.
fn flush_html(buffer: &mut String, offset: usize, items: &mut Vec<Item>) {
    if !buffer.is_empty() {
        raw_anchors(buffer, offset, items);
        buffer.clear();
    }
}

/// Appends one item for each `<a ... href ...>` tag in `html`, outside HTML comments.
///
/// `offset` is where `html` starts in the page; every item is placed there,
/// so a finding names the line the HTML begins on.
fn raw_anchors(html: &str, offset: usize, items: &mut Vec<Item>) {
    let mut rest = html;
    while !rest.is_empty() {
        if let Some(after) = rest.strip_prefix("<!--") {
            rest = after.find("-->").map_or("", |end| &after[end + 3..]);
            continue;
        }
        if let Some(tag) = anchor_tag(rest)
            && tag.to_ascii_lowercase().contains("href")
        {
            items.push(Item {
                kind: Kind::RawAnchor,
                target: tag.split_whitespace().collect::<Vec<_>>().join(" "),
                offset,
            });
        }
        let step = rest.chars().next().map_or(1, char::len_utf8);
        rest = &rest[step..];
    }
}

/// The text of an `<a` tag that starts at the beginning of `text`, up to its closing `>`.
fn anchor_tag(text: &str) -> Option<&str> {
    let mut chars = text.chars();
    let opens = chars.next() == Some('<')
        && chars.next().is_some_and(|c| c.eq_ignore_ascii_case(&'a'))
        && chars.next().is_some_and(char::is_whitespace);
    opens.then(|| text.find('>').map_or(text, |end| &text[..=end]))
}

/// Byte offsets at which each line of a page starts.
struct LineStarts(Vec<usize>);

impl LineStarts {
    fn new(text: &str) -> Self {
        let newlines = text.match_indices('\n').map(|(at, _)| at + 1);
        Self(std::iter::once(0).chain(newlines).collect())
    }

    /// The 1-based line containing byte `offset`.
    fn line_of(&self, offset: usize) -> usize {
        self.0.partition_point(|start| *start <= offset)
    }
}

fn drop_anchor(target: &str) -> &str {
    target.split_once('#').map_or(target, |(before, _)| before)
}

/// Whether the target starts with a URL scheme such as `https:` or `mailto:`.
fn has_scheme(target: &str) -> bool {
    let Some((scheme, _)) = target.split_once(':') else {
        return target.starts_with("//");
    };
    let mut chars = scheme.chars();
    chars.next().is_some_and(|c| c.is_ascii_alphabetic())
        && chars.all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '-' | '.'))
}

/// Why a link target does not resolve, or `None` when it passes or is skipped.
fn broken(target: &str, base_dir: &Path, book_src: &Path, site_url: &str) -> Option<String> {
    let target = drop_anchor(target);
    if target.is_empty() {
        return None;
    }
    if let Some(page) = target.strip_prefix(site_url) {
        // The bare site root passes; so does anything that is not an HTML page, such as a script.
        let page = page.strip_suffix(".html")?;
        return (!book_src.join(format!("{page}.md")).is_file())
            .then(|| format!("no page {page}.md in the book"));
    }
    if has_scheme(target) {
        return None;
    }
    (!base_dir.join(target).exists()).then(|| "link target does not exist".to_owned())
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use super::*;
    use tempfile::TempDir;

    const SITE: &str = "https://site/";

    /// A book source directory holding `a.md`, and a page to scan.
    struct Fixture {
        dir: TempDir,
    }

    impl Fixture {
        fn new() -> Self {
            let dir = TempDir::new().unwrap();
            fs::write(dir.path().join("a.md"), "# a\n").unwrap();
            Self { dir }
        }

        fn scan(&self, text: &str) -> Vec<Finding> {
            let page = self.dir.path().join("page.md");
            fs::write(&page, text).unwrap();
            scan_page(&page, self.dir.path(), self.dir.path(), SITE)
        }
    }

    #[test]
    fn inline_link_to_a_missing_file_is_a_finding() {
        let found = Fixture::new().scan("ok\n\nsee [x](nope.md) here\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert!(found[0].file.ends_with("page.md"));
        assert_eq!(found[0].line, 3);
        assert_eq!(found[0].target, "nope.md");
    }

    #[test]
    fn inline_link_to_a_present_file_passes() {
        assert!(Fixture::new().scan("[x](a.md)\n").is_empty());
    }

    #[test]
    fn image_to_a_missing_file_is_a_finding() {
        let found = Fixture::new().scan("![i](missing.png)\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "missing.png");
    }

    #[test]
    fn book_url_to_a_missing_page_is_a_finding() {
        let found = Fixture::new().scan("[x](https://site/gone.html)\n<https://site/gone.html>\n");
        assert_eq!(found.len(), 2, "{found:?}");
        assert_eq!(found[0].line, 1);
        assert_eq!(found[1].line, 2);
        assert_eq!(found[1].target, "https://site/gone.html");
    }

    #[test]
    fn book_url_to_a_present_page_passes() {
        assert!(Fixture::new().scan("[x](https://site/a.html)\n").is_empty());
    }

    #[test]
    fn bare_site_root_passes() {
        assert!(Fixture::new().scan("[x](https://site/)\n").is_empty());
    }

    #[test]
    fn book_url_that_is_not_a_page_is_skipped() {
        assert!(
            Fixture::new()
                .scan("[x](https://site/install.sh)\n")
                .is_empty()
        );
    }

    #[test]
    fn anchor_is_dropped_before_the_check() {
        assert!(Fixture::new().scan("[x](a.md#no-such-anchor)\n").is_empty());
    }

    #[test]
    fn anchor_only_link_is_skipped() {
        assert!(Fixture::new().scan("[x](#here)\n").is_empty());
    }

    #[test]
    fn external_url_is_skipped() {
        let text = "[x](https://example.com/x.html)\n<https://example.com/y.html>\n";
        assert!(Fixture::new().scan(text).is_empty());
    }

    #[test]
    fn links_in_fences_and_inline_code_are_skipped() {
        let text =
            "```text\n[x](nope.md)\n```\n\nuse `[y](nope.md)` like so\n\n~~~\n[z](nope.md)\n~~~\n";
        assert!(Fixture::new().scan(text).is_empty());
    }

    #[test]
    fn reference_definition_is_a_finding() {
        let found = Fixture::new().scan("text\n[ref]: nope.md\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].line, 2);
    }

    #[test]
    fn raw_anchor_tag_is_a_finding() {
        let found = Fixture::new().scan("<a href=\"x.html\">x</a>\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].line, 1);
    }

    #[test]
    fn relative_link_resolves_against_the_base_dir() {
        let with = TempDir::new().unwrap();
        fs::write(with.path().join("LICENSE"), "x").unwrap();
        let without = TempDir::new().unwrap();
        let src = TempDir::new().unwrap();
        let page = src.path().join("page.md");
        fs::write(&page, "[l](./LICENSE)\n").unwrap();

        assert!(scan_page(&page, with.path(), src.path(), SITE).is_empty());
        let found = scan_page(&page, without.path(), src.path(), SITE);
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "./LICENSE");
    }

    #[test]
    fn anchor_on_a_book_url_is_dropped_before_the_check() {
        let fixture = Fixture::new();
        assert!(
            fixture
                .scan("[x](https://site/a.html#no-such-anchor)\n")
                .is_empty()
        );
        // The page check still runs once the anchor is gone.
        let found = fixture.scan("[x](https://site/gone.html#top)\n");
        assert_eq!(found.len(), 1, "{found:?}");
    }

    #[test]
    fn page_missing_from_summary_is_an_orphan() {
        let dir = TempDir::new().unwrap();
        fs::write(
            dir.path().join("SUMMARY.md"),
            "# Summary\n\n- [A](a.md)\n  - [N](sub/n.md)\n",
        )
        .unwrap();
        fs::write(dir.path().join("a.md"), "").unwrap();
        fs::create_dir(dir.path().join("sub")).unwrap();
        fs::write(dir.path().join("sub/n.md"), "").unwrap();
        fs::write(dir.path().join("lost.md"), "").unwrap();

        let found = orphan_pages(dir.path());
        assert_eq!(found.len(), 1, "{found:?}");
        assert!(found[0].file.ends_with("lost.md"));
    }

    #[test]
    fn unreadable_file_is_a_finding() {
        let dir = TempDir::new().unwrap();
        let missing = dir.path().join("absent.md");
        let found = scan_page(&missing, dir.path(), dir.path(), SITE);
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].file, missing);
    }

    #[test]
    fn missing_summary_is_a_finding() {
        let dir = TempDir::new().unwrap();
        let found = orphan_pages(dir.path());
        assert_eq!(found.len(), 1, "{found:?}");
        assert!(found[0].file.ends_with("SUMMARY.md"));
    }

    #[test]
    fn link_after_a_fence_opened_on_a_list_item_is_checked() {
        let bullet = "- ```sh\n  foo\n  ```\n- [AFTER](nope1.md)\n";
        let found = Fixture::new().scan(bullet);
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "nope1.md");
        assert_eq!(found[0].line, 4);

        let numbered = "1. ```sh\n   foo\n   ```\n2. [AFTER](nope1.md)\n";
        assert_eq!(Fixture::new().scan(numbered).len(), 1);
    }

    #[test]
    fn link_after_a_code_span_wrapped_across_lines_is_checked() {
        let found = Fixture::new().scan("use `foo\nbar` and [AFTER](nope2.md) and `baz` ok\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "nope2.md");
        assert_eq!(found[0].line, 2);
    }

    #[test]
    fn raw_anchor_with_another_attribute_first_is_a_finding() {
        for tag in [
            "<a class=\"c\" href=\"nope7.html\">x</a>",
            "<a  href=\"x.html\">x</a>",
            "<a\thref=\"x.html\">x</a>",
            "<A HREF=\"x.html\">x</A>",
        ] {
            let found = Fixture::new().scan(&format!("text {tag}\n"));
            assert_eq!(found.len(), 1, "{tag}: {found:?}");
            assert_eq!(found[0].line, 1, "{tag}");
        }
    }

    #[test]
    fn raw_anchor_wrapped_onto_a_second_line_is_a_finding() {
        let found = Fixture::new().scan("see <a\nhref=\"x.html\">x</a>\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].line, 1);
    }

    #[test]
    fn anchor_tag_without_an_href_and_html_comments_are_not_findings() {
        let text = "<a name=\"top\"></a>\n\n<!-- <a href=\"x.html\"> -->\n";
        assert!(Fixture::new().scan(text).is_empty());
    }

    #[test]
    fn reference_definition_inside_a_container_is_a_finding() {
        let found = Fixture::new().scan("> [ref]: nope5.md\n\n- [lref]: nope6.md\n");
        assert_eq!(found.len(), 2, "{found:?}");
        assert_eq!(found[0].line, 1);
        assert_eq!(found[1].line, 3);
    }

    #[test]
    fn unused_reference_definition_is_a_finding() {
        let found = Fixture::new().scan("text\n\n[never-used]: a.md\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].line, 3);
    }

    #[test]
    fn footnote_definition_is_not_a_finding() {
        let text = "text[^1]\n\n[^1]: a note\n";
        assert!(Fixture::new().scan(text).is_empty());
    }

    #[test]
    fn paren_inside_a_title_does_not_hide_the_next_link() {
        let found = Fixture::new().scan("[a](a.md \"foo (bar\") and [x](nope3.md)\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "nope3.md");
    }

    #[test]
    fn destination_on_the_line_after_the_bracket_is_checked() {
        let found = Fixture::new().scan("[x](\n  nope4.md\n)\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].target, "nope4.md");
        assert_eq!(found[0].line, 1);
    }

    #[test]
    fn empty_target_is_a_finding() {
        for text in ["[x]()\n", "[x](<>)\n", "![i]()\n"] {
            let found = Fixture::new().scan(text);
            assert_eq!(found.len(), 1, "{text:?}: {found:?}");
            assert_eq!(found[0].line, 1);
        }
    }

    #[test]
    fn commented_out_summary_entry_is_not_named() {
        let found = orphans("# Summary\n\n- [A](a.md)\n<!-- - [L](lost.md) -->\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert!(found[0].file.ends_with("lost.md"));
    }

    #[test]
    fn fenced_summary_entry_is_not_named() {
        let found = orphans("# Summary\n\n- [A](a.md)\n\n```\n- [L](lost.md)\n```\n");
        assert_eq!(found.len(), 1, "{found:?}");
        assert!(found[0].file.ends_with("lost.md"));
    }

    /// Runs `orphan_pages` over a book holding `a.md` and `lost.md` with the given `SUMMARY.md`.
    fn orphans(summary: &str) -> Vec<Finding> {
        let dir = TempDir::new().unwrap();
        fs::write(dir.path().join("SUMMARY.md"), summary).unwrap();
        fs::write(dir.path().join("a.md"), "").unwrap();
        fs::write(dir.path().join("lost.md"), "").unwrap();
        orphan_pages(dir.path())
    }
}
