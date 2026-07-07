//! Receive-only telemetry backend modules.
//!
//! This module owns the Rust side of the UDP JSON telemetry path. It does not
//! send MAVLink commands, request live parameters, write parameters, or expose
//! vehicle control operations.

mod link_manager;
mod message_rates;
mod parser;
mod payload;
mod snapshot;
mod udp_stream;

pub use snapshot::{MessageRateSnapshot, VehicleSnapshot};
pub use udp_stream::start_udp_telemetry_stream;
