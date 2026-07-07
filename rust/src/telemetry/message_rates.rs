//! MAVLink inspector message-rate helpers.
//!
//! The dashboard shows a small fixed set of receive-only message counters and
//! freshness values. Missing metadata is treated as zero/unknown rather than an
//! error so partial telemetry packets remain displayable.

use crate::telemetry::payload::TelemetryMetadataPayload;
use crate::telemetry::snapshot::MessageRateSnapshot;
use std::collections::HashMap;

/// Message types shown by the lightweight inspector panel.
const INSPECTOR_MESSAGE_TYPES: [&str; 8] = [
    "HEARTBEAT",
    "ATTITUDE",
    "GPS_RAW_INT",
    "GLOBAL_POSITION_INT",
    "VFR_HUD",
    "SYS_STATUS",
    "BATTERY_STATUS",
    "STATUSTEXT",
];

/// Returns the freshness field associated with an inspector message type.
pub(crate) fn message_age_ms(
    message_type: &str,
    telemetry: &TelemetryMetadataPayload,
) -> Option<u32> {
    match message_type {
        "HEARTBEAT" => telemetry.heartbeat_age_ms,
        "ATTITUDE" => telemetry.attitude_age_ms,
        "GLOBAL_POSITION_INT" => telemetry.position_age_ms,
        "GPS_RAW_INT" => telemetry.gps_age_ms,
        "SYS_STATUS" | "BATTERY_STATUS" => telemetry.battery_age_ms,
        _ => None,
    }
}

/// Builds the dashboard's fixed message-rate list from optional metadata.
pub(crate) fn message_rates_from_metadata(
    telemetry: Option<&TelemetryMetadataPayload>,
) -> Vec<MessageRateSnapshot> {
    let Some(telemetry) = telemetry else {
        return Vec::new();
    };
    let empty_counts = HashMap::new();
    let empty_rates = HashMap::new();
    let counts = telemetry.message_counts.as_ref().unwrap_or(&empty_counts);
    let rates = telemetry.message_rates_hz.as_ref().unwrap_or(&empty_rates);

    INSPECTOR_MESSAGE_TYPES
        .iter()
        .map(|message_type| MessageRateSnapshot {
            message_type: (*message_type).to_string(),
            count: counts.get(*message_type).copied().unwrap_or(0),
            rate_hz: rates.get(*message_type).copied().unwrap_or(0.0),
            age_ms: message_age_ms(message_type, telemetry),
        })
        .collect()
}
