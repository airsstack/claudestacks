//! Validating newtypes for claudevs domain values.
//!
//! Four of the five types this module exports are newtypes with one
//! validated field — [`CaseName`], [`MarketplaceName`], [`PluginName`],
//! [`PluginVersion`] — plus their four error structs
//! ([`InvalidCaseName`], [`InvalidMarketplaceName`], [`InvalidPluginName`],
//! [`InvalidPluginVersion`]). None of those eight carries `#[non_exhaustive]`,
//! deliberately: each newtype's invariant is the whole type, so there is
//! nothing to add to a `PluginName` that is not a different type, and each
//! error struct carries only the rejected value.
//!
//! [`HookEvent`] is the exception in this file, not another instance of the
//! rule above: it is an enum whose variant set Claude Code decides, not a
//! validated newtype, so it *does* carry `#[non_exhaustive]` like every other
//! type in the crate that fits that description. Its error struct,
//! [`InvalidHookEvent`], stays open for the same reason as the other four —
//! it carries only the string that failed to parse — which is why this
//! module holds five open error structs against only four open newtypes.
//!
//! Every other public type in this crate carries `#[non_exhaustive]` except
//! two, both still open pending a decision by the crate's maintainers rather
//! than an oversight: [`crate::case::Invocation`], whose fields are all
//! `pub` with no invariant guarding them, and [`crate::harness::TModule`],
//! whose fields are already private so the attribute would add nothing.
//! This file is where the closed exceptions, and the one look-alike that is
//! not one, are written down; those two open types are not among them.

mod case_name;
mod hook_event;
mod ident;
mod marketplace_name;
mod plugin_name;
mod plugin_version;

pub use case_name::{CaseName, InvalidCaseName};
pub use hook_event::{HookEvent, InvalidHookEvent};
pub use marketplace_name::{InvalidMarketplaceName, MarketplaceName};
pub use plugin_name::{InvalidPluginName, PluginName};
pub use plugin_version::{InvalidPluginVersion, PluginVersion};
