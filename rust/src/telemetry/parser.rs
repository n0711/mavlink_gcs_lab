//! UDP JSON parser for receive-only telemetry snapshots.
//!
//! Parsing failures are converted into safe fallback snapshots. The parser does
//! not send commands, request parameters, or infer authority from incoming data.

use crate::telemetry::link_manager::{
    TelemetrySourceDiagnostics, RECEIVE_ONLY_NOTE, TELEMETRY_BIND_ADDRESS, UDP_JSON_SOURCE_TYPE,
};
use crate::telemetry::message_rates::message_rates_from_metadata;
use crate::telemetry::payload::TelemetryPayload;
use crate::telemetry::snapshot::VehicleSnapshot;
use std::net::SocketAddr;

/// Returns a safe snapshot for malformed UDP telemetry.
///
/// Invalid packets must not crash the backend and must not look like an armed
/// or controllable vehicle. Every optional field is unavailable and the status
/// text clearly reports the invalid packet.
fn invalid_packet_snapshot(diagnostics: TelemetrySourceDiagnostics) -> VehicleSnapshot {
    VehicleSnapshot {
        latitude: None,
        longitude: None,
        altitude_m: None,
        roll_deg: None,
        pitch_deg: None,
        yaw_deg: None,
        battery_pct: None,
        battery_voltage_v: None,
        battery_current_a: None,
        battery_validity: None,
        battery_source: None,
        is_armed: false,
        mode: None,
        gps_fix_type: None,
        satellites_visible: None,
        hdop: None,
        heartbeat_age_s: None,
        attitude_age_s: None,
        attitude_age_ms: None,
        position_age_s: None,
        battery_age_s: None,
        gps_age_s: None,
        vehicle_sysid: None,
        vehicle_compid: None,
        yaw_source: None,
        heading_source: None,
        last_message_type: None,
        locked_vehicle_source: false,
        message_rates: Vec::new(),
        telemetry_source_type: diagnostics.source_type,
        telemetry_bind_address: diagnostics.bind_address,
        telemetry_packet_count: diagnostics.packet_count,
        telemetry_parse_error_count: diagnostics.parse_error_count,
        telemetry_message_rate_hz: diagnostics.message_rate_hz,
        telemetry_receive_only_note: diagnostics.receive_only_note,
        status_text: "Invalid UDP telemetry packet received".to_string(),
    }
}

