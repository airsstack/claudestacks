//! What Claude Code specifies about plugin hooks.
//!
//! One module owns the contract so no other component has to guess at it.
//! Four questions, four files:
//!
//! - [`event`] — which events exist, which take a matcher, how their output
//!   may decide, whose bare stdout is injected as context.
//! - [`matcher`] — how a `matcher` value is evaluated, in both its documented
//!   modes.
//! - [`handler`] — the `hooks.json` handler entry and its two execution
//!   models.
//! - [`site`] — which plugin files Claude Code loads, which positions in them
//!   are load-bearing, and where a reference ends.
//!
//! Everything here describes Claude Code. Nothing here describes what claudevs
//! can do about it: whether a case can be run against an event is
//! [`crate::types::HookEvent`]'s answer, and the two are deliberately separate
//! types over overlapping sets.
//!
//! This module re-exports its four submodules and carries no logic of its own.

pub mod event;
pub mod handler;
pub mod matcher;
pub mod site;

pub use event::{DecisionMechanism, DocumentedEvent, MatcherSupport, catalogue, lookup};
pub use handler::HookCommand;
pub use matcher::MatcherRule;
