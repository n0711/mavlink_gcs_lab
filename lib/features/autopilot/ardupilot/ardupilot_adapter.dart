import 'package:mavlink_gcs_portfolio/features/autopilot/domain/autopilot_adapter.dart';
import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';

class ArduPilotAdapter implements AutopilotAdapter {
  const ArduPilotAdapter();

  @override
  AutopilotType get type => AutopilotType.ardupilot;

  @override
  String get displayName => 'ArduPilot';

  @override
  VehicleMode normalizeMode(String? rawMode) {
    final normalized = _normalizeModeText(rawMode);
    return VehicleMode(
      rawMode: rawMode?.trim().isEmpty == false ? rawMode!.trim() : 'UNKNOWN',
      normalizedMode: normalized,
      autopilotName: displayName,
    );
  }

  @override
  String describeHealth(VehicleState state) {
    if (state.isTelemetryStale) return 'Telemetry stale';
    if (!state.gps.isHealthy) return 'GPS not healthy';
    return 'Telemetry monitor healthy';
  }

  @override
  bool get supportsMissionUpload => false;

  @override
  bool get supportsCommandAuthority => false;

  String _normalizeModeText(String? rawMode) {
    final mode = rawMode?.trim();
    if (mode == null || mode.isEmpty) return 'unknown';
    return mode.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }
}
