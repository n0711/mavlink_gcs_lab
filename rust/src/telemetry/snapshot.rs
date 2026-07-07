//! Flutter-facing telemetry snapshot types.
//!
//! These structs are the typed output contract sent through
//! `flutter_rust_bridge`. Keep field names stable unless the bridge outputs are
//! regenerated through the normal project workflow.

/// Per-message inspector data displayed by the Flutter dashboard.
pub struct MessageRateSnapshot {
    pub message_type: String,
    pub count: u32,
    pub rate_hz: f32,
    pub age_ms: Option<u32>,
}

/// Vehicle state snapshot emitted by the receive-only Rust telemetry backend.
pub struct VehicleSnapshot {
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub altitude_m: Option<f32>,
    pub roll_deg: Option<f32>,
    pub pitch_deg: Option<f32>,
    pub yaw_deg: Option<f32>,
    pub battery_pct: Option<u8>,
    pub battery_voltage_v: Option<f32>,
    pub battery_current_a: Option<f32>,
    pub battery_validity: Option<String>,
    pub battery_source: Option<String>,
    pub is_armed: bool,
    pub mode: Option<String>,
    pub gps_fix_type: Option<u8>,
    pub satellites_visible: Option<u8>,
    pub hdop: Option<f32>,
    pub heartbeat_age_s: Option<f32>,
    pub attitude_age_s: Option<f32>,
    pub attitude_age_ms: Option<u32>,
    pub position_age_s: Option<f32>,
    pub battery_age_s: Option<f32>,
    pub gps_age_s: Option<f32>,
    pub vehicle_sysid: Option<u8>,
    pub vehicle_compid: Option<u8>,
    pub yaw_source: Option<String>,
    pub heading_source: Option<String>,
    pub last_message_type: Option<String>,
    pub locked_vehicle_source: bool,
    pub message_rates: Vec<MessageRateSnapshot>,
    pub telemetry_source_type: String,
    pub telemetry_bind_address: String,
    pub telemetry_packet_count: u32,
    pub telemetry_parse_error_count: u32,
    pub telemetry_message_rate_hz: f32,
    pub telemetry_receive_only_note: String,
    pub status_text: String,
}
