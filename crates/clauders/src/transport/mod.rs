//! Generic async transport substrate for the SDK.
//!
//! Layered: [`Transport`] is the generic send-one-request contract;
//! [`HttpTransport`] is the HTTP specialization (a `Transport` whose
//! associated types are the `http` crate types); [`ReqwestTransport`] is the
//! concrete `reqwest`-backed implementer.
//!
//! Vendored from the `airs-transport` crate when this SDK moved to its own
//! repository. Boundary test for what belongs here: *does the code name a
//! provider, an endpoint, an API-key format, a model catalog, a sampling
//! range, or a wire error envelope?* If yes, it belongs in the SDK proper;
//! if no, it is eligible for this module.

pub mod body;
pub mod collect;
pub mod contract;
pub mod error;
pub mod http_transport;
pub mod reqwest_impl;

pub use body::BodyStream;
pub use collect::{MAX_RESPONSE_BODY_BYTES, collect_body};
pub use contract::Transport;
pub use error::TransportError;
pub use http_transport::HttpTransport;
pub use reqwest_impl::ReqwestTransport;
