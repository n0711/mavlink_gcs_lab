import 'package:mavlink_gcs_portfolio/features/autopilot/domain/autopilot_adapter.dart';
import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';

class Px4Adapter implements AutopilotAdapter {
  const Px4Adapter();

  @override
  AutopilotType get type => AutopilotType.px4;

  @override
  String get displayName => 'PX4';

  @override
  VehicleMode normalizeMode(String? rawMode) {
    final mode = rawMode?.trim();
    return VehicleMode(
      rawMode: mode == null || mode.isEmpty ? 'UNKNOWN' : mode,
      normalizedMode: mode == null || mode.isEmpty
          ? 'unknown'
          : mode.toLowerCase(),
      autopilotName: displayName,
    );
  }

  @override
  String describeHealth(VehicleState state) {
    return state.isTelemetryStale
        ? 'Telemetry stale'
        : 'PX4 monitor placeholder';
  }

  @override
  bool get supportsMissionUpload => false;

  @override
  bool get supportsCommandAuthority => false;
}
