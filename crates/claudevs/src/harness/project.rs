//! Materializing a case's temp project, from a fixture or synthesized fresh.
//!
//! Fixtures are plain directories under `tests/fixtures/`. A fixture holding a
//! file named `.gitinit` gets `git init` + one commit (the marker itself is not
//! copied). A fixtureless case gets [`Project::empty`]'s default project
//! instead: a manifest, one tracked file, and a git repository, so a hook that
//! branches on project shape does not silently take its not-found path. Both
//! kinds are hermetic against the developer's own git configuration — see
//! [`git`]. Nothing ever executes against the plugin's real checkout.

use std::path::{Path, PathBuf};

use crate::error::{Error, Result};

/// The one file the default project ships and tracks.
///
/// A hook case's payload names this path, so a hook that stats its target
/// finds a real file rather than taking the not-found branch. One constant so
/// the project and the payload cannot drift apart —
/// [`crate::harness::payload`] reads it.
#[expect(
    clippy::redundant_pub_crate,
    reason = "explicit pub(crate) documents that harness::payload, a sibling module, shares this constant"
)]
pub(crate) const TRACKED_FILE: &str = "file.txt";

/// The manifest the default project ships.
///
/// A hook guarding a lockfile, or refusing to run outside a package, takes its
/// silent branch in a bare temp directory — and a case then passes exactly as
/// well when the hook is broken as when it works. This closes that branch for
/// the commonest shape; it does not close every one. A hook keyed on a
/// `package.json` or a `pyproject.toml` still finds nothing, and a case that
/// asserts too little still passes.
const PROJECT_MANIFEST: &str = "\
[package]
name = \"claudevs-test-project\"
version = \"0.1.0\"
edition = \"2024\"
";

/// A materialized temp project (deleted on drop).
#[derive(Debug)]
pub struct Project {
    dir: tempfile::TempDir,
}

impl Project {
    /// A temp directory and nothing else.
    ///
    /// The substrate both constructors share. [`Project::empty`] builds the
    /// default project on top of it; [`Project::from_fixture`] copies a fixture
    /// tree into it and leaves that tree exactly as its author wrote it.
    fn bare() -> Result<Self> {
        let dir = tempfile::tempdir().map_err(|source| Error::Io {
            operation: "create temp project",
            path: String::from("(tempdir)"),
            source,
        })?;
        Ok(Self { dir })
    }

    /// A project with nothing in it but the shape of a project.
    ///
    /// Git-initialised, carrying a manifest and one tracked file. A bare temp
    /// directory would let a hook that branches on project state take its silent
    /// branch, which makes a case pass whether the hook works or not.
    ///
    /// # Errors
    ///
    /// [`Error::Io`] when the temp dir cannot be created or written, or when
    /// `git` is not on `PATH`.
    pub fn empty() -> Result<Self> {
        let project = Self::bare()?;
        let root = project.path();

        write_file(&root.join("Cargo.toml"), PROJECT_MANIFEST)?;
        write_file(&root.join(TRACKED_FILE), "claudevs test project\n")?;

        git(root, &["init", "-q"])?;
        git(root, &["add", "Cargo.toml", TRACKED_FILE])?;
        git(
            root,
            &[
                "-c",
                "user.email=t@t",
                "-c",
                "user.name=t",
                "commit",
                "-q",
                "-m",
                "init",
            ],
        )?;
        Ok(project)
    }

    /// A project seeded from `fixtures_root/<name>`.
    ///
    /// # Errors
    ///
    /// [`Error::Fixture`] when the fixture is missing; [`Error::Io`] on copy failure.
    pub fn from_fixture(fixtures_root: &Path, name: &str) -> Result<Self> {
        let source = fixtures_root.join(name);
        if !source.is_dir() {
            return Err(Error::Fixture {
                name: name.to_owned(),
                reason: format!("no directory at `{}`", source.display()),
            });
        }
        let project = Self::bare()?;
        copy_tree(&source, project.path())?;

        if source.join(".gitinit").is_file() {
            let _ = std::fs::remove_file(project.path().join(".gitinit"));
            git(project.path(), &["init", "-q"])?;
            git(
                project.path(),
                &[
                    "-c",
                    "user.email=t@t",
                    "-c",
                    "user.name=t",
                    "commit",
                    "-q",
                    "--allow-empty",
                    "-m",
                    "init",
                ],
            )?;
        }
        Ok(project)
    }

