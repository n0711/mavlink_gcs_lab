//! Flutter/Rust bridge entry point for receive-only telemetry streaming.
//!
//! Flutter calls this module to start the Rust telemetry stream. The parsing,
//! UDP socket loop, and telemetry data model live in `crate::telemetry` so this
//! bridge-facing file stays small and easy to explain.

use crate::frb_generated::StreamSink;
pub use crate::telemetry::{MessageRateSnapshot, VehicleSnapshot};

/// Starts the receive-only telemetry stream consumed by Flutter.
///
/// This function intentionally exposes no command authority. It only forwards
/// telemetry snapshots produced by the Rust backend.
pub fn start_telemetry_stream(sink: StreamSink<VehicleSnapshot>) -> anyhow::Result<()> {
    crate::telemetry::start_udp_telemetry_stream(sink)
}
