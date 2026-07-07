//! Receive-only UDP telemetry stream.
//!
//! This module owns the socket loop for `127.0.0.1:16000`. It receives UDP JSON,
//! parses it into `VehicleSnapshot` objects, and forwards those snapshots to
//! Flutter. It intentionally has no command path back to a vehicle.

use crate::frb_generated::StreamSink;
use crate::telemetry::link_manager::{TelemetryLinkManager, TELEMETRY_BIND_ADDRESS};
use crate::telemetry::parser::parse_telemetry_snapshot;
use crate::telemetry::snapshot::VehicleSnapshot;
use tokio::net::UdpSocket;

/// Starts the receive-only UDP telemetry loop.
pub fn start_udp_telemetry_stream(sink: StreamSink<VehicleSnapshot>) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;

    rt.block_on(async {
        let socket = UdpSocket::bind(TELEMETRY_BIND_ADDRESS).await?;
        let mut buffer = [0u8; 2048];
        let mut link_manager = TelemetryLinkManager::new();

        loop {
            let (byte_size, source_address) = socket.recv_from(&mut buffer).await?;
            let parse_error =
                serde_json::from_slice::<serde_json::Value>(&buffer[..byte_size]).is_err();
            let diagnostics = link_manager.observe_packet(parse_error);
            let snapshot = parse_telemetry_snapshot(
                &buffer[..byte_size],
                byte_size,
                source_address,
                diagnostics,
            );

            if sink.add(snapshot).is_err() {
                break;
            }
        }
        anyhow::Ok(())
    })?;

    Ok(())
}