    /// Overlays `fixtures_root/<name>` onto this project (flow `apply_fixture`).
    ///
    /// # Errors
    ///
    /// Same conditions as [`Project::from_fixture`].
    pub fn overlay(&self, fixtures_root: &Path, name: &str) -> Result<()> {
        overlay_into(fixtures_root, name, self.path())
    }

    /// The project's root directory.
    #[must_use]
    pub fn path(&self) -> &Path {
        self.dir.path()
    }
}

/// Overlays `fixtures_root/<name>` into an existing directory.
///
/// # Errors
///
/// Same conditions as [`Project::from_fixture`].
pub fn overlay_into(fixtures_root: &Path, name: &str, into: &Path) -> Result<()> {
    let source = fixtures_root.join(name);
    if !source.is_dir() {
        return Err(Error::Fixture {
            name: name.to_owned(),
            reason: format!("no directory at `{}`", source.display()),
        });
    }
    copy_tree(&source, into)
}

/// Recursively copies `from` into the existing directory `to`.
#[expect(
    clippy::redundant_pub_crate,
    reason = "explicit pub(crate) documents that the installed layout shares this copier"
)]
pub(crate) fn copy_tree(from: &Path, to: &Path) -> Result<()> {
    for entry in walkdir::WalkDir::new(from).sort_by_file_name() {
        let entry = entry.map_err(|e| Error::Io {
            operation: "walk fixture",
            path: from.display().to_string(),
            source: e.into(),
        })?;
        let rel: PathBuf = entry
            .path()
            .strip_prefix(from)
            .unwrap_or_else(|_| entry.path())
            .to_path_buf();
        if rel.as_os_str().is_empty() {
            continue;
        }
        let dest = to.join(&rel);
        let io = |source| Error::Io {
            operation: "copy fixture",
            path: dest.display().to_string(),
            source,
        };
        if entry.file_type().is_dir() {
            std::fs::create_dir_all(&dest).map_err(io)?;
        } else {
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent).map_err(io)?;
            }
            std::fs::copy(entry.path(), &dest).map_err(io)?;
        }
    }
    Ok(())
}

/// Writes `contents` to `path`, mapping a failure into [`Error::Io`].
fn write_file(path: &Path, contents: &str) -> Result<()> {
    std::fs::write(path, contents).map_err(|source| Error::Io {
        operation: "write default project file",
        path: path.display().to_string(),
        source,
    })
}

