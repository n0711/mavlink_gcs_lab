//! UDP JSON input payload types.
//!
//! These structs describe the receive-only JSON contract accepted on
//! `127.0.0.1:16000`. They are internal to the backend and are separate from
//! the Flutter-facing snapshot types.

use serde::Deserialize;
use std::collections::HashMap;

/// Top-level UDP JSON telemetry packet.
#[derive(Debug, Deserialize)]
pub(crate) struct TelemetryPayload {
    pub(crate) timestamp: Option<String>,
    pub(crate) message_type: Option<String>,
    pub(crate) position: Option<PositionPayload>,
    pub(crate) motion: Option<MotionPayload>,
    pub(crate) attitude: Option<AttitudePayload>,
    pub(crate) system: Option<SystemPayload>,
    pub(crate) gps: Option<GpsPayload>,
    pub(crate) telemetry: Option<TelemetryMetadataPayload>,
    pub(crate) health: Option<HealthPayload>,
    pub(crate) freshness: Option<FreshnessPayload>,
    pub(crate) source: Option<SourcePayload>,
    pub(crate) status_text: Option<String>,
}

/// Position fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct PositionPayload {
    pub(crate) latitude_deg: Option<f64>,
    pub(crate) longitude_deg: Option<f64>,
    pub(crate) altitude_m: Option<f32>,
}

/// Motion fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct MotionPayload {
    pub(crate) heading_deg: Option<f32>,
    pub(crate) heading_source: Option<String>,
}

/// Attitude fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct AttitudePayload {
    pub(crate) roll_deg: Option<f32>,
    pub(crate) pitch_deg: Option<f32>,
    pub(crate) yaw_deg: Option<f32>,
    pub(crate) age_ms: Option<u32>,
}

/// System and battery fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct SystemPayload {
    pub(crate) armed: Option<bool>,
    pub(crate) battery_percent: Option<u8>,
    pub(crate) battery_voltage_v: Option<f32>,
    pub(crate) battery_current_a: Option<f32>,
    pub(crate) battery_validity: Option<String>,
    pub(crate) battery_source: Option<String>,
    pub(crate) mode: Option<String>,
}

/// GPS fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct GpsPayload {
    pub(crate) fix_type: Option<u8>,
    pub(crate) satellites_visible: Option<u8>,
    pub(crate) hdop: Option<f32>,
}

/// Normalized health fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct HealthPayload {
    pub(crate) gps_fix_type: Option<u8>,
    pub(crate) satellites_visible: Option<u8>,
    pub(crate) hdop: Option<f32>,
}

/// Message freshness fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct FreshnessPayload {
    pub(crate) heartbeat_age_s: Option<f32>,
    pub(crate) attitude_age_s: Option<f32>,
    pub(crate) position_age_s: Option<f32>,
    pub(crate) battery_age_s: Option<f32>,
    pub(crate) gps_age_s: Option<f32>,
}

/// MAVLink source identity fields from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct SourcePayload {
    pub(crate) vehicle_sysid: Option<u8>,
    pub(crate) vehicle_compid: Option<u8>,
    pub(crate) yaw_source: Option<String>,
    pub(crate) heading_source: Option<String>,
}

/// Inspector and message-rate metadata from the UDP JSON contract.
#[derive(Debug, Deserialize)]
pub(crate) struct TelemetryMetadataPayload {
    pub(crate) vehicle_sysid: Option<u8>,
    pub(crate) vehicle_compid: Option<u8>,
    pub(crate) last_message_type: Option<String>,
    pub(crate) message_counts: Option<HashMap<String, u32>>,
    pub(crate) message_rates_hz: Option<HashMap<String, f32>>,
    pub(crate) heartbeat_age_ms: Option<u32>,
    pub(crate) attitude_age_ms: Option<u32>,
    pub(crate) position_age_ms: Option<u32>,
    pub(crate) gps_age_ms: Option<u32>,
    pub(crate) battery_age_ms: Option<u32>,
    pub(crate) locked_vehicle_source: Option<bool>,
}
