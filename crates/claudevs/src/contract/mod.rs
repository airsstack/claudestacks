//! What Claude Code specifies about plugin hooks.
//!
//! One module owns the contract so no other component has to guess at it.
//!
//! - [`event`] — which events exist, which take a matcher, how their output
//!   may decide, whose bare stdout is injected as context.
//! - [`matcher`] — how a `matcher` value is evaluated, in both its documented
//!   modes.
//!
//! Everything here describes Claude Code. Nothing here describes what claudevs
//! can do about it: whether a case can be run against an event is
//! [`crate::types::HookEvent`]'s answer, and the two are deliberately separate
//! types over overlapping sets.
//!
//! This module re-exports [`event`] and [`matcher`] and carries no logic of
//! its own.

pub mod event;
pub mod matcher;