/// Runs git in `dir`, discarding output.
///
/// Hermetic against the developer's own machine: `GIT_CONFIG_GLOBAL=/dev/null`
/// and `GIT_CONFIG_NOSYSTEM=1` stop the child from reading `~/.gitconfig` or
/// `/etc/gitconfig`, so a personal `commit.gpgsign`, `core.hooksPath`, or
/// `init.templateDir` cannot reach a project this harness synthesizes for
/// itself. Without this, a signing-enabled machine fails every fixtureless
/// case at the `commit` step with a `gpg` error that names none of the above.
fn git(dir: &Path, args: &[&str]) -> Result<()> {
    let status = std::process::Command::new("git")
        .args(args)
        .current_dir(dir)
        .env("GIT_CONFIG_GLOBAL", "/dev/null")
        .env("GIT_CONFIG_NOSYSTEM", "1")
        .output()
        .map_err(|source| Error::Io {
            operation: "run git",
            path: dir.display().to_string(),
            source,
        })?;
    if status.status.success() {
        Ok(())
    } else {
        Err(Error::Io {
            operation: "run git",
            path: dir.display().to_string(),
            source: std::io::Error::other(format!(
                "git {args:?} failed: {}",
                String::from_utf8_lossy(&status.stderr)
            )),
        })
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use super::Project;

    fn fixtures() -> tempfile::TempDir {
        let root = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(root.path().join("repo/src")).unwrap();
        std::fs::write(root.path().join("repo/Cargo.toml"), "[package]\n").unwrap();
        std::fs::write(root.path().join("repo/src/main.rs"), "fn main() {}\n").unwrap();
        root
    }

    #[test]
    fn a_fixture_is_copied_into_a_fresh_temp_dir() {
        let root = fixtures();
        let project = Project::from_fixture(root.path(), "repo").unwrap();
        assert!(project.path().join("src/main.rs").is_file());
        assert_ne!(project.path(), root.path().join("repo"));
    }

    #[test]
    fn a_gitinit_marker_produces_a_repo_and_is_not_copied() {
        let root = fixtures();
        std::fs::write(root.path().join("repo/.gitinit"), "").unwrap();
        let project = Project::from_fixture(root.path(), "repo").unwrap();
        assert!(project.path().join(".git").is_dir());
        assert!(!project.path().join(".gitinit").exists());
    }

    #[test]
    fn a_missing_fixture_is_an_author_error_naming_it() {
        let root = fixtures();
        let error = Project::from_fixture(root.path(), "nope")
            .unwrap_err()
            .to_string();
        assert!(error.contains("nope"), "{error}");
    }

    #[test]
    fn overlay_adds_files_to_an_existing_project() {
        let root = fixtures();
        std::fs::create_dir_all(root.path().join("edits")).unwrap();
        std::fs::write(root.path().join("edits/new.md"), "x").unwrap();
        let project = Project::from_fixture(root.path(), "repo").unwrap();
        project.overlay(root.path(), "edits").unwrap();
        assert!(project.path().join("new.md").is_file());
        assert!(project.path().join("src/main.rs").is_file());
    }

    #[test]
    fn the_default_project_looks_like_a_project_a_hook_could_branch_on() {
        let project = Project::empty().unwrap();
        let root = project.path();

        assert!(
            root.join("Cargo.toml").is_file(),
            "a hook that branches on project type finds nothing without a manifest"
        );
        assert!(
            root.join(super::TRACKED_FILE).is_file(),
            "a hook whose payload names a file needs that file to exist"
        );
        assert!(
            root.join(".git").is_dir(),
            "a hook that shells out to git needs a repository"
        );
    }

    #[test]
    fn the_default_projects_tracked_file_is_committed_not_merely_present() {
        let project = Project::empty().unwrap();
        let output = std::process::Command::new("git")
            .args(["ls-files", "--error-unmatch", super::TRACKED_FILE])
            .current_dir(project.path())
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "`git ls-files --error-unmatch {}` failed: {}",
            super::TRACKED_FILE,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    #[test]
    fn project_empty_is_hermetic_against_a_hostile_global_git_config() {
        // A developer's own `commit.gpgsign = true` (or `core.hooksPath`, or
        // `init.templateDir`) must never reach this harness's own synthesized
        // project — see the doc on `super::git`. Re-exec this test binary as a
        // child process carrying a hostile `GIT_CONFIG_GLOBAL`, rather than
        // mutating this process's own environment, so sibling tests running
        // concurrently on other threads cannot race a process-wide env change.
        let hostile_config = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(
            hostile_config.path(),
            "[commit]\n\tgpgsign = true\n[gpg]\n\tprogram = /nonexistent/gpg\n",
        )
        .unwrap();

        let exe = std::env::current_exe().unwrap();
        let output = std::process::Command::new(exe)
            .args([
                "--exact",
                "harness::project::tests::a_project_is_built_under_a_hostile_global_git_config",
                "--include-ignored",
            ])
            .env("GIT_CONFIG_GLOBAL", hostile_config.path())
            .output()
            .unwrap();

        assert!(
            output.status.success(),
            "stdout: {}\nstderr: {}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    #[test]
    #[ignore = "exercised only as a child process of \
                `project_empty_is_hermetic_against_a_hostile_global_git_config`, \
                under a deliberately hostile GIT_CONFIG_GLOBAL"]
    fn a_project_is_built_under_a_hostile_global_git_config() {
        Project::empty().unwrap();
    }

    #[test]
    fn a_fixture_project_is_left_exactly_as_its_author_wrote_it() {
        // A fixture author owns their tree. A manifest injected into it could
        // collide with one they shipped, and `from_fixture`'s `.gitinit` marker
        // is how a fixture asks for a repository.
        let fixtures = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(fixtures.path().join("plain")).unwrap();
        std::fs::write(fixtures.path().join("plain/README.md"), "x").unwrap();
        let project = Project::from_fixture(fixtures.path(), "plain").unwrap();
        assert!(!project.path().join("Cargo.toml").exists());
        assert!(!project.path().join(super::TRACKED_FILE).exists());
        assert!(!project.path().join(".git").exists());
    }
}