/// Converts one UDP JSON packet into a Flutter-facing vehicle snapshot.
pub(crate) fn parse_telemetry_snapshot(
    payload: &[u8],
    byte_size: usize,
    source_address: SocketAddr,
    diagnostics: TelemetrySourceDiagnostics,
) -> VehicleSnapshot {
    let Ok(telemetry) = serde_json::from_slice::<TelemetryPayload>(payload) else {
        return invalid_packet_snapshot(diagnostics);
    };
    let position = telemetry.position;
    let motion = telemetry.motion;
    let attitude = telemetry.attitude;
    let system = telemetry.system;
    let gps = telemetry.gps;
    let telemetry_metadata = telemetry.telemetry;
    let health = telemetry.health;
    let freshness = telemetry.freshness;
    let source = telemetry.source;

    let mode = system
        .as_ref()
        .and_then(|system| system.mode.as_deref())
        .unwrap_or("UNKNOWN");
    let message_type = telemetry.message_type.as_deref().unwrap_or("telemetry");
    let timestamp = telemetry.timestamp.as_deref().unwrap_or("no timestamp");

    VehicleSnapshot {
        latitude: position.as_ref().and_then(|position| position.latitude_deg),
        longitude: position
            .as_ref()
            .and_then(|position| position.longitude_deg),
        altitude_m: position.as_ref().and_then(|position| position.altitude_m),
        roll_deg: attitude.as_ref().and_then(|attitude| attitude.roll_deg),
        pitch_deg: attitude.as_ref().and_then(|attitude| attitude.pitch_deg),
        // Some sources provide heading but not yaw. Reusing heading keeps the
        // dashboard oriented without inventing a new value.
        yaw_deg: attitude
            .as_ref()
            .and_then(|attitude| attitude.yaw_deg)
            .or_else(|| motion.as_ref().and_then(|motion| motion.heading_deg)),
        battery_pct: system.as_ref().and_then(|system| system.battery_percent),
        battery_voltage_v: system.as_ref().and_then(|system| system.battery_voltage_v),
        battery_current_a: system.as_ref().and_then(|system| system.battery_current_a),
        battery_validity: system
            .as_ref()
            .and_then(|system| system.battery_validity.clone()),
        battery_source: system
            .as_ref()
            .and_then(|system| system.battery_source.clone()),
        is_armed: system
            .as_ref()
            .and_then(|system| system.armed)
            .unwrap_or(false),
        mode: Some(mode.to_string()),
        gps_fix_type: gps
            .as_ref()
            .and_then(|gps| gps.fix_type)
            .or_else(|| health.as_ref().and_then(|health| health.gps_fix_type)),
        satellites_visible: gps
            .as_ref()
            .and_then(|gps| gps.satellites_visible)
            .or_else(|| health.as_ref().and_then(|health| health.satellites_visible)),
        hdop: gps
            .as_ref()
            .and_then(|gps| gps.hdop)
            .or_else(|| health.as_ref().and_then(|health| health.hdop)),
        heartbeat_age_s: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.heartbeat_age_ms)
            .map(|age_ms| age_ms as f32 / 1000.0)
            .or_else(|| {
                freshness
                    .as_ref()
                    .and_then(|freshness| freshness.heartbeat_age_s)
            }),
        attitude_age_s: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.attitude_age_ms)
            .map(|age_ms| age_ms as f32 / 1000.0)
            .or_else(|| {
                freshness
                    .as_ref()
                    .and_then(|freshness| freshness.attitude_age_s)
            }),
        attitude_age_ms: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.attitude_age_ms)
            .or_else(|| attitude.as_ref().and_then(|attitude| attitude.age_ms)),
        position_age_s: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.position_age_ms)
            .map(|age_ms| age_ms as f32 / 1000.0)
            .or_else(|| {
                freshness
                    .as_ref()
                    .and_then(|freshness| freshness.position_age_s)
            }),
        battery_age_s: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.battery_age_ms)
            .map(|age_ms| age_ms as f32 / 1000.0)
            .or_else(|| {
                freshness
                    .as_ref()
                    .and_then(|freshness| freshness.battery_age_s)
            }),
        gps_age_s: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.gps_age_ms)
            .map(|age_ms| age_ms as f32 / 1000.0)
            .or_else(|| freshness.as_ref().and_then(|freshness| freshness.gps_age_s)),
        vehicle_sysid: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.vehicle_sysid)
            .or_else(|| source.as_ref().and_then(|source| source.vehicle_sysid)),
        vehicle_compid: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.vehicle_compid)
            .or_else(|| source.as_ref().and_then(|source| source.vehicle_compid)),
        yaw_source: source.as_ref().and_then(|source| source.yaw_source.clone()),
        heading_source: source
            .as_ref()
            .and_then(|source| source.heading_source.clone())
            .or_else(|| {
                motion
                    .as_ref()
                    .and_then(|motion| motion.heading_source.clone())
            }),
        last_message_type: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.last_message_type.clone()),
        locked_vehicle_source: telemetry_metadata
            .as_ref()
            .and_then(|telemetry| telemetry.locked_vehicle_source)
            .unwrap_or(false),
        message_rates: message_rates_from_metadata(telemetry_metadata.as_ref()),
        telemetry_source_type: diagnostics.source_type,
        telemetry_bind_address: diagnostics.bind_address,
        telemetry_packet_count: diagnostics.packet_count,
        telemetry_parse_error_count: diagnostics.parse_error_count,
        telemetry_message_rate_hz: diagnostics.message_rate_hz,
        telemetry_receive_only_note: diagnostics.receive_only_note,
        status_text: telemetry.status_text.unwrap_or_else(|| {
            format!(
                "Decoded {} JSON ({} bytes) from {} at {} [{}]",
                message_type, byte_size, source_address, timestamp, mode
            )
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source_address() -> SocketAddr {
        "127.0.0.1:14550".parse().unwrap()
    }

    fn parse(payload: &str) -> VehicleSnapshot {
        parse_telemetry_snapshot(
            payload.as_bytes(),
            payload.len(),
            source_address(),
            TelemetrySourceDiagnostics {
                source_type: UDP_JSON_SOURCE_TYPE.to_string(),
                bind_address: TELEMETRY_BIND_ADDRESS.to_string(),
                packet_count: 1,
                parse_error_count: 0,
                message_rate_hz: 1.0,
                receive_only_note: RECEIVE_ONLY_NOTE.to_string(),
            },
        )
    }

    #[test]
    fn parses_valid_json_with_position_attitude_battery_and_armed_state() {
        // Protects the main happy path from UDP JSON into Flutter-facing fields.
        let snapshot = parse(
            r#"{
                "timestamp": "2026-06-30T07:46:09Z",
                "message_type": "vehicle_state",
                "position": {
                    "latitude_deg": 34.981269,
                    "longitude_deg": 34.002445,
                    "altitude_m": 4.8
                },
                "attitude": {
                    "roll_deg": -4.9,
                    "pitch_deg": 8.0,
                    "yaw_deg": 319.8
                },
                "system": {
                    "armed": true,
                    "battery_percent": 74,
                    "mode": "AUTO"
                }
            }"#,
        );

        assert_eq!(snapshot.latitude, Some(34.981269));
        assert_eq!(snapshot.longitude, Some(34.002445));
        assert_eq!(snapshot.altitude_m, Some(4.8));
        assert_eq!(snapshot.roll_deg, Some(-4.9));
        assert_eq!(snapshot.pitch_deg, Some(8.0));
        assert_eq!(snapshot.yaw_deg, Some(319.8));
        assert_eq!(snapshot.battery_pct, Some(74));
        assert!(snapshot.is_armed);
        assert!(snapshot.status_text.contains("Decoded vehicle_state JSON"));
    }

    #[test]
    fn uses_motion_heading_when_yaw_is_missing() {
        // Some telemetry bridges provide heading without attitude yaw.
        let snapshot = parse(
            r#"{
                "motion": { "heading_deg": 181.5 },
                "attitude": { "roll_deg": 1.0, "pitch_deg": 2.0 },
                "system": { "armed": false }
            }"#,
        );

        assert_eq!(snapshot.yaw_deg, Some(181.5));
    }

    #[test]
    fn preserves_voltage_without_inventing_percent_when_percent_is_missing() {
        // Voltage-only packets must not invent battery percentage.
        let snapshot = parse(
            r#"{
                "system": {
                    "armed": false,
                    "battery_voltage_v": 11.55
                }
            }"#,
        );

        assert_eq!(snapshot.battery_pct, None);
        assert_eq!(snapshot.battery_voltage_v, Some(11.55));
    }

    #[test]
    fn invalid_json_returns_safe_fallback_snapshot() {
        // Malformed UDP data must be visible as invalid and never armed-looking.
        let snapshot = parse("not json");

        assert_eq!(snapshot.latitude, None);
        assert_eq!(snapshot.longitude, None);
        assert_eq!(snapshot.altitude_m, None);
        assert_eq!(snapshot.roll_deg, None);
        assert_eq!(snapshot.pitch_deg, None);
        assert_eq!(snapshot.yaw_deg, None);
        assert_eq!(snapshot.battery_pct, None);
        assert!(!snapshot.is_armed);
        assert_eq!(
            snapshot.status_text,
            "Invalid UDP telemetry packet received"
        );
    }

    #[test]
    fn missing_optional_fields_do_not_crash() {
        // The input contract is intentionally sparse-tolerant for helper tools.
        let snapshot = parse(r#"{"message_type": "vehicle_state"}"#);

        assert_eq!(snapshot.latitude, None);
        assert_eq!(snapshot.longitude, None);
        assert_eq!(snapshot.altitude_m, None);
        assert_eq!(snapshot.roll_deg, None);
        assert_eq!(snapshot.pitch_deg, None);
        assert_eq!(snapshot.yaw_deg, None);
        assert_eq!(snapshot.battery_pct, None);
        assert!(!snapshot.is_armed);
    }
}
