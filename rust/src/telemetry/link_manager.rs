//! V1 telemetry link boundary.
//!
//! `TelemetryLinkManager` owns the receive-only source selected for V1. The
//! current source is a UDP JSON adapter, normally fed by
//! `tools/mavlink_to_udp_json.py` or `tools/send_sample_telemetry.py`.
//!
//! Future work can add a Rust-native MAVLink source behind this boundary. The
//! Flutter API should continue to consume `VehicleSnapshot` diagnostics instead
//! of learning how a specific source receives bytes.

use std::time::Instant;

/// Human-readable name for the V1 receive-only adapter.
pub(crate) const UDP_JSON_SOURCE_TYPE: &str = "UDP JSON adapter";

/// Local UDP address used by the current V1 telemetry contract.
pub(crate) const TELEMETRY_BIND_ADDRESS: &str = "127.0.0.1:16000";

/// Safety note surfaced to Flutter diagnostics.
pub(crate) const RECEIVE_ONLY_NOTE: &str =
    "Receive-only V1 adapter: no commands, parameter writes, or mission upload.";

/// Running diagnostics for the active telemetry source.
#[derive(Debug)]
pub(crate) struct TelemetryLinkManager {
    started_at: Instant,
    packet_count: u32,
    parse_error_count: u32,
}

impl TelemetryLinkManager {
    pub(crate) fn new() -> Self {
        Self {
            started_at: Instant::now(),
            packet_count: 0,
            parse_error_count: 0,
        }
    }

    pub(crate) fn observe_packet(&mut self, parse_error: bool) -> TelemetrySourceDiagnostics {
        self.packet_count += 1;
        if parse_error {
            self.parse_error_count += 1;
        }

        let elapsed_s = self.started_at.elapsed().as_secs_f32().max(0.001);
        TelemetrySourceDiagnostics {
            source_type: UDP_JSON_SOURCE_TYPE.to_string(),
            bind_address: TELEMETRY_BIND_ADDRESS.to_string(),
            packet_count: self.packet_count,
            parse_error_count: self.parse_error_count,
            message_rate_hz: self.packet_count as f32 / elapsed_s,
            receive_only_note: RECEIVE_ONLY_NOTE.to_string(),
        }
    }
}

/// Snapshot of link diagnostics attached to each decoded vehicle snapshot.
#[derive(Debug)]
pub(crate) struct TelemetrySourceDiagnostics {
    pub(crate) source_type: String,
    pub(crate) bind_address: String,
    pub(crate) packet_count: u32,
    pub(crate) parse_error_count: u32,
    pub(crate) message_rate_hz: f32,
    pub(crate) receive_only_note: String,
}
